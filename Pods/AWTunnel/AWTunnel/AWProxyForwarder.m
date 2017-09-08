//
//  VHProxyForwarder.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <AWTunnel/AWTunnel-Swift.h>

#import "AWProxyForwarder.h"
#import "AWProxy+Private.h"
#import "AWProxyErrors.h"
#import "AWTunnelLogger.h"

#import "Fuji.h"
#import "ProxyAuthTokenHelper.h"
#import "VHDispatchRunLoopQueuing.h"
#import "VHProxyUtils.h"

#import "NSStreamUtils.h"
#import "NSURLRequest+HTTPMessage.h"

#import "MobileAPI.h"

#include <netinet/in.h>
#include <netinet/tcp.h>

@import AWHelpers;
@import AWCMWrapper;

#define FPS_BUFF_SIZE 4096

static const CFSocketNativeHandle INVALID_HANDLE = -1;

/**
 * \brief Extract the underlying handle from a CFReadStream
 *
 * \param stream The stream
 * \return The underlying handle or INVALID_HANDLE on failure
 */
static CFSocketNativeHandle
GetNativeReadHandle(CFReadStreamRef stream)
{
    CFDataRef data = (CFDataRef)CFReadStreamCopyProperty(stream, kCFStreamPropertySocketNativeHandle);
    if (data == NULL) {
        return INVALID_HANDLE;
    }
    FATAL_IF(CFDataGetLength(data) != sizeof (CFSocketNativeHandle), FUJI_FATAL_INVALID_STATE);
    CFSocketNativeHandle handle = *(CFSocketNativeHandle *)CFDataGetBytePtr(data);
    CFRelease(data);
    return handle;
}

/**
 * \brief Extract the underlying handle from a CFWriteStream
 *
 * \param stream The stream
 * \return The underlying handle or INVALID_HANDLE on failure
 */
static CFSocketNativeHandle
GetNativeWriteHandle(CFWriteStreamRef stream)
{
    CFDataRef data = (CFDataRef)CFWriteStreamCopyProperty(stream, kCFStreamPropertySocketNativeHandle);
    if (data == NULL) {
        return INVALID_HANDLE;
    }
    FATAL_IF(CFDataGetLength(data) != sizeof (CFSocketNativeHandle), FUJI_FATAL_INVALID_STATE);
    CFSocketNativeHandle handle = *(CFSocketNativeHandle *)CFDataGetBytePtr(data);
    CFRelease(data);
    return handle;
}

@interface AWProxyForwarder () {
    // members accessed on the data forwarding path are Ivars to avoid Obj-C dispatches
    uint8_t *_readBuf;
    uint8_t *_readBufEnd;
    NSMutableData *_readBufBacking;
    NSMutableData *_tempBuffBacking;
    NSInputStream *_input;
    NSOutputStream *_output;
    
@private
    CFHTTPMessageRef                    _HTTPRequest;
}
@property (nonatomic, retain) NSString *label;
@property (nonatomic, retain) id<VHDispatchRunLoopQueuing> queue;
@property (nonatomic, copy) dispatch_block_t completion;
@property (nonatomic, strong) AWMutableURLRequest *req;
@property (nonatomic) AWRequestSignerType signatureType;
@property (nonatomic) BOOL isRequestHTTPS;
@property (nonatomic) BOOL isRequestDirect;
@property (nonatomic, retain) NSString * requestHost;
@property (nonatomic) BOOL isBrowser;
@property (nonatomic) BOOL isMAGTrusted;

@end

/**
 * \brief Forwards data from an input stream to an output stream
 *
 * \note This initial implementation favors simplicity over performance.
 * See @knownjira{FUJI-1966} for a discussion of future performance tuning.
 */
@implementation AWProxyForwarder

- (AWProxyForwarder *)initWithInput:(NSInputStream *)input
                             output:(NSOutputStream *)output
                              label:(NSString *)label
                              queue:(id<VHDispatchRunLoopQueuing>)queue
                      signatureType:(AWRequestSignerType)signatureType
                    isRequestDirect:(BOOL) isRequestDirect
                     isRequestHTTPS:(BOOL) isRequestHTTPS
                        requestHost:(NSString *) requestHost
{
    if (self = [super init]) {
        PROXY_TRACE(@"%@", self);
        _readBuf = NULL;
        _readBufBacking = NULL;
        _input = input;
        _input.delegate = self;
        _output = output;
        _output.delegate = self;
        self.label = label;
        self.queue = queue;
        self.signatureType = signatureType;
        self.requestHost = requestHost;
        self.isRequestDirect = isRequestDirect;
        self.isRequestHTTPS = isRequestHTTPS;
        self.isMAGTrusted = NO;
        
        self.isBrowser = NO;
        if (objc_getClass("ABURLProtocol") &&
            objc_getClass("AWBrowserAppDelegate"))
        {
            self.isBrowser = YES;
        }
    }
    return self;
}

