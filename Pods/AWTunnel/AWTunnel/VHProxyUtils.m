//
//  VHProxyUtils.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHProxyUtils.h"
#import <Foundation/Foundation.h>

BOOL proxyTraceEnabled = NO;

/**
 * \brief configure proxy tracing based on environment
 */
void
ConfigureProxyTrace()
{
#ifdef DEBUG
   NSDictionary *env = [[NSProcessInfo processInfo] environment];
   NSObject *value = env[@"FUJI_PROXY_TRACE"];
   if (value != nil) {
      if ([value isKindOfClass:[NSString class]]) {
         NSString *stringValue = (NSString *)value;
         proxyTraceEnabled = [stringValue boolValue];
      } else {
         LOG_ERROR(@"FUJI_PROXY_TRACE value is not of type NSString. type: %@",
                   [value class]);
      }
   }
   LOG_DEBUG(@"FUJI_PROXY_TRACE: %d", (int)proxyTraceEnabled);
#endif
}

