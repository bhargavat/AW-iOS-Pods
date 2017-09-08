//
// VHProxyServerSocket.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VHProxyServerSocketDelegate;

@interface VHProxyServerSocket : NSObject

/**
 * \brief local host (IP number) to which the server socket is bound
 *
 * Only valid after bindAndListenOnAddress:port: returns YES.
 */
@property (nonatomic, retain, readonly) NSString *boundHost;

/**
 * \brief local port to which the server socket is bound
 *
 * Only valid after bindAndListenOnAddress:port: returns YES.
 */
@property (nonatomic, readonly) NSInteger boundPort;

- (VHProxyServerSocket *)initWithDelegate:(id<VHProxyServerSocketDelegate>)delegate;
- (BOOL)bindAndListenOnAddress:(NSString *)address port:(NSInteger)port;
- (void)close;

@end