/**
 * \brief Destroy a completed/closed forwarder
 */
- (void)dealloc
{
    PROXY_TRACE(@"%@", self);
    ASSERT(_completion == nil);
    ASSERT(_input == nil);
    ASSERT(_output == nil);
    
    _readBufBacking = nil;
    _tempBuffBacking = nil;
    _label = nil;
    _queue = nil;
    _readBuf = nil;
    _readBufEnd = nil;
}

/**
 * \brief Schedule the streams and start forwarding data
 *
 * \param completion Called when data forwarding has stopped and the streams have been closed. Called on
 *        the forwarder's queue / run loop.
 */
- (void)startWithCompletion:(dispatch_block_t)completion
{
    ASSERT(completion != nil);
    [self.queue enqueue:
     ^{
         ASSERT(self.completion == nil);
         self.completion = completion;
         // keep this object in memory until complete. Balanced by release in -complete.
         //[self retain];
         
         if (_input.streamStatus == NSStreamStatusNotOpen) {
             [_input scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
             [_input open];
         }
         if (_output.streamStatus == NSStreamStatusNotOpen) {
             [_output scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
             [_output open];
         }
         
         /* Handle CONNECT Requests for Direct Connections */
         
         if([self.label isEqualToString:@"inbound"] && self.isRequestDirect && self.isRequestHTTPS) {
             //We need to send back a 200 ok if the connection to the remote was made for a CONNECT statment.
             NSString *serializedString = @"HTTP/1.0 200 Connection established\r\n\r\n";
             
             if (_readBufBacking == nil) {
                 _readBufBacking = [[NSMutableData alloc]initWithCapacity:FPS_BUFF_SIZE];
                 _readBufBacking.length = FPS_BUFF_SIZE;
             }
             [_readBufBacking replaceBytesInRange:NSMakeRange(0, [serializedString length]) withBytes:[[serializedString dataUsingEncoding:NSUTF8StringEncoding] bytes]];
             _readBuf = _readBufBacking.mutableBytes;
             _readBufEnd = _readBuf + [serializedString length];
             
             [self write];
         }
         
         if([self.label isEqualToString:@"outbound"] && self.isRequestDirect && self.isRequestHTTPS) {
             //First read in whats on the input buffer.  This is done so we do not send a CONNECT to a regular web server.
             if(self.signatureType == AWRequestSignerTypeMAG) {
                 [self readFullRequest];
                 _readBufBacking = NULL;
             } else {
                 [self read];
             }
             _readBuf = NULL;
             _readBufEnd = NULL;
         }
     }];
}

/**
 * \brief Close streams and call the completion callback as necessary
 */
- (void)cancel
{
    [self.queue enqueue:
     ^{
         [self complete];
     }];
}

#pragma mark - Private implementation

/**
 * \brief Write buffered data to the output stream
 *
 * Clear the buffer if all data can be written.
 *
 * \return YES if some data was written (progress was made)
 *         NO if no data was written
 */
- (BOOL)write
{
    if (_readBuf != NULL &&
        _output.hasSpaceAvailable &&
        _readBufEnd != _readBuf /* read EOF case */) {
        
        _HTTPRequest = CFHTTPMessageCreateEmpty(kCFAllocatorDefault,true);
        
        CFHTTPMessageAppendBytes(_HTTPRequest, _readBuf, (_readBufEnd - _readBuf));
        
        //get Body
        NSData *body = (NSData *)CFBridgingRelease(CFHTTPMessageCopyBody(_HTTPRequest));
        NSUInteger bodySize = 0;
        if (body) bodySize = [body length];
        
        NSArray *originalChunks;
        if (!self.isRequestDirect) {
            NSString * originalSerializedString = [[NSString alloc] initWithBytes:(const char *)_readBuf length:(_readBufEnd - _readBuf - bodySize) encoding:NSUTF8StringEncoding];
            originalChunks = [originalSerializedString componentsSeparatedByString: @"\r\n"];
        }
        
        NSString *requestMethod = (NSString *)CFBridgingRelease(CFHTTPMessageCopyRequestMethod(_HTTPRequest));
        if ([self.label isEqualToString:@"outbound"] &&  requestMethod &&
            ([requestMethod caseInsensitiveCompare:@"CONNECT"] == NSOrderedSame ||
             [requestMethod caseInsensitiveCompare:@"GET"] == NSOrderedSame||
             [requestMethod caseInsensitiveCompare:@"POST"] == NSOrderedSame||
             [requestMethod caseInsensitiveCompare:@"PUT"] == NSOrderedSame||
             [requestMethod caseInsensitiveCompare:@"DELETE"] == NSOrderedSame||
             [requestMethod caseInsensitiveCompare:@"OPTIONS"] == NSOrderedSame||
             [requestMethod caseInsensitiveCompare:@"HEAD"] == NSOrderedSame||
             [requestMethod caseInsensitiveCompare:@"PATCH"] == NSOrderedSame)) {
                
                if (self.isBrowser)
                {
                    /* If SecureBrowser then check if authorization header is present */
                    NSString *header = (__bridge_transfer NSString *) CFHTTPMessageCopyHeaderFieldValue(_HTTPRequest,
                                                                                                        (__bridge CFStringRef)@"Proxy-Authorization");
                    
                    CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"Proxy-Authorization", NULL);
                    CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"Proxy-Connection", NULL);
                    
                    if (nil == header || (header.length <= 0) ||
                        (0 == isTokenValid([header UTF8String])))
                    {
                        CFRelease(_HTTPRequest);
                        _HTTPRequest = nil;
                        [self complete];
                        return NO;
                    }
                }
                
                
                NSInteger contentLength = [(__bridge_transfer NSString *) CFHTTPMessageCopyHeaderFieldValue(_HTTPRequest,
                                                                                                            (__bridge CFStringRef)@"Content-Length") integerValue];
                
                if ((self.signatureType == AWRequestSignerTypeMAG) &&
                    (contentLength > [body length]))
                {
                    /* We have not received all the data for MAG */
                    CFRelease(_HTTPRequest);
                    _HTTPRequest = nil;
                    return YES;
                }
                
                
                CFURLRef cfURL = CFHTTPMessageCopyRequestURL(_HTTPRequest);
                
                NSString *scheme =  (NSString *)CFBridgingRelease(CFURLCopyScheme(cfURL));
                NSString *host = (NSString *)CFBridgingRelease(CFURLCopyNetLocation(cfURL));
                if ([requestMethod caseInsensitiveCompare:@"CONNECT"] == NSOrderedSame && self.isRequestDirect)
                {
                    CFRelease(cfURL);
                    _readBuf = NULL;
                    _readBufEnd = NULL;
                    _readBufBacking = NULL;
                    CFRelease(_HTTPRequest);
                    _HTTPRequest = nil;
                    return YES;
                }
                
                if(!host.length || ![[scheme lowercaseString] isEqualToString:@"http"]){
                    if ([requestMethod caseInsensitiveCompare:@"CONNECT"] == NSOrderedSame)
                    {
                        /* Temporary fix :: REFACTOR CODE */
                        NSMutableString *tempURL = [NSMutableString stringWithFormat:@"%@", cfURL];
                        if(tempURL && ![tempURL hasPrefix:@"http"]) {
                            [tempURL insertString:@"https://" atIndex:0];
                        }
                        
                        NSURL *url = [[NSURL alloc] initWithString:tempURL];
                        NSInteger portVal = [[url port] integerValue];
                        
                        if(portVal != 80 && portVal != 443) {
                            host = [NSString stringWithFormat:@"%@", cfURL];
                        } else {
                            host = scheme;
                        }
                        
                        scheme = @"https";
                    }
                }
                
                
                CFRelease(cfURL);
                
                /*
                 The below fix was done w.r.t issues IBRW-170243 & IBRW-169928.
                 Prior to fixing IBRW-170243, the IBRW-169928 issue was fixed by not removing the ports from host and self.requestHost.
                 */
                
                 // if any of the below ports, it will be removed from self.requestHost
                
                NSArray* hostPort = [host componentsSeparatedByString:@":"];
                
                NSArray* reHostPort = [self.requestHost componentsSeparatedByString:@":"];

                if (hostPort.count && reHostPort.count && ![hostPort[0] isEqualToString:reHostPort[0]])
                {
                    CFRelease(_HTTPRequest);
                    _HTTPRequest = nil;
                    [self complete];
                    return NO;
                }
                
                
                
                
                if (self.signatureType == AWRequestSignerTypeMAG && self.isMAGTrusted) {
                    //Add signature and proper Request line if PROXY:
                    NSString *urlWithSchemeString;
                    if ([requestMethod caseInsensitiveCompare:@"CONNECT"] == NSOrderedSame) {
                        urlWithSchemeString = [NSString stringWithFormat:@"%@://%@", scheme, host];
                    } else {
                        urlWithSchemeString = [NSString stringWithFormat:@"%@",CFHTTPMessageCopyRequestURL(_HTTPRequest)];
                    }
                    
                    NSURL *url = [[NSURL alloc] initWithString:urlWithSchemeString];
                    
                    AWMutableURLRequest *req = [[AWMutableURLRequest alloc] initWithURL:url];
                    [req setHTTPMethod:requestMethod];
                    [req setHTTPBody:body];
                    
                    NSString* Host = (__bridge_transfer NSString *) CFHTTPMessageCopyHeaderFieldValue(_HTTPRequest,
                                                                                                      (__bridge CFStringRef)@"Host");
                    NSNumber *hostPort = nil;
                    NSArray* hostParts = [Host componentsSeparatedByString:@":"];

                    //Host can have port, host:port
                    if(hostParts.count == 2){
                        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                        hostPort = [numberFormatter numberFromString:hostParts[1]];
                    }
                    
                    req = [[AWRequestSigner sharedInstance] MAGSignedRequestWithPort:hostPort andRequest:req error:NULL];
                    
                    if (!req) {
                        CFRelease(_HTTPRequest);
                        _HTTPRequest = nil;
                        [self complete];
                        return NO;
                    }

                    
                    NSString *proxyAuth = [[req allHTTPHeaderFields] valueForKey:@"Proxy-Authorization"];
                    NSString *jsonString = [[req allHTTPHeaderFields] valueForKey:@"aa-device-info"];
                    
                    CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"Proxy-Authorization", (__bridge CFStringRef)proxyAuth);
                    CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"DNT", (__bridge CFStringRef)@"1");
                    
                    if(jsonString.length){
                        CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"aa-device-info", (__bridge CFStringRef)jsonString);
                    }
                    
                    
                } else if (self.signatureType == AWRequestSignerTypeWebSense) {
                    
                    NSString *urlWithSchemeString = [NSString stringWithFormat:@"%@://%@", scheme, host];
                    
                    NSURL *url = [[NSURL alloc] initWithString:urlWithSchemeString];
                    
                    AWMutableURLRequest *req = [[AWMutableURLRequest alloc] initWithURL:url];
                    [req setHTTPMethod:requestMethod];
                    [req setHTTPBody:body];
                    
                    req = [[AWRequestSigner sharedInstance] newSignedRequestForWebSense:req error:NULL];
                    
                    NSString *accountId = [[req allHTTPHeaderFields] valueForKey:@"X-Ws-Mobile-Account-Id"];
                    NSString *version = [[req allHTTPHeaderFields] valueForKey:@"X-Ws-Ver"];
                    NSString *mobileVersion = [[req allHTTPHeaderFields] valueForKey:@"X-Ws-Mobile-Ver"];
                    NSString *auth = [[req allHTTPHeaderFields] valueForKey:@"X-Ws-Auth"];
                    
                    CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"X-Ws-Mobile-Account-Id", (__bridge CFStringRef)accountId);
                    CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"X-Ws-Ver", (__bridge CFStringRef)version);
                    CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"X-Ws-Mobile-Ver", (__bridge CFStringRef)mobileVersion);
                    CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"X-Ws-Auth", (__bridge CFStringRef)auth);
                    
                    
                } else if (self.signatureType == AWRequestSignerTypeBASIC) {
                    CFHTTPMessageAddAuthentication(_HTTPRequest, NULL, (__bridge CFStringRef)[[AWProxy sharedInstance] username], (__bridge CFStringRef)[[AWProxy sharedInstance] password], kCFHTTPAuthenticationSchemeBasic, YES);
                }
                
                CFDataRef serialized = CFHTTPMessageCopySerializedMessage(_HTTPRequest);
                NSString * serializedString = [[NSString alloc] initWithBytes:(const char *)[(__bridge_transfer NSMutableData *) serialized bytes] length:(CFDataGetLength(serialized) - bodySize) encoding:NSUTF8StringEncoding];
                
                // Replace first line with original line from sender.
                // CFHTTPMessageCopySerializedMessage serializes the message for
                // non proxy mode
                if(!self.isRequestDirect && originalChunks) {
                    NSMutableArray *chunks = [[serializedString componentsSeparatedByString: @"\r\n"] mutableCopy];
                    if(chunks) {
                        chunks[0] = originalChunks[0];
                        serializedString = [[chunks valueForKey:@"description"] componentsJoinedByString:@"\r\n"];
                    }
                }
                
                NSMutableData *serializedData = [[NSMutableData alloc] initWithBytes:[serializedString cStringUsingEncoding:NSUTF8StringEncoding] length:[serializedString length]];
                if(body) [serializedData appendBytes:[body bytes] length:[body length]];
                
                _readBuf = (uint8_t *) [serializedData bytes];
                _readBufEnd = _readBuf + [serializedData length];
            }
        
        NSInteger written = [_output write:_readBuf
                                 maxLength:_readBufEnd - _readBuf];
        
        CFRelease(_HTTPRequest);
        _HTTPRequest = nil;
        
        if (written > 0) {
            NSString * string __unused = [[NSString alloc] initWithBytes:(const char *)_readBuf length:written encoding:NSUTF8StringEncoding];
            if(string) {
                AWLogDebug(@"\n%@ \n******** WROTE TO: %@", string, self.label);
            }
            
            [self evaluateMAGCertificateRefetch:originalChunks];
            _readBuf += written;
            if (_readBuf == _readBufEnd) {
                _readBuf = NULL;
                _readBufEnd = NULL;
                if (self.signatureType == AWRequestSignerTypeMAG) _readBufBacking = NULL;
            }
            return YES;
        }
    }
    return NO;
}

