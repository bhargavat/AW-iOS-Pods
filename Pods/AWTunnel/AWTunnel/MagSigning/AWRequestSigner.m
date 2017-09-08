//  AWRequestSigner.m
//  AirWatch
//
//  Created by Nolan Roberson on 11/1/13.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#import <AWTunnel/AWTunnel-Swift.h>

#import "AWRequestSigner.h"

#import "AWSignatureCache.h"
#import "AWSignatureCacheEntry.h"

#import "AWContentFilter.h"
#import "AWProxy.h"
#import "AWTunnelLogger.h"

// This is to allow the smooth import of this module into Swift framework
@import AWServices;
@import AWHelpers;
@import AWCrypto;
@import AWCMWrapper;

static NSString *const kAWDate                      =	@"DATE";
static NSString *const kAWSignatureHeader           =	@"PROXY-AUTHORIZATION";
static NSDateFormatter *kDateFormatter              =   nil;
static NSString *const kAWCms1                      =   @"cms1";
static NSString *const kAWCms2                      =   @"cms2";


@interface AWRequestSigner ()
#if !TARGET_IPHONE_SIMULATOR
- (void) setupMobileAPI;
#endif
@end

@implementation AWRequestSigner

#if !TARGET_IPHONE_SIMULATOR
@synthesize dataCollectionLevel = _dataCollectionLevel;
#endif


+(AWRequestSigner*)sharedInstance{
    
    static AWRequestSigner *sharedInst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInst = [[self alloc] init];
    });
    return sharedInst;
}

-(void) dealloc
{
#if !TARGET_IPHONE_SIMULATOR
    [mMobileAPI destroy];
    mMobileAPI = nil;
#endif
}


- (id)init
{
    if (self = [super init]) {
#if !TARGET_IPHONE_SIMULATOR
        _dataCollectionLevel = COLLECT_ALL_DEVICE_DATA_AND_LOCATION;
        [self updateRSAJSONString];
#endif
        self.useCmsv2 = YES;
    }
    return self;
}

#if !TARGET_IPHONE_SIMULATOR

- (void) setDataCollectionLevel:(AWRSAAADeviceInfoLevel) theDataCollectionLevel {
    switch (theDataCollectionLevel) {
        case AWRSAAABasicData:
             _dataCollectionLevel = COLLECT_BASIC_DEVICE_DATA_ONLY;
            break;
        case AWRSAAADeviceData:
            _dataCollectionLevel = COLLECT_DEVICE_DATA_ONLY;
            break;
        case AWRSAAAAllDeviceData:
            _dataCollectionLevel = COLLECT_ALL_DEVICE_DATA_AND_LOCATION;
            break;
        default:
            _dataCollectionLevel = COLLECT_ALL_DEVICE_DATA_AND_LOCATION;
            break;
    }
    [self setupMobileAPI];
    [self updateRSAJSONString];
}


