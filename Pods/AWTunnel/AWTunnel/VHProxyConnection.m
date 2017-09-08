//
//  VHProxyConnection.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHProxyConnection.h"

#import "VHProxyForwarder.h"
#import "VHProxyUtils.h"
#import "AWProxy.h"
#import "Fuji.h"
#import "VHDispatchRunLoopQueuing.h"

#include <netinet/in.h>
#include <netinet/tcp.h>
#import <CoreFoundation/CoreFoundation.h>

@interface VHProxyConnection ()
@property (nonatomic, retain) id<VHDispatchRunLoopQueuing> queue;
@property (nonatomic, retain) VHProxyForwarder *outbound;
@property (nonatomic, retain) VHProxyForwarder *inbound;
@property (nonatomic, copy) dispatch_block_t completion;
@end

/**
 * \brief Encapsulates a full-duplex TLS connection between a local socket and a remote host:port.
 *
 * Implemented by aggregating two forwarders.
 *
 * \todo @knownjira={FUJI-1627} most of the NOT_IMPLEMENTED's below will be covered by a later
 *       "negative path" story.
 */
@implementation VHProxyConnection

/**
 * \brief Destroy a closed connection
 *
 * By the time dealloc is called both of the forwarders should have completed.
 */
- (void)dealloc
{
    PROXY_TRACE(@"");
    ASSERT(_outbound == nil);
    ASSERT(_inbound == nil);
    ASSERT(_completion == nil);
   //[_queue release];
    _queue = nil;
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
    NSLog(@"New Socket: %d Host: %@, Port: %ld", localSocket, host, (long)port);
#endif
    ASSERT(self.queue == nil);
    self.queue = queue;
    [self.queue enqueue:
     ^{
         ASSERT(self.outbound == nil);
         ASSERT(self.inbound == nil);
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
         NSInputStream *localInput = (__bridge_transfer NSInputStream *)localRead;
         NSOutputStream *localOutput = (__bridge_transfer NSOutputStream *)localWrite;
         if (![localInput setProperty:(id)kCFBooleanTrue
                               forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket]) {
             NOT_IMPLEMENTED();
         }
         
         CFReadStreamRef remoteRead = NULL;
         CFWriteStreamRef remoteWrite = NULL;
         CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                            (__bridge CFStringRef)host,
                                            (UInt32)port,
                                            &remoteRead,
                                            &remoteWrite);
         NOT_IMPLEMENTED_IF(!remoteRead || !remoteWrite);
         
         NSInputStream *remoteInput = (__bridge_transfer NSInputStream *)remoteRead;
         NSOutputStream *remoteOutput = (__bridge_transfer NSOutputStream *)remoteWrite;
         if (![remoteInput setProperty:NSStreamSocketSecurityLevelTLSv1
                                forKey:NSStreamSocketSecurityLevelKey]) {
             NOT_IMPLEMENTED();
          }
         
         if (!authenticateCertificates) {
             if (![remoteInput setProperty:@{ (id)kCFStreamSSLValidatesCertificateChain : (id)kCFBooleanFalse }
                                    forKey:(id)kCFStreamPropertySSLSettings]) {
                 NOT_IMPLEMENTED();
             }
         }
         AWRequestSignerType signType = AWRequestSignerTypeNONE;
         if ([[AWProxy sharedInstance] type] == AWproxyServerTypeMAG) {
             signType = AWRequestSignerTypeMAG;
         } else if ([[AWProxy sharedInstance] type] == AWProxyServerTypeStandard) {
             signType = AWRequestSignerTypeBASIC;
         }
         self.outbound = [[VHProxyForwarder alloc] initWithInput:localInput
                                                           output:remoteOutput
                                                            label:@"outbound"
                                                            queue:self.queue
                                                            signatureType:signType];
         self.inbound = [[VHProxyForwarder alloc] initWithInput:remoteInput
                                                          output:localOutput
                                                           label:@"inbound"
                                                           queue:self.queue
                                                           signatureType:NO];
         
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
     }];
}

/**
 * \brief Asynchronously close the connection
 */
- (void)close
{
    [self.queue enqueue:
     ^{
         [self.inbound cancel];
         [self.outbound cancel];
     }];
}

/**
 * \brief Call the completion block, if any, when inbound and outbound are nil (closed)
 */
- (void)tryComplete
{
    if (self.inbound == nil && self.outbound == nil && self.completion != nil) {
        self.completion();
        self.completion = nil;
    }
}

@end