-(void)evaluateMAGCertificateRefetch:(NSArray*)originalChunks
{
    if (originalChunks.count >= 2) {
        NSString *statusCodeString = originalChunks[0];
        if ([self.label isEqualToString:@"inbound"] && [statusCodeString containsString:@"407 Proxy Authentication Required"]) {
            NSInteger awErrorCode = [self getAWErrorCode:originalChunks];
            if(awErrorCode == NSNotFound){
                return;
            }
            switch (awErrorCode) {
                case AWProxyErrorMAG407ForbiddentMethod:
                    // Use cmsv1 as a fallback in case of invalid sign data.
                    AWLogDebug(@"Mag error %ld", (long)awErrorCode);
                    [[AWRequestSigner sharedInstance] setUseCmsv2:NO];
                    break;
                default:
                    [[NSNotificationCenter defaultCenter] postNotificationName:AWRefetchMAGCertificate object:nil userInfo:@{ AWMAGCertFetchFailureErrorCode : @(awErrorCode) }];
                    break;
            }
        }
    }
}

/**
 *  Scans through the originalChunks array to find a string that contains kAWSDKMAGErrorCodeKey, returns MAG error code else default 0.
 */
-(NSInteger)getAWErrorCode:(NSArray*)originalChunks
{
    NSInteger awErrorCode = NSNotFound;
    for (NSString *aString in originalChunks) {
        if ([aString containsString:kAWSDKMAGErrorCodeKey]) {
            NSArray *awErrorCodeArray = [aString componentsSeparatedByString:@":"];
            if (awErrorCodeArray.count == 2){
                awErrorCode = [awErrorCodeArray[1] integerValue];
            }
        }
    }
    return awErrorCode;
}