- (void) setupMobileAPI {
    mMobileAPI = [[MobileAPI alloc]init];
    NSNumber *configuration = [[NSNumber alloc]initWithUnsignedLong:self.dataCollectionLevel];
    NSNumber *timeout = [[NSNumber alloc]initWithInt:TIMEOUT_DEFAULT_VALUE];
    NSNumber *silencePeriod = [[NSNumber alloc]initWithInt:SILENT_PERIOD_DEFAULT_VALUE];
    NSNumber *bestAge = [[NSNumber alloc]initWithInt:BEST_LOCATION_AGE_MINUTES_DEFAULT_VALUE];
    NSNumber *maxAge = [[NSNumber alloc]initWithInt:MAX_LOCATION_AGE_DAYS_DEFAULT_VALUE];
    ///NSNumber *maxAccuracy = [[NSNumber alloc]initWithInt:MAX_ACCURACY_DEFAULT_VALUE];
    // override default accuracy in order to force GPS collection
    NSNumber *maxAccuracy = [[NSNumber alloc]initWithInt: 50];
    
    NSDictionary *properties = [[NSDictionary alloc] initWithObjectsAndKeys:
                                configuration, CONFIGURATION_KEY,
                                timeout, TIMEOUT_MINUTES_KEY,
                                silencePeriod, SILENT_PERIOD_MINUTES_KEY,
                                bestAge, BEST_LOCATION_AGE_MINUTES_KEY,
                                maxAge, MAX_LOCATION_AGE_DAYS_KEY,
                                maxAccuracy, MAX_ACCURACY_KEY,
                                @"1", ADD_TIMESTAMP_KEY,
                                nil];
    
    mMobileAPIInitialized = [mMobileAPI initSDK: properties];
}
-(void) updateRSAJSONString
{
    
    if(![[AWProxy sharedInstance] magRSAAdaptiveAuthEnabled]) {
        jsonString = nil;
        return;
    }
    
    if(!mMobileAPI) {
        [self setupMobileAPI];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateRSAJSONString)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    jsonString = [[mMobileAPI collectInfo] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    jsonString  = [data base64EncodedStringWithOptions:0];

}
#endif


- (NSString *)cmsV2PayloadStringToBeSignedForRequest:(NSURLRequest *)request
{
    NSString * payloadString = nil;
    if ([request URL].absoluteString.length) {
        payloadString = [NSString stringWithFormat:@"%@\n",[request URL]];
    }
    return payloadString;
}

- (NSString *)cmsV1PayloadStringToBeSignedForRequest:(NSURLRequest *)request withHostPort:(NSNumber *)hostPort
{
    NSString * payloadString = nil;
    BOOL isHTTPPostOrPut = [[[request URL] scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame && ([request HTTPBody] && [[request HTTPBody] length] > 0);
    if (isHTTPPostOrPut) {
        //1. Body data
        if(hostPort){
            payloadString = [NSString stringWithFormat:@"%@:%ld\n%@",
                             [[request URL] host],
                             (long)hostPort.integerValue,
                             [[request HTTPBody] base64EncodedStringWithOptions:0]];
            
        }
        
        else{
            payloadString = [NSString stringWithFormat:@"%@\n%@",
                             [[request URL] host],
                             [[request HTTPBody] base64EncodedStringWithOptions:0]];
        }
    } else if ([[request URL] path]) {
        //2. Canonical resource path
        if(hostPort)
            payloadString = [NSString stringWithFormat:@"%@:%ld\n%@",[[request URL] host],(long)hostPort.integerValue,@""];
        else
            payloadString = [NSString stringWithFormat:@"%@\n%@",[[request URL] host],@""];
    }
    
    return payloadString;
}

- (AWMutableURLRequest *)MAGSignedRequestWithPort:(NSNumber *)hostPort andRequest:(NSURLRequest *)origRequest error:(NSError **)outError
{
#if DEBUG
    NSDate *beginDate = [NSDate date];
#endif
    
    NSURL *url = [origRequest URL];
    AWMutableURLRequest *retRequest = [origRequest mutableCopy];
    
    retRequest.HTTPMethod = (retRequest.HTTPMethod) ? [retRequest HTTPMethod] : @"GET";
    
    if (kDateFormatter == nil) {
        kDateFormatter = [NSDateFormatter GMTDateFormatter];
        [kDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
    }
    
    [retRequest setValue:[kDateFormatter stringFromDate:[NSDate date]] forHTTPHeaderField:kAWDate];
    
#if !TARGET_IPHONE_SIMULATOR
    if(mMobileAPI && jsonString) {
        [retRequest addValue:jsonString forHTTPHeaderField:@"aa-device-info"];
    }
#endif
    
    NSData *pfxCert = [self.proxyCertService signingCertificate];
    if (!pfxCert)
    {
        AWLogError(@"There is no MAG proxy certificate stored on the device.");
        return retRequest;
    }
    
    NSData *signature = nil;
    NSString *payloadString;
    
    [retRequest setHTTPBody:[self httpBody:origRequest]];
    
    BOOL forceSign = NO;
    BOOL isHTTPPostOrPut = [[url scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame && ([retRequest HTTPBody] && [[retRequest HTTPBody] length] > 0);
    if (isHTTPPostOrPut)
    { //1. Body data
        
        forceSign = YES;
        
        if(!origRequest.HTTPBodyStream){
            NSString *bodyLength = [NSString stringWithFormat:@"%ld", (long)retRequest.HTTPBody.length];
            [retRequest addValue:bodyLength forHTTPHeaderField:@"Content-Length"];
        }
        
    }
    
    if (self.useCmsv2) {
        payloadString = [self cmsV2PayloadStringToBeSignedForRequest:retRequest];
    } else {
        payloadString = [self cmsV1PayloadStringToBeSignedForRequest:retRequest withHostPort:hostPort];
    }
    
    if (!payloadString) {
        AWLogError(@"Failed to sign the request payload.");
        return nil;
    }

    
    AWSignatureCacheEntry *entry = nil;
    //For POST generate signature each time.
    if(!forceSign){
        //Check our cache first
        entry = [[AWSignatureCache sharedInstance] objectForKey:payloadString];
    }
    
    if (!entry){
        //signature for host not in cache.
        signature = [self signatureForPayload:[payloadString dataUsingEncoding:NSUTF8StringEncoding]
                                  withPFXCert:pfxCert
                                     password:[[AWTunnelService sharedInstance] bundleID]]; //[AWUtility bundleIdentifier]];
        
        if(signature && !forceSign) {
            [[AWSignatureCache sharedInstance] setObject:signature forKey:payloadString];
        }
    } else {
        signature = entry.signature;
    }
    
    
    if (!signature)
    {
        AWLogError(@"Failed to sign the request payload.");
        return nil;
    }
    
    NSString *scheme = @"Basic";
    NSString *udid = [[AWTunnelService sharedInstance] deviceUDID];
    NSString *bundleId = [[AWTunnelService sharedInstance] bundleID]; //[AWUtility bundleIdentifier];
    NSString *cmsVersion = self.useCmsv2 ? kAWCms2 : kAWCms1;
    NSString *authString = [NSString stringWithFormat:@"alg:%@;uid:%@;bundleid:%@:%@",
                            cmsVersion,
                            udid,
                            bundleId,
                            [signature base64EncodedStringWithOptions:0]];
    NSData *authData = [authString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *headerValue = [NSString stringWithFormat:@"%@ %@",
                             scheme,
                             [authData base64EncodedStringWithOptions:0]];
    
    [retRequest setValue:headerValue forHTTPHeaderField:kAWSignatureHeader];
    
#if DEBUG
    NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:beginDate];
    AWLogDebug(@"Time to sign request: %fs", executionTime);
#endif
    
    return retRequest;
}

- (NSData *)signatureForPayload:(NSData *)payload withPFXCert:(NSData *)pfxCert password:(NSString *)password;
{
    NSData *privateKeyData = [AWPKCS12Helper privateKeyDataFromPKCS12Data:pfxCert
                                                                 password:password];
    NSData *certData = [AWPKCS12Helper certificateDataFromPKCS12Data:pfxCert
                                                            password:password];

    return [AWPKCS7Cryptor pkcs7SignatureForPayload:payload
                                     privateKeyData:privateKeyData
                                           password:password
                                  signerCertificate:certData];
}

- (NSString *)newSignedBasicAuthFor:(NSString *)user password:(NSString *)password error:(NSError **)outError
{
    NSString *stringToEncode = [NSString stringWithFormat:@"%@:%@", user, password];
    return [NSString stringWithFormat:@"Basic %@",
               [[stringToEncode dataUsingEncoding:NSUTF8StringEncoding]
                   base64EncodedStringWithOptions:0]];
}

#pragma mark - Util


- (NSData *)httpBody:(NSURLRequest*)req {
    if (req.HTTPBodyStream) {
        NSInputStream *stream = req.HTTPBodyStream;
        NSMutableData *data = [NSMutableData data];
        [stream open];
        size_t bufferSize = 4096;
        uint8_t *buffer = malloc(bufferSize);
        if (buffer == NULL) {
            return nil;
        }
        while ([stream hasBytesAvailable]) {
            NSInteger bytesRead = [stream read:buffer maxLength:bufferSize];
            if (bytesRead > 0) {
                NSData *readData = [NSData dataWithBytes:buffer length:bytesRead];
                [data appendData:readData];
            } else if (bytesRead < 0) {
                free(buffer);
                return nil;
            }
        }
        free(buffer);
        [stream close];
        
        return data;
    }
    return [req HTTPBody];
}


#pragma mark - Websense
- (AWMutableURLRequest *)newSignedRequestForWebSense: (NSURLRequest *)origRequest error:(NSError **)outError
{
#if DEBUG
    NSDate *beginDate = [NSDate date];
#endif
    
    AWMutableURLRequest *retRequest = [origRequest mutableCopy];
    
    retRequest.HTTPMethod = (retRequest.HTTPMethod) ? [retRequest HTTPMethod] : @"GET";
    
    if (kDateFormatter == nil) {
        kDateFormatter = [NSDateFormatter GMTDateFormatter];
        [kDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
    }
    
    AWContentFilter *contentFilter = [AWContentFilter sharedInstance];
    
    [retRequest setValue:[kDateFormatter stringFromDate:[NSDate date]] forHTTPHeaderField:kAWDate];
    [retRequest addValue:@"" forHTTPHeaderField:kAWSignatureHeader];
    
    //Clear values first:
    [retRequest addValue:@"" forHTTPHeaderField:@"X-Ws-Mobile-Account-Id"];
    [retRequest addValue:@"" forHTTPHeaderField:@"X-Ws-Ver"];
    [retRequest addValue:@"" forHTTPHeaderField:@"X-Ws-Mobile-Ver"];
    [retRequest addValue:@"" forHTTPHeaderField:@"X-Ws-Auth"];
    
    
    //Add Account ID
    NSString *accountID = [@([contentFilter websenseAccountId]) stringValue];
    [retRequest addValue:accountID  forHTTPHeaderField:@"X-Ws-Mobile-Account-Id"];
    
    //Add version
    [retRequest addValue:@"1.0" forHTTPHeaderField:@"X-Ws-Ver"];
    [retRequest addValue:@"2.0" forHTTPHeaderField:@"X-Ws-Mobile-Ver"];
    
    
    NSString *host = [[retRequest URL] host];
    AWSignatureCacheEntry * cachedAuthForHost = [[AWSignatureCache sharedInstance] objectForKey:host];
    NSString *authHeader = [[NSString alloc] initWithData:cachedAuthForHost.signature encoding:NSUTF8StringEncoding];
    
    if(!cachedAuthForHost &&
       (!authHeader ||
        (authHeader && ![authHeader length]))) {
           
           //Add IV
           NSString *ivString = @"00000000000000000000000000000000";
           NSMutableData *iv= [[NSMutableData alloc] init];
           unsigned char whole_byte_iv;
           char iv_byte_chars[3] = {'\0','\0','\0'};
           for (int i = 0; i < ([ivString length] / 2); i++) {
               iv_byte_chars[0] = [ivString characterAtIndex:i*2];
               iv_byte_chars[1] = [ivString characterAtIndex:i*2+1];
               whole_byte_iv = strtol(iv_byte_chars, NULL, 16);
               [iv appendBytes:&whole_byte_iv length:1];
           }
           
           //Add auth signature
           //# First, pad the host header to 16 bytes with spaces
           NSString *keyString =[contentFilter websenseSecurityKey];
           NSMutableData *key= [[NSMutableData alloc] init];
           unsigned char whole_byte;
           char byte_chars[3] = {'\0','\0','\0'};
           for (int i = 0; i < ([keyString length] / 2); i++) {
               byte_chars[0] = [keyString characterAtIndex:i*2];
               byte_chars[1] = [keyString characterAtIndex:i*2+1];
               whole_byte = strtol(byte_chars, NULL, 16);
               [key appendBytes:&whole_byte length:1];
           }
           
           
           NSError *err;
           NSData *requestKeyData = [self encryptData:[host dataUsingEncoding:NSUTF8StringEncoding] key:key iv:iv error:&err];
           NSData *requestKey = [self sha1Data:requestKeyData];
           
           NSString *username = [[AWProxy sharedInstance] username];
           NSString *deviceId = [[AWTunnelService sharedInstance] deviceUDID]; //[[AWDeviceInfo sharedInstance] formattedUniqueIdentifier];
           NSString *deviceType = [[UIDevice currentDevice] model];
           NSString *deviceClass = @"2";
           
           NSString *header = [NSString stringWithFormat:@"AccountID:%@; Username:%@; DeviceID:%@; DeviceType:%@; DeviceClass:%@",
                               accountID,
                               username,
                               deviceId,
                               deviceType,
                               deviceClass];
           
           NSData *encryptedHeader = [self encryptData:[header dataUsingEncoding:NSUTF8StringEncoding] key:requestKey iv:iv error:&err];
           authHeader = [encryptedHeader aw_hexadecimalString];
           
           [[AWSignatureCache sharedInstance] setObject:[authHeader dataUsingEncoding:NSUTF8StringEncoding] forKey:host];
       }
    
    [retRequest addValue:authHeader forHTTPHeaderField:@"X-Ws-Auth"];
    
#if DEBUG
    NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:beginDate];
    AWLogDebug(@"Time to sign request: %fs", executionTime);
#endif
    
    return retRequest;
    
}

- (NSData *)encryptData:(NSData *)data key:(NSData *)secKey iv:(NSData *)iv error:(NSError **)err
{
    //Pad data to 16 bytes with spaces
    NSMutableData *paddedData = [NSMutableData dataWithData:data];
    NSUInteger padLen = (16 - ([paddedData length] % 16));
    if(padLen > 0 && padLen < 16)
    {
        NSString *pad = [[NSString string] stringByPaddingToLength:padLen withString:@" " startingAtIndex:0];
        [paddedData appendData:[pad dataUsingEncoding:NSUTF8StringEncoding]];
    }

    return [NSData AW_AES128EncryptedData:paddedData
                                      key:secKey
                                       iv:iv
                                    error:err];
}

- (NSData *)sha1Data:(NSData *)data
{
    return [data aw_sha1];
}



@end
