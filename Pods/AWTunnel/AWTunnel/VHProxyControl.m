//
//  VHProxyControl.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHProxyControl.h"

#import "VHProxyConfig.h"
#import "VHProxyService.h"
#import "VHProxyUtils.h"

#import "FNInetPriv.h"
#import "FNProxySupportPriv.h"

#import "VHDispatchSharedThreadQueue.h"
//TODO:CHECK #import <vmShared/vmPolicies.h>

/**
 * \brief return the proxy service singleton, creating it if necessary
 *
 * \return proxy service singleton
 */
VHProxyService *
SharedProxyService()
{
   static VHProxyService *proxyService;
   static dispatch_once_t onceToken;
   dispatch_once(&onceToken, ^{
      id<VHDispatchRunLoopQueuing> queue = [VHDispatchSharedThreadQueue new];
      proxyService = [[VHProxyService alloc] initWithQueue:queue];
      //[queue release];
      [queue enqueue:^{}];
   });
   return proxyService;
}