/**
 * \brief Read data from the input stream
 *
 * \return YES if some data was read (progress was made)
 *         NO if no data was read
 *
 * [VP] Keeping this around incase we decide to change mag signing.
 */
- (BOOL)read
{
    if (_readBuf == NULL && _input.hasBytesAvailable) {
        
        if (_readBufBacking == nil) {
            _readBufBacking = [[NSMutableData alloc]initWithCapacity:FPS_BUFF_SIZE];
            _readBufBacking.length = FPS_BUFF_SIZE;
        }
        NSInteger read = [_input read:_readBufBacking.mutableBytes
                            maxLength:_readBufBacking.length];
        if (read > 0) {
            _readBuf = _readBufBacking.mutableBytes;
            _readBufEnd = _readBuf + read;
            //NSString * string __unused = [[NSString alloc] initWithBytes:(const char *)_readBuf length:(_readBufEnd - _readBuf) encoding:NSUTF8StringEncoding];
            //if(string) NSLog(@"\n%@ \n***^ was %d ***** read from: %@", string, read, self.label);
            return YES;
        }
    }
    return NO;
}


/**
 * \brief Read data from the input stream
 *
 * \return YES if some data was read (progress was made)
 *         NO if no data was read
 */
- (BOOL)readFullRequest
{
    if (_input.hasBytesAvailable) {
        
        if (_tempBuffBacking == nil) {
            _tempBuffBacking = [[NSMutableData alloc] initWithCapacity:FPS_BUFF_SIZE];
            _tempBuffBacking.length = FPS_BUFF_SIZE;
            
        } else {
            //Zero out temp buffer
            [_tempBuffBacking resetBytesInRange:NSMakeRange(0, FPS_BUFF_SIZE)];
        }
        
        NSInteger read = [_input read:_tempBuffBacking.mutableBytes
                            maxLength:_tempBuffBacking.length];
        if (read > 0) {
            if(_readBufBacking == nil) {
                _readBufBacking = [[NSMutableData alloc] initWithBytes:_tempBuffBacking.mutableBytes length:read];
                _readBufBacking.length = read;
            } else {
                NSUInteger buffLenthBefore = _readBufBacking.length;
                [_readBufBacking appendBytes:_tempBuffBacking.mutableBytes length:read];
                //We must truncate the buffer because appending bytes grows it beyond what we need.
                _readBufBacking.length = buffLenthBefore + read;
            }
            
        }
        
        
        if (!_input.hasBytesAvailable && _readBufBacking.length > 0) {
            _readBuf = _readBufBacking.mutableBytes;
            _readBufEnd = _readBuf + _readBufBacking.length;
            //NSString * string __unused = [[NSString alloc] initWithBytes:(const char *)_readBuf length:(_readBufEnd - _readBuf) encoding:NSUTF8StringEncoding];
            //if(string) NSLog(@"\n%@ \n***^ was %d ***** read from: %@", string, _readBufBacking.length, self.label);
            //NSLog(@"\n\n***^ was %d: count:%d ***** read from: %@\n\n", _readBufBacking.length, count, self.label);
            return YES;
        }
    }
    return NO;
}

