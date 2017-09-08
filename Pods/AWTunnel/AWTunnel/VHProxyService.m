//
//  VHProxyService.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VHProxyService.h"
#import "AWProxyConnection.h"
#import "VHProxyConnectionList.h"
#import "VHProxyServerSocket.h"
#import "VHProxyUtils.h"
#import "Fuji.h"
#import "VHDispatchRunLoopQueuing.h"
#import "AWForwarderService.h"

@interface VHProxyService ()
@property (nonatomic, retain) id<VHDispatchRunLoopQueuing> queue;
@property (nonatomic, retain) VHProxyServerSocket *serverSocket;
@property (nonatomic, copy) NSString *proxyHost;
@property (nonatomic) NSInteger proxyPort;
@property (nonatomic) BOOL authenticateCertificates;
@property (nonatomic, retain) VHProxyConnectionList *connections;
@property (nonatomic) BOOL isEnabled;
@end

/**
 * \brief Manage a local loopback server socket that forwards connections to a proxy host:port
 */
@implementation VHProxyService

/**
 * \brief create a new service instance
 *
 * \param queue define the run loop to be used by the service
 * \return the new instance
 */
- (VHProxyService *)initWithQueue:(id<VHDispatchRunLoopQueuing>)queue
{
    if (self = [super init]) {
        self.queue = queue;
    }
    return self;
}

/**
 * \brief start or reconfigure the proxy service
 *
 * If the proxy service is stopped, start it and direct new connections to host:port. If the proxy service
 * is already running reconfigure it so that new connections are directed to host:port.
 *
 * \param host host name or IP address of the proxy server
 * \param port port of the proxy server
 * \param onStarted block called after the service has started to provide the local loopback connection
 *        address.
 */
- (void)startWithProxyHost:(NSString *)host
                 proxyPort:(NSInteger)port
  authenticateCertificates:(BOOL)authenticateCertificates
                 onStarted:(VHProxyServiceStartCompletion)onStarted
{
    @synchronized(self) {
        self.isEnabled = NO;
        // update proxy for future connections
        self.proxyHost = host;
        self.proxyPort = port;
        self.authenticateCertificates = authenticateCertificates;
        
        if (self.connections == nil) {
            self.connections = [[VHProxyConnectionList alloc] initWithQueue:self.queue];
        }
        
        do {
            if (self.serverSocket != nil) {
                PROXY_TRACE(@"reconfigured");
                [self rebind];
                break;
            }
            if([self bindToAddress:@"127.0.0.1" port:0]) {
                break;
            }
            if([self bindToAddress:@"::1" port:0]) {
                break;
            }
            NOT_IMPLEMENTED(); // @knownjira={FUJI-1627} proxy negative paths
            
        } while (NO);
        
        [self logState];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        onStarted(self.serverSocket.boundHost, self.serverSocket.boundPort, nil);
        self.isEnabled = YES;
        
    }
}

-(BOOL) isServiceEnabled;
{
    @synchronized(self) {
        return self.isEnabled;
    }
}

/**
 * \brief log our current state
 */
- (void)logState
{
    PROXY_TRACE(@"host:%@, port:%ld, serverSocket.boundHost:%@, serverSocket.boundPort:%ld",
                self.proxyHost,
                (long)self.proxyPort,
                self.serverSocket.boundHost,
                (long)self.serverSocket.boundPort);
}

/**
 * \brief stop accepting connections
 *
 * Established connections will disconnect shortly after the completion callback runs.
 *
 * \param completion Block called when the server socket has been closed.
 */
- (void)stopWithCompletion:(dispatch_block_t)completion
{
    [self.queue enqueue:
     ^{
         PROXY_TRACE(@"");
         [self stop];
         if(completion) completion();
     }];
}

/**
 * \brief rebind the server socket when we enter the foreground
 *
 * (iOS may have reaped it while we were in the background)
 */
- (void)willEnterForeground
{
    if (objc_getClass("AppWrapDelegate") && objc_getClass("AppWrapSDKController")){
        /*
         ISDK-168988 - In wrapped app, we are not stopping the ForwarderService, but when the device comes foreground after a lock-unlock, the port to which the proxy was listening is dying and thus we should bind Proxy to the new port
         
         https://github.com/robbiehanson/CocoaHTTPServer/issues/10
         */
        [self.queue enqueue: ^{
            if (self.serverSocket != nil) {
                PROXY_TRACE(@"reconfigured");
                [self rebind];
                [self logState];
            }
        }];
    }
    else{
        [[AWForwarderService sharedInstance] startForwarderService];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    }
}

- (void)didEnterBackground
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    /* ISDK-168708 - Wrapped app should work in background also. No need to stop ForwarderService */
    if (!(objc_getClass("AppWrapDelegate") && objc_getClass("AppWrapSDKController"))) {
        [[AWForwarderService sharedInstance] stopForwarderServiceWithCompletion:nil];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    
}

#pragma mark - private implementation

/**
 * \brief Stop the service
 *
 * Close the server socket and all of the open connections.
 */
- (void)stop
{
    [_serverSocket close];
    _serverSocket = nil;
    [_connections close];
    _connections = nil;
    @synchronized(self) {
        self.isEnabled = NO;
    }
    //Remove observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    
}

/**
 * \brief destroy the service instance
 */
- (void)dealloc
{
    [self stop];
    _proxyHost = nil;
    _queue = nil;
}

/**
 * \brief Try to start the service binding it to a particular local address
 *
 * \param address The address to bind to. VHProxyServerSocket supports only "localhost4" and "localhost6".
 * \return YES if the server socket was successfully bound.
 */
- (BOOL)bindToAddress:(NSString *)address port:(NSInteger)port
{
    VHProxyServerSocket *serverSocket = [[VHProxyServerSocket alloc] initWithDelegate:self];
    if (![serverSocket bindAndListenOnAddress:address port:port]) {
        return NO;
    }
    self.serverSocket = serverSocket;
    return YES;
}

/**
 * \brief rebind to our host/interface and port
 *
 * iOS can silently "reclaim" our server socket while we are in the background such that when we come back to
 * the foreground a connect from the application will fail. Here we release/close the server socket and rebind
 * to the prior port.
 *
 * A failure to rebind is considered fatal because if another application were to usurp the port they would be
 * able to intercept our plain text basic auth credentials.
 */
- (void)rebind
{
    ASSERT(self.serverSocket != nil);
    NSString *boundHost = self.serverSocket.boundHost;
    NSInteger boundPort = self.serverSocket.boundPort;
    [self.serverSocket close];
    self.serverSocket = nil;
    FATAL_IF(![self bindToAddress:boundHost port:boundPort], FUJI_FATAL_SECURITY);
}

#pragma mark - FPSForwardConnectionProtocol

/**
 * \brief create a connetion to wrap a newly accepted socket.
 *
 * \param localSocket socket handle. This function takes ownership of the handle.
 */
- (void)forwardLocalSocket:(CFSocketNativeHandle)localSocket
{
    // called back on server socket run loop
    
    if (self.serverSocket == nil) {
        close(localSocket);
        return;
    }
    // pull connections into a local variable to avoid binding self in the completion callback
    VHProxyConnectionList *connections = self.connections;
    ASSERT(connections != nil);
    
    AWProxyConnection *connection = [AWProxyConnection new];
    [connections add:connection];
    [connection startWithQueue:self.queue
                   localSocket:localSocket
                          host:self.proxyHost
                          port:self.proxyPort
      authenticateCertificates:self.authenticateCertificates
                    completion:
     ^{
         [connections remove:connection];
     }];
}

@end
