//
//  AWContentFilter.m
//  AirWatch
//
//  Created by Vishal Patel on 11/18/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */


#import <AWTunnel/AWTunnel-Swift.h>

#import "AWContentFilter.h"
#import "AWForwarderService.h"
#import "AWProxyErrors.h"
#import "AWTunnelLogger.h"
#import "FNProxySupportPriv.h"

@import AWLocalization;

@interface AWContentFilter (private)

-(BOOL) checkShouldFilterContentForRequest:(const char *)requestURL withHost:(const char *)requestHost;

@end

int should_content_filter_handle_request (const char * requestURL, const char * host)
{
    return [[AWContentFilter sharedInstance] checkShouldFilterContentForRequest:requestURL withHost:host];
}



NSString *const AWContentFilterErrorDomain = @"com.AirWatch.sdk.contentfilter.ErrorDomain";


@interface AWContentFilter() <AWContentFilterDelegate>

@property (nonatomic, copy) NSString * proxyAutoConfigScript;

@end

@implementation AWContentFilter

#pragma mark Lifecycle

+ (AWContentFilter*)sharedInstance
{
    static dispatch_once_t onceToken;
    static AWContentFilter *contentFilterProxy = nil;
    
    dispatch_once(&onceToken, ^{
        
        contentFilterProxy = [[self alloc] init];
    });
    
    return contentFilterProxy;
}

- (id)init
{
    if ((self = [super init]))
    {
        _isEnabled = NO;
        _delegate = nil;
        
    }
    return self;
}

- (void)dealloc
{
    set_content_filter_function(NULL);
    _delegate = nil;
}

- (void)setDelegate:(id<AWContentFilterDelegate>)delegate
{
    if (_delegate)
    {
        AWLogInfo(@"Setting a new delegate on the AWContentFilter singleton.");
    }
    _delegate = delegate;
}

- (BOOL)start:(NSError**)error
{
    
    AWForwarderService *service = [AWForwarderService sharedInstance];
    
    _isEnabled = [service startForwarderService];
    
    if (![self fetchPACFile:nil]){
        _isEnabled = NO;
        [service stopContentFilterWithCompletion:^{}];
    }
    
    if (_isEnabled) {
        set_content_filter_function(&should_content_filter_handle_request);
    }
    
    return _isEnabled;
}

- (void)stop
{
    AWForwarderService *service = [AWForwarderService sharedInstance];
    [service stopContentFilterWithCompletion:^{
        _isEnabled = NO;
        set_content_filter_function(NULL);
    }];
}


/*
 fetches the pac script located at the url specified by self.autoConfigURL
 stores the script in self.proxyAutoConfigScript
 returns the status of the operation
 
 return status and error are mutually exclusive
 */
- (BOOL)fetchPACFile:(NSError **)error;
{
    AWLogVerbose(@"Fetching PAC file from [%@]",self.websensePacAddress);
    if(!self.websensePacAddress)
    {
        [self setProxyAutoConfigScript:nil];
        NSString *desc = AWSDKLocalizedString(@"FailedToGetPACscript", nil);
        NSString *recv = AWSDKLocalizedString(@"SetAutoConfigURLProperty", nil);
        NSString *reas = AWSDKLocalizedString(@"AutoConfigURLPropertyIsNotSet", nil);
        
        AWLogError(@"%@",reas);
        NSError *err = AWErrorMacro(AWContentFilterErrorDomain, AWProxyErrorAutoConfigURLMissing,
                                    desc, recv, reas);
        if (error)
            *error = err;
        return NO;
    }
    NSData *data = nil;
    NSURL *autoconfigURL = [NSURL URLWithString:self.websensePacAddress];
    data = [NSData dataWithContentsOfURL:autoconfigURL];
    BOOL status;
    NSError *outErr;
    if([data length])
    {
        NSString *autoConfigScript = [[NSString alloc] initWithData:data
                                                           encoding:NSUTF8StringEncoding];
        if ([autoConfigScript length])
        {
            self.proxyAutoConfigScript = autoConfigScript;
            status = YES;
            outErr = nil;
        } else
        {
            [self setProxyAutoConfigScript:nil];
            NSString *desc = AWSDKLocalizedString(@"FailedToGetPACscript", nil);
            NSString *recv = AWSDKLocalizedString(@"MakeSureForValidScriptLocatedAtAutoConfigURL", nil);
            NSString *reas = AWSDKLocalizedString(@"FailedToDecodeAutoConfigUrlRetrievedData", nil);
            AWLogError(@"%@",reas);
            outErr = AWErrorMacro(AWProxyErrorDomain, AWProxyErrorInvalidDataFromPACURL,
                                  desc, recv, reas);
            status = NO;
        }
        
    }
    else
    {
        [self setProxyAutoConfigScript:nil];
        NSString *desc = AWSDKLocalizedString(@"FailedToGetPACscript", nil);
        NSString *recv = AWSDKLocalizedString(@"MakeSurePACURLisValid", nil);
        NSString *reas = AWSDKLocalizedString(@"FailedToRetrievedAutoConfigUrlData", nil);
        AWLogWarning(@"%@",reas);
        outErr = AWErrorMacro(AWProxyErrorDomain, AWProxyErrorFailedToGetPACScript,
                              desc, recv, reas);
        status = NO;
    }
    
    if (error)
    {
        *error = outErr;
    }
    
    return status;
    
} /* fetchPACFile: */