/**
 * \brief If we have reached a terminal condition complete forwarding
 */
- (void)tryComplete
{
    if (_readBuf == NULL && _input.streamStatus == NSStreamStatusAtEnd) {
        // no more data to deliver
        [self complete];
        return;
    }
    if (_output.streamStatus == NSStreamStatusError) {
        PROXY_TRACE(@"%@: output.streamError: %@", self.label, _output.streamError);
        // nothing more we can do
        [self complete];
        return;
    }
    if (_readBuf == NULL && _input.streamStatus == NSStreamStatusError) {
        PROXY_TRACE(@"%@: input.streamError: %@", self.label, _input.streamError);
        
        /*
         * \todo @knownjira{FUJI-1627} proxy errors by calling close() without shutdown(). That should generate
         * a RST. We may need to detach from the CF stream to do this?
         */
        
        [self complete];
        return;
    }
}

/**
 * \brief stop forwarding and call our completion block
 */
- (void)complete
{
    
    _readBuf = NULL;
    _readBufEnd = NULL;
    _readBufBacking = NULL;
    
    if (self.completion != nil) {
        PROXY_TRACE(@"%@", self);
        [_input close];
        _input = nil;
        [_output close];
        _output = nil;
        self.completion();
        self.completion = nil;
    }
}

#pragma mark - NSStreamDelegate

