//
//  VHProxyServerSocketDelegate.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VHProxyServerSocketDelegate <NSObject>

/**
 * \brief dispatch a newly accepted socket
 *
 * The delegate takes responsibility for closing this handle.
 */
- (void)forwardLocalSocket:(CFSocketNativeHandle)localSocket;

@end