/*
 This method uses CFNetworkCopyProxiesForAutoConfigurationScript to determine host and port information for the provided
 url. This method sets self.host and self.httpPort and self.httpsPort automatically.
 
 This method won't do anyting if self.proxyAutoConfigScript == nil Be sure to either manuall set proxyAutoConfigScript or
 set self.autoConfigURL and call fetchPACFile:
 
 */
- (NSDictionary *)getProxySettingsForURL:(NSURL *)url
{
    NSDictionary * retDict = NULL;
    if (self.proxyAutoConfigScript)
    {
        // From: http://developer.apple.com/samplecode/CFProxySupportTool/listing1.html
        // Work around <rdar://problem/5530166>. This dummy call to
        // CFNetworkCopyProxiesForURL initialise some state within CFNetwork
        // that is required by CFNetworkCopyProxiesForAutoConfigurationScript.
        
        CFRelease(CFNetworkCopyProxiesForURL((__bridge CFURLRef)url, (__bridge CFDictionaryRef)(@{})));
        
        AWLogInfo(@"Getting proxy settings from PAC file.");
        AWLogDebug(@"Getting proxies for URL: %@", url);

        CFErrorRef err = NULL;
        NSArray *proxies = (__bridge_transfer id)(CFNetworkCopyProxiesForAutoConfigurationScript\
                                                  ((__bridge CFStringRef)self.proxyAutoConfigScript,
                                                   (__bridge CFURLRef)url, &err));
        
        if (err)
        {
            AWLogError(@"Failed to get proxies from auto config script due to error: %@",
                       (__bridge NSError*)err);
        } else
        {
            if ([proxies count])
            {
                NSDictionary *settings = [proxies objectAtIndex:0];
                
                BOOL isProxyTypeNone = [[settings objectForKey:(NSString *)kCFProxyTypeKey] isEqualToString:(NSString *)kCFProxyTypeNone];
                BOOL hasPort = ([settings objectForKey:(NSString *)kCFProxyPortNumberKey] != nil);
                NSString *host = [settings objectForKey:(NSString *)kCFProxyHostNameKey];
                
                if (isProxyTypeNone || !hasPort || !host)
                {
                    AWLogInfo(@"Not using proxy. Connecting directly.");
                } else
                {
                    return settings;
                }
                
                
                
            } else
            {
                AWLogWarning(@"No proxies found for host: %@", [url host]);
            }
        }
        
    } else
    {
        AWLogWarning(@"Missing PAC script. Be sure to use fetchPACFile:");
    }
    
    return retDict;
}

-(BOOL) checkShouldFilterContentForRequest:(const char *)requestURL withHost:(const char *)requestHost
{
    NSString *requestHostOrURL = nil;
    
    if (NULL != requestURL) {
        requestHostOrURL = [NSString stringWithUTF8String:requestURL];
    } else if (NULL != requestHost) {
        requestHostOrURL = [NSString stringWithUTF8String:requestHost];
    }
    
    
    if(requestHostOrURL &&
       self.delegate &&
       [self.delegate respondsToSelector:@selector(shouldFilterContentForRequest:)])
    {
        NSURL *url = [NSURL URLWithString:requestHostOrURL];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        return [self.delegate shouldFilterContentForRequest:request];
    }
    return NO;
}

#pragma mark ConfigureMethods

- (void)configureWebsenseWithPac: (NSString *) pacAddress securityKey:(NSString *) secKey accountId: (NSInteger) accountId
{
    _websensePacAddress = [pacAddress copy];
    _websenseSecurityKey = [secKey copy];
    _websenseAccountId = accountId;
}

#pragma mark - Mapping methods
#if 0
- (NSArray*)categoryListForURL:(NSString*)urlString {
    NSArray* categoryList = [self.categoryToURLMap objectForKey:urlString];
    return categoryList;
}

- (void)setCategories:(NSArray*)categoryList forURL:(NSString*)urlString {
    if(!self.categoryToURLMap)
        self.categoryToURLMap = [[NSMutableDictionary alloc] init];
    
    if([[self.categoryToURLMap allKeys] containsObject:urlString])
        [self.categoryToURLMap removeObjectForKey:urlString];
    
    [self.categoryToURLMap setObject:categoryList forKey:urlString];
}

#pragma mark - websense threatseeker

-(void) createStreamsToFilterServer{
    
    if (!self.streamOpen) {
        //TODO: VIPString needs to be updated with production env url
        NSString* VIPString = @"http://tsc-demo-vip-704272852.us-east-1.elb.amazonaws.com/urlinfo/cat?url=";
        
        NSURL* url = [NSURL URLWithString:VIPString];
        
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)[url host], 80, &readStream, &writeStream);
        
        NSInputStream *inputStream = (__bridge_transfer NSInputStream *)readStream;
        NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;
        
        CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanFalse);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanFalse);
        
        _inputStream = inputStream;
        _outputStream = outputStream;
        
        if (NSStreamStatusNotOpen == _inputStream.streamStatus) {
            [_inputStream open];
        }
        
        if (NSStreamStatusNotOpen == _outputStream.streamStatus) {
            [_outputStream open];
        }
        self.streamOpen = YES;
        
    }
}