/**
 * \brief Implement NSStreamDelegate
 *
 * Greedily write and read data until we can nolonger make progress.
 *
 * \todo @knownjira{FUJI-1966} fairness - after some number of iterations re-queue to the run loop
 */
- (void)stream:(NSStream*)stream
   handleEvent:(NSStreamEvent)eventCode
{
    if (stream == _output &&
        !self.isMAGTrusted &&
        self.signatureType == AWRequestSignerTypeMAG &&
        eventCode == NSStreamEventHasSpaceAvailable)
    {
        /* Only check for trusted if MAG and outbound */
        self.isMAGTrusted = [self verifyCertificateForStream:(NSOutputStream *)stream];
        
        if(!self.isMAGTrusted) {
            AWLogVerbose(@"MAG Certificate not trusted! Please check the SSL Certificate.");
            [self complete];
            return;
        }
        
    }
    
    PROXY_TRACE(@"%@(%p): event:%@", self.label, stream, NSStreamEventDescription(eventCode));
    PROXY_TRACE(@"input.streamStatus:%@ output.streamStatus:%@ readBuf:%p len:%d",
                NSStreamStatusDescription(_input.streamStatus),
                NSStreamStatusDescription(_output.streamStatus),
                _readBuf,
                (int)(_readBuf ? _readBufEnd - _readBuf : 0));
    if (eventCode == NSStreamEventOpenCompleted) {
        if ([stream isKindOfClass:[NSInputStream class]]) {
            CFReadStreamRef readStream = (__bridge CFReadStreamRef)(NSInputStream *)stream;
            CFSocketNativeHandle remoteSocket = GetNativeReadHandle(readStream);
            if (setsockopt(remoteSocket, IPPROTO_TCP, TCP_NODELAY, &(int){ 1 }, sizeof(int)) != 0) {
                LOG_WARNING(@"unable to set TCP_NODELAY");
            }
        } else if ([stream isKindOfClass:[NSOutputStream class]]) {
            CFSocketNativeHandle remoteSocket = GetNativeWriteHandle((__bridge CFWriteStreamRef)(NSOutputStream *)stream);
            if (setsockopt(remoteSocket, IPPROTO_TCP, TCP_NODELAY, &(int){ 1 }, sizeof(int)) != 0) {
                LOG_WARNING(@"unable to set TCP_NODELAY");
            }
            
            
        }
        
        
    }
    
    if ((eventCode == NSStreamEventHasBytesAvailable || eventCode == NSStreamEventHasSpaceAvailable)
        && _output && _output.hasSpaceAvailable) {

        BOOL wrote = NO;
        BOOL read = NO;
        
        do {
            if (self.signatureType == AWRequestSignerTypeMAG) {
                read = [self readFullRequest];
                if(!_input.hasBytesAvailable)
                    wrote = [self write];
            } else {
                read = [self read];
                wrote = [self write];
            }
        } while (read || wrote);
        
        
        [self tryComplete];
    }
}



