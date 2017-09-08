//
//  AWProxyConnection.m
//  AirWatch
//
//  Created by Vishal Patel on 7/11/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//


#import "AWContentFilter.h"
#import "AWContentFilterHandler.h"
#import "AWProxy+Private.h"
#import "AWProxyConnection.h"
#import "AWProxyForwarder.h"
#import "AWProxyHandler.h"
#import "AWTunnelLogger.h"

#import "VHProxyUtils.h"

#import "NSURLRequest+HTTPMessage.h"
#import "ProxyAuthTokenHelper.h"

#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
#import "AWF5ProxyController.h"
#import "AWProxy_F5.h"
#endif

#import "Fuji.h"
#import "VHDispatchRunLoopQueuing.h"
#import "NSStreamUtils.h"

#include <netinet/in.h>
#include <netinet/tcp.h>

#import <CoreFoundation/CoreFoundation.h>
#import <AWTunnel/AWTunnel-Swift.h>


#define FPS_BUFF_SIZE 4096

@interface AWProxyConnection (){
    // members accessed on the data forwarding path are Ivars to avoid Obj-C dispatches
    uint8_t *_localReadBuf;
    uint8_t *_localReadBufEnd;
    NSMutableData *_localReadBufBacking;
    
    uint8_t *_remoteReadBuf;
    uint8_t *_remoteReadBufEnd;
    NSMutableData *_remoteReadBufBacking;
@private
    CFHTTPMessageRef _HTTPRequest;
}

@property (nonatomic, retain) id<VHDispatchRunLoopQueuing> queue;
@property (nonatomic, copy) dispatch_block_t completion;

@property (nonatomic, retain) AWProxyForwarder *outbound;
@property (nonatomic, retain) AWProxyForwarder *inbound;

@property (nonatomic, retain) NSInputStream *localInput;
@property (nonatomic, retain) NSOutputStream *localOutput;
@property (nonatomic, retain) NSInputStream *remoteInput;
@property (nonatomic, retain) NSOutputStream *remoteOutput;
@property (nonatomic, assign) AWRequestSignerType signType;
@property (nonatomic, assign) CFSocketNativeHandle localSocket;
//@property (nonatomic, assign) AWProxyServerType remoteType;

@end


@implementation AWProxyConnection

/**
 * \brief Destroy a closed connection
 *
 * By the time dealloc is called both of the forwarders should have completed.
 */
- (void)dealloc
{
    PROXY_TRACE(@"");
    ASSERT(_completion == nil);
    //[_queue release];
    _queue = nil;
    _localInput = nil;
    _localOutput = nil;
    _remoteOutput = nil;
    _remoteInput = nil;
    _localReadBuf = nil;
    _localReadBufEnd = nil;
    _remoteReadBuf = nil;
    _remoteReadBufEnd = nil;
    if(_HTTPRequest) {
        CFRelease(_HTTPRequest);
    }
    //[super dealloc];
}

/**
 * \brief Start a newly allocated connection from a local socket to a host:port
 *
 * \param localSocket the local socket
 * \param host the proxy server host
 * \param port the proxy server port
 */