-(void) closeStreamsToFilterServer
{
    if (self.streamOpen)
    {
        [_inputStream close];
        [_outputStream close];
        _outputStream = nil;
        _inputStream = nil;
        
        self.streamOpen = NO;
    }
}


- (BOOL)isAllowedCategoryFilter:(NSString*)urlString {
    
    BOOL isAllowed = NO;
    NSArray* cachedList = [[AWContentFilter sharedInstance] categoryListForURL:urlString];
    
    if(cachedList && [cachedList count]>0) {
        isAllowed = [self isAllowedToBrowseCategories:cachedList];
        return isAllowed;
    }
    
    return [self threatSeekerWebsenseStreamCheck:urlString];
}


-(BOOL)threatSeekerWebsenseStreamCheck:(NSString*)urlString
{
    //TODO: VIPString and demokey needs to be updated with production env url/key.
    NSString* demoKey = @"94F26882-9F22-11DE-B4B9-8447ED2E2560";
    NSString* VIPString = @"http://tsc-demo-vip-704272852.us-east-1.elb.amazonaws.com/urlinfo/cat?url=%@";
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:VIPString,urlString]];
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setValue:demoKey forHTTPHeaderField:@"X-WSL-Auth"];
    
    BOOL isAllowed = YES;

    @synchronized(self)
    {
        if (!self.streamOpen) {
            [self createStreamsToFilterServer];
            self.streamOpen= YES;
        }
        
        CFDataRef msg = [request createHTTPMessageSerial];
        
        if (NSStreamStatusClosed == [_outputStream streamStatus])
        {
            self.streamOpen = NO;
            
            [self createStreamsToFilterServer];
        }
        
        if (NSStreamStatusOpen == [_outputStream streamStatus])
        {
            if ([_outputStream write:CFDataGetBytePtr(msg) maxLength:CFDataGetLength(msg)] < 1)
            {
                
                NSError *strmError = [_outputStream streamError];
                AWLogWarning(@"Failed to write message to stream! %@", strmError);
                [_outputStream close];
                [_inputStream close];
                _outputStream = nil;
                _inputStream = nil;
                
                self.streamOpen = NO;
                // [self createStreamsToFilterServer];
            }
        }
        CFRelease(msg);
        CFHTTPMessageRef _HTTPResponse = CFHTTPMessageCreateEmpty(kCFAllocatorDefault,false);
        
        while(CFReadStreamHasBytesAvailable((CFReadStreamRef)_inputStream))
        {
            AWLogVerbose(@"Bytes available in stream");
            
            UInt8 buffer[1024];
            CFIndex read = 0;
            read = CFReadStreamRead((CFReadStreamRef)_inputStream, buffer, 1024);
            if (read)
            {
                CFHTTPMessageAppendBytes(_HTTPResponse,buffer, read);
            }
        }
        
        CFDataRef body = CFHTTPMessageCopyBody(_HTTPResponse);
        NSData* data = (__bridge_transfer NSData *) body;
        
#if 0
        NSInteger httpStatus = CFHTTPMessageGetResponseStatusCode(_HTTPResponse);
        NSDictionary *headers = (NSDictionary *)CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(_HTTPResponse));
        AWLogVerbose(@"Response status code from stream %li", (long)httpStatus);
        AWLogVerbose(@"Response headers from stream %@", headers);
#endif
        
        if(data){
            NSError* error = nil;
            NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSArray* categories = (NSArray*)[responseDict valueForKey:@"cat"];
            log(debug: @"Filter category response  %@,%@", responseDict , error);
            if(urlString && categories) {
                [[AWContentFilter sharedInstance] setCategories:categories forURL:urlString];
            }
            isAllowed = [self isAllowedToBrowseCategories:categories];
        }
        
        CFRelease(_HTTPResponse);
    }
    return isAllowed;
}

- (BOOL)isAllowedToBrowseCategories:(NSArray*)categoryList {
    
    AWStoreManager *store = [AWStoreManager currentStore];
    self.profile = [store sdkProfile];

    NSArray *filterCategories = self.profile.websiteFilteringPayload.websiteFilterCategories;
    AWWebsiteFilterType filterType = self.profile.websiteFilteringPayload.filterType;
    BOOL isAllowed = YES;
    
    for(NSInteger i=0; i< categoryList.count; i++)
    {
        NSNumber* cat = [NSNumber numberWithInt:[[categoryList objectAtIndex:i] intValue]];
        
        switch (filterType) {
            case AWWebsiteFilterTypeAllow:
                
                isAllowed = [filterCategories containsObject:cat] ? YES : NO;
                break;
                
            case AWWebsiteFilterTypeDeny:
                isAllowed = ![filterCategories containsObject:cat] ? YES : NO;
                break;
                
            default:
                break;
        }
        
    }
    return isAllowed;
}
#endif

@end