-(BOOL)verifyCertificateForStream:(NSOutputStream *)theStream
{
    SecTrustRef trust = (__bridge SecTrustRef)[theStream propertyForKey: (__bridge NSString *)kCFStreamPropertySSLPeerTrust];
    
    if ([[[AWProxy sharedInstance] getSSLPinningCertificates] count] > 0)
    {
        /* Always perform SSL Pinning for MAG regardless of public or not */
        /* ONLY FOR Console 8.0 and above                                 */
        SecTrustResultType trustResult = [self evaluateTrust:trust
                                                 withAnchors:(__bridge CFArrayRef)[[AWProxy sharedInstance] getSSLPinningCertificates]
                                                 anchorsOnly:YES];

        if ((kSecTrustResultUnspecified == trustResult) ||
            (kSecTrustResultProceed == trustResult)) {
            return YES;
        }
#if DEBUG
        else {
            NSDictionary * dict __unused = (__bridge_transfer NSDictionary *)SecTrustCopyResult(trust);
            NSArray * props __unused = (__bridge_transfer NSArray *)SecTrustCopyProperties(trust);
        }
#endif
        //Certificate did not match so do not allow!
        return NO;
    }
    
    
    /* For public certs lets just evaluate the trust as is agains iOS anchors */
    /* Only used for 7.x consoles and lower                                   */
    SecTrustResultType trustResult = [self evaluateTrust:trust withAnchors:NULL anchorsOnly:NO];
    if (trustResult == kSecTrustResultProceed ||
        trustResult == kSecTrustResultUnspecified)
    {
        return YES;
    }
    
    /* If no pinning certificate or public cert verification fails then check the chain against our        */
    /* device services root if not using public                                                            */
    /* Only used for 7.x consoles and lower                                                                */
    SecCertificateRef deviceServiceRoot = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)[[AWProxy sharedInstance] getDeviceServiceRootCertificate]);
    NSArray *anchorArray = @[(__bridge_transfer id)deviceServiceRoot];
    
    trustResult = [self evaluateTrust:trust withAnchors:(__bridge CFArrayRef)anchorArray anchorsOnly:YES];
    
    if ((kSecTrustResultUnspecified == trustResult) ||
        (kSecTrustResultProceed == trustResult)) {
        return YES;
    } else if ((kSecTrustResultRecoverableTrustFailure == trustResult) &&
               [self verifyAirWatchCertifcatesForStream:theStream]) {
        /* To support older consoles we are manually verifying chain */
        return YES;
    }
    
    return NO;
}