-    (void)startWithQueue:(id<VHDispatchRunLoopQueuing>)queue
              localSocket:(CFSocketNativeHandle)localSocket
                     host:(NSString *)host
                     port:(NSInteger)port
 authenticateCertificates:(BOOL)authenticateCertificates
               completion:(dispatch_block_t)completion
{
    PROXY_TRACE(@"localSocket:%d, host:%@, port:%ld", localSocket, host, (long)port);
#if DEBUG
    AWLogDebug(@"New Socket: %d Host: %@, Port: %ld", localSocket, host, (long)port);
#endif
    self.localSocket = localSocket;
    ASSERT(self.queue == nil);
    self.queue = queue;
    [self.queue enqueue:
     ^{
         ASSERT(self.completion == nil);
         self.completion = completion;
         
         if (setsockopt(localSocket, IPPROTO_TCP, TCP_NODELAY, &(int){ 1 }, sizeof(int)) != 0) {
             // this is a non-fatal error. (convert to LOG_DEBUG?)
             LOG_ERROR(@"unable to set TCP_NODELAY");
         }
         
         CFReadStreamRef localRead = NULL;
         CFWriteStreamRef localWrite = NULL;
         CFStreamCreatePairWithSocket(kCFAllocatorDefault,
                                      localSocket,
                                      &localRead,
                                      &localWrite);
         NOT_IMPLEMENTED_IF(!localRead || !localWrite);
         _localInput = (__bridge_transfer NSInputStream *)localRead;
         _localOutput = (__bridge_transfer NSOutputStream *)localWrite;
         if (![_localInput setProperty:(id)kCFBooleanTrue
                               forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket]) {
             NOT_IMPLEMENTED();
         }
         
         [_localInput setDelegate:self];
         [_localOutput setDelegate:self];
         
         _signType = AWRequestSignerTypeNONE;
         if ([[AWProxy sharedInstance] type] == AWproxyServerTypeMAG) {
             _signType = AWRequestSignerTypeMAG;
         } else if ([[AWProxy sharedInstance] type] == AWProxyServerTypeStandard) {
             _signType = AWRequestSignerTypeBASIC;
         }
         
         [_localInput scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
         [_localOutput scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
         if (_localInput.streamStatus == NSStreamStatusNotOpen) {
             [_localInput open];
         }
         if (_localOutput.streamStatus == NSStreamStatusNotOpen) {
             [_localOutput open];
         }
         
         
     }];
}

/**
 * \brief Asynchronously close the connection
 */
- (void)close
{
    [self.queue enqueue:
     ^{
         if(_remoteInput) [_remoteInput close];
         if(_remoteOutput) [_remoteOutput close];
         if(_localInput) [_localInput close];
         if(_localOutput) [_localOutput close];
         
         _remoteInput = nil;
         _remoteOutput = nil;
         _localInput= nil;
         _localOutput= nil;
        
         if(self.completion != nil) {
             self.completion();
             self.completion = nil;
         }
     }];
}

#pragma mark - NSStreamDelegate
/**
 * \brief If we have reached a terminal condition complete forwarding
 */
- (void)tryComplete
{
    if (self.inbound == nil && self.outbound == nil && self.completion != nil) {
        self.completion();
        self.completion = nil;
    }
}

- (BOOL)write407
{
    if (_localOutput.hasSpaceAvailable) {
        NSString *serializedString = @"HTTP/1.1 407 ProxyAuthentication Required\r\nProxy-Authenticate:NTLM\r\nProxy-Connection:close\r\n\r\n";
        
        NSInteger written = [_localOutput write:[[serializedString dataUsingEncoding:NSUTF8StringEncoding] bytes]
                                 maxLength:[serializedString length]];
        
        
        if (written > 0) {
            return YES;
        }
    }
    return NO;
}

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
    switch (eventCode)
    {
        case NSStreamEventHasBytesAvailable:
        {
            int ret;
            UInt8 buff[FPS_BUFF_SIZE];
            ret = (int)recv(self.localSocket, buff, FPS_BUFF_SIZE, MSG_PEEK | MSG_DONTWAIT);
            if(ret > 0) {
                [self processRequestForBuffer:buff size:ret];
            }
            break;
        }
        default:
            break;
    } /* switch */
}
#pragma mark - Private implementation

-(void) processRequestForBuffer:(UInt8 *)buffer size:(int)size
{
    _HTTPRequest = CFHTTPMessageCreateEmpty(kCFAllocatorDefault,true);
    
    CFHTTPMessageAppendBytes(_HTTPRequest, buffer, size);
    
    NSString *requestMethod = (NSString *)CFBridgingRelease(CFHTTPMessageCopyRequestMethod(_HTTPRequest));
    if (requestMethod &&
        ([requestMethod caseInsensitiveCompare:@"CONNECT"] == NSOrderedSame ||
         [requestMethod caseInsensitiveCompare:@"GET"] == NSOrderedSame||
         [requestMethod caseInsensitiveCompare:@"POST"] == NSOrderedSame||
         [requestMethod caseInsensitiveCompare:@"PUT"] == NSOrderedSame||
         [requestMethod caseInsensitiveCompare:@"DELETE"] == NSOrderedSame||
         [requestMethod caseInsensitiveCompare:@"OPTIONS"] == NSOrderedSame||
         [requestMethod caseInsensitiveCompare:@"HEAD"] == NSOrderedSame||
         [requestMethod caseInsensitiveCompare:@"PATCH"] == NSOrderedSame)) {
            
            if (objc_getClass("ABURLProtocol") &&
                objc_getClass("AWBrowserAppDelegate"))
            {
                /* If SecureBrowser then check if authorization header is present */
                NSString *header = (__bridge_transfer NSString *) CFHTTPMessageCopyHeaderFieldValue(_HTTPRequest,
                                                                                                    (__bridge CFStringRef)@"Proxy-Authorization");
            
                if (nil == header || (header.length <= 0) ||
                     (0 == isTokenValid([header UTF8String])))
                {
                    [self close];
                    return;
                }
            }
            
            CFURLRef cfURL = CFHTTPMessageCopyRequestURL(_HTTPRequest);
            
            NSString *scheme =  (NSString *)CFBridgingRelease(CFURLCopyScheme(cfURL));
            NSString *host = (NSString *)CFBridgingRelease(CFURLCopyNetLocation(cfURL));
            //free up cfURL
            CFRelease(cfURL);
            
            if(!host.length || ![[scheme lowercaseString] isEqualToString:@"http"]){
                
                if ([requestMethod caseInsensitiveCompare:@"CONNECT"] == NSOrderedSame)
                {
                    scheme = @"https";
                }
            }
            NSString *urlWithSchemeString = [NSString stringWithFormat:@"%@", cfURL];
            
            if(![urlWithSchemeString hasPrefix:@"http"]) {
                urlWithSchemeString = [NSString stringWithFormat:@"%@://%@", scheme, cfURL];
            }
            
            NSURL *url = [[NSURL alloc] initWithString:urlWithSchemeString];
            AWMutableURLRequest *req = [[AWMutableURLRequest alloc] initWithURL:url];
            [req setHTTPMethod:requestMethod];
            
            /* Configure remote streams based on tunnelling */
            [self configureStreamBasedOnRequest:req];
        }
    
    
    CFRelease(_HTTPRequest);
    _HTTPRequest = nil;
    
}
#pragma StreamConfiguration

-(void)configureStreamBasedOnRequest:(NSURLRequest *) request
{
    
    id proxyDelegate = [[AWProxy sharedInstance] delegate];
    
    NSString *scheme;
    NSString * host;
    NSInteger port = 443;
    BOOL isDirect = NO;
    AWRequestSignerType signatureType = AWRequestSignerTypeNONE;
    AWProxyServerType remoteType = AWProxyServerTypeUnknown;
    AWProxy *awproxySharedInstance = [AWProxy sharedInstance];
    AWContentFilter *contentFilterInstance = [AWContentFilter sharedInstance];
    
    BOOL shouldRouteToProxy = NO;
    
    if ([awproxySharedInstance isEnabled] && [proxyDelegate respondsToSelector:@selector(proxyShouldHandleRequest:)])
    {
        if ([proxyDelegate proxyShouldHandleRequest:request])
        {
            //Connect via proxy
            shouldRouteToProxy = YES;
        }
    }
    
    if(shouldRouteToProxy || [AWProxy sharedInstance].appTunnelDomains.count == 0)
    {
        host = [awproxySharedInstance host];
        port = [awproxySharedInstance httpsPort];
        
        remoteType = [awproxySharedInstance type];
        
        if(remoteType == AWproxyServerTypeMAG) {
            scheme = @"https";
            signatureType = AWRequestSignerTypeMAG;
        } else if (remoteType == AWProxyServerTypeStandard) {
            scheme = @"http";
            
            if ([awproxySharedInstance autoConfigURL]) {
                [awproxySharedInstance setProxySettingsForURL:[request URL]];
                host = [awproxySharedInstance host];
                port = [awproxySharedInstance httpPort];
            }
            
            if ([awproxySharedInstance requiresAuth] &&
                [awproxySharedInstance username] &&
                [awproxySharedInstance password]) {
                
                signatureType = AWRequestSignerTypeBASIC;
            }
        }
    }
    
     if ([contentFilterInstance isEnabled] && !shouldRouteToProxy)
     {
         NSDictionary *proxyInfo = [contentFilterInstance getProxySettingsForURL:[request URL]];
         
         scheme = (NSString *)kCFProxyTypeHTTP;
         
         port = [[proxyInfo objectForKey:(NSString *)kCFProxyPortNumberKey] integerValue];
         host = [proxyInfo objectForKey:(NSString *)kCFProxyHostNameKey];
         shouldRouteToProxy = YES;
         
         signatureType = AWRequestSignerTypeNONE;
         if([contentFilterInstance type] == AWContentFilterServerTypeWebSense)
         {
             signatureType = AWRequestSignerTypeWebSense;
         }
     }
    
    if (!shouldRouteToProxy || !host || (host && ![host length])) {
        //Connect Directly
        signatureType = AWRequestSignerTypeNONE;
        remoteType = AWProxyServerTypeUnknown;
        
        host = [[request URL] host];
        port = [[[request URL] port] integerValue];
        scheme = [[request URL] scheme];
        if(!port) {
            if([scheme isEqualToString:@"https"])
                port = 443;
            else
                port = 80;
        }
        isDirect = YES;
    }
    
    if(!host)
    {
        //If no host is defined then we should close the connection
        [self close];
        return;
    }
    
    CFReadStreamRef remoteRead = NULL;
    CFWriteStreamRef remoteWrite = NULL;
#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
    if (remoteType == AWproxyServerTypeF5) {
        scheme = [[request URL] scheme];
        isDirect = YES;
        NSError *f5StreamError = nil;
        int fd = [[AWF5ProxyController sharedInstance] socketHandleForRequest:(NSURLRequest *)request
                                                                    withError:&f5StreamError];
        if (0 == fd)
        {
            [self close];
            return;
        }
        
        CFStreamCreatePairWithSocket(kCFAllocatorDefault,
                                     
                                     fd,
                                     &remoteRead,
                                     &remoteWrite);
        
        _remoteOutput = (__bridge_transfer NSOutputStream *)remoteWrite;
        _remoteInput = (__bridge_transfer NSInputStream *)remoteRead;

    } else {
#endif
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           (__bridge CFStringRef)host,
                                           (UInt32)port,
                                           &remoteRead,
                                           &remoteWrite);
        NOT_IMPLEMENTED_IF(!remoteRead || !remoteWrite);
    
        _remoteInput = (__bridge_transfer NSInputStream *)remoteRead;
        _remoteOutput = (__bridge_transfer NSOutputStream *)remoteWrite;
#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
    }
#endif
    
    if (!isDirect && [scheme isEqualToString:@"https"]) {
         [_remoteInput setProperty:@"kCFStreamSocketSecurityLevelTLSv1_2TLSv1_1"
                            forKey:NSStreamSocketSecurityLevelKey];
        if(remoteType == AWproxyServerTypeMAG) {
            [_remoteInput setProperty:@{ (id)kCFStreamSSLValidatesCertificateChain : (id)kCFBooleanFalse }
                               forKey:(id)kCFStreamPropertySSLSettings];
        }
    }
    
    [_localOutput setDelegate:nil];
    [_localInput setDelegate:nil];
    
    NSInteger requestPort = [[[request URL] port] integerValue];
    NSString *requestHostWithPort = [[request URL] host];
    if(requestPort &&
       requestPort != 80 &&
       requestPort != 443) {
        requestHostWithPort = [requestHostWithPort stringByAppendingFormat:@":%ld", (long)requestPort];
    }
    
    self.outbound = [[AWProxyForwarder alloc] initWithInput:_localInput
                                                     output:_remoteOutput
                                                      label:@"outbound"
                                                      queue:self.queue
                                              signatureType:signatureType
                                            isRequestDirect:isDirect
                                             isRequestHTTPS:[scheme isEqualToString:@"https"]
                                                requestHost:requestHostWithPort];
    
    self.inbound = [[AWProxyForwarder alloc] initWithInput:_remoteInput
                                                         output:_localOutput
                                                          label:@"inbound"
                                                          queue:self.queue
                                                  signatureType:NO
                                                isRequestDirect:isDirect
                                                isRequestHTTPS:[scheme isEqualToString:@"https"]
                                                    requestHost:requestHostWithPort];
         
    // binding self here increases our retain count until both forwarders complete.
    [self.outbound startWithCompletion:
     ^{
         [self.queue enqueue:
          ^{
              self.outbound = nil;
              [self.inbound cancel];
              [self tryComplete];
            }];
     }];
     [self.inbound startWithCompletion:
      ^{
          [self.queue enqueue:
           ^{
               self.inbound = nil;
               [self.outbound cancel];
               [self tryComplete];
           }];
      }];

}


@end