-(SecTrustResultType) evaluateTrust: (SecTrustRef) trust withAnchors:(CFArrayRef)anchorsArray anchorsOnly: (BOOL) anchorsOnly
{
    if (![[AWProxy sharedInstance] usePublicMAGCert]) {
        /* REMOVE when everyone moves to console 8. */
        /* Disable hostname checking as console does not set the hostname in the certificate */
        SecPolicyRef policy = SecPolicyCreateSSL(YES, nil);
        SecTrustSetPolicies(trust, policy);
        CFRelease(policy);
    }

#if DEBUG
    NSInteger count = SecTrustGetCertificateCount(trust);
    for (int i = 0; i < count; i++) {
        SecCertificateRef trustCert = SecTrustGetCertificateAtIndex(trust, i);
        CFStringRef certSummary = SecCertificateCopySubjectSummary(trustCert);
        NSString* summaryString = [[NSString alloc] initWithString:(__bridge NSString*)certSummary];
        AWLogDebug(@"SSL Server Certificate SUMMARY ***************: %@", summaryString);
        CFRelease(certSummary);
    }
#endif
    
    if (anchorsArray) {
#if DEBUG
        for (int i = 0; i < CFArrayGetCount(anchorsArray); i++) {
            SecCertificateRef cert = (SecCertificateRef)CFArrayGetValueAtIndex(anchorsArray, i);
            CFStringRef certSummary = SecCertificateCopySubjectSummary(cert);
            NSString* summaryString = [[NSString alloc] initWithString:(__bridge NSString*)certSummary];
            AWLogDebug(@"SSL Pinning Certificate SUMMARY ***************: %@", summaryString);
            CFRelease(certSummary);
        }
#endif
        SecTrustSetAnchorCertificates(trust, anchorsArray);
        SecTrustSetAnchorCertificatesOnly(trust, anchorsOnly);
    }
    
    SecTrustResultType trustResult;

    OSStatus result = SecTrustEvaluate(trust, &trustResult);
    if (result != errSecSuccess) {
        return kSecTrustResultInvalid;
    }
    
    return trustResult;
}

-(BOOL)verifyAirWatchCertificate:(NSData *)certificateData
{
    AWX509Wrapper *x509 = [[AWX509Wrapper alloc] initWithCertificateData: certificateData];
    AWX509Wrapper *root = [[AWX509Wrapper alloc] initWithCertificateData: [AWProxyCertService deviceRootCertificate]];

    return [x509 verifyWithRootCertificate: root];
}

-(BOOL)verifyAirWatchCertifcatesForStream:(NSOutputStream *)theStream
{
    BOOL trusted = NO;
    /* DEPRECATED Key. Remove when everyone moves to Console 8 */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    //TODO: using deprecated stuff. Please look into this.
    NSArray *streamCertificates = [theStream propertyForKey:(NSString *)kCFStreamPropertySSLPeerCertificates];
#warning "FIXME: 💡Using deprecated stuff... Needed A fix. 🔧"    
#pragma GCC diagnostic pop
    


    AWLogVerbose(@"Attempting to use AirWatch Internal Certificate.");
    //========== Validate If  Airwatch Internal Certificate ==========//
    if(streamCertificates && [streamCertificates count]) {
        NSUInteger count = [streamCertificates count];
        NSUInteger index = 0;
        while (index < count && !trusted)
        {
            SecCertificateRef cert = (__bridge SecCertificateRef)streamCertificates[index];
#if DEBUG
            CFStringRef certSummary = SecCertificateCopySubjectSummary(cert);
            NSString* summaryString = [[NSString alloc] initWithString:(__bridge NSString*)certSummary];
            AWLogDebug(@"Certificate SUMMARY ***************: %@", summaryString);
            CFRelease(certSummary);
#endif
            NSData *certificateData = (NSData *) CFBridgingRelease(SecCertificateCopyData(cert));

            trusted = [self verifyAirWatchCertificate:certificateData];

            index++;
        }
    }

    return trusted;
}

@end
