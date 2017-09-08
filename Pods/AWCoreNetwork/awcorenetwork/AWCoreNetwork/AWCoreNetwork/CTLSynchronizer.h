//
//  CTLSynchronizer.m
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


#import <Foundation/Foundation.h>

#ifndef CTLSYNCHRONIZER_H
#define CTLSYNCHRONIZER_H


@interface CTLSynchronizer: NSObject

+(void)synchronized:(void (^)(void))block;

+(void)requireSynchronized;

+(void)requireNoSynchronized;

@end


/**
 Below code is from Google GData GTMSessionSyncMonitorInternal. It uses thread local
 storage to ensure current execution path is protected by proper synchronizer. Those
 are only for debug build.
 */

#if DEBUG
  #define __CTLSyncMonitorSynchronizedVariableInner(varname, counter) \
      varname ## counter
  #define __CTLSyncMonitorSynchronizedVariable(varname, counter)  \
      __CTLSyncMonitorSynchronizedVariableInner(varname, counter)

  #define __CTLSyncMonitorCallerName                                          \
      ({                                                                      \
            NSString *caller = [[NSThread callStackSymbols] objectAtIndex:1]; \
            [caller UTF8String];                                              \
      })

  #define CTLSyncMonitorSynchronized(obj)                                \
      NS_VALID_UNTIL_END_OF_SCOPE id                                     \
        __CTLSyncMonitorSynchronizedVariable(__monitor, __COUNTER__) =   \
       [[CTLSyncMonitorInternal alloc] initWithSynchronizationObject:obj \
                                                      allowRecursive:NO  \
                                                        functionName:__CTLSyncMonitorCallerName]

  #define CTLSyncMonitorRecursiveSynchronized(obj)                        \
      NS_VALID_UNTIL_END_OF_SCOPE id                                      \
        __CTLSyncMonitorSynchronizedVariable(__monitor, __COUNTER__) =    \
        [[CTLSyncMonitorInternal alloc] initWithSynchronizationObject:obj \
                                                       allowRecursive:YES \
                                                         functionName:__CTLSyncMonitorCallerName]

  #define CTLSyncMonitorCheckSynchronized(obj) {                                \
      NSAssert(                                                                 \
          [CTLSyncMonitorInternal functionsHoldingSynchronizationOnObject:obj], \
          @"CTLSyncMonitorCheckSynchronized(" #obj ") failed: not sync'd"       \
          @" on " #obj " in %s. Call stack:\n%@",                               \
          __func__, [NSThread callStackSymbols]);                               \
  }

  #define CTLSyncMonitorCheckNotSynchronized(obj) {                              \
      NSAssert(                                                                  \
          ![CTLSyncMonitorInternal functionsHoldingSynchronizationOnObject:obj], \
          @"CTLSyncMonitorCheckNotSynchronized(" #obj ") failed: was sync'd"     \
          @" on " #obj " in %s. Call stack:\n%@",                                \
          __func__, [NSThread callStackSymbols]);                                \
  }


@interface CTLSyncMonitorInternal : NSObject
- (instancetype)initWithSynchronizationObject:(id)object
                               allowRecursive:(BOOL)allowRecursive
                                 functionName:(const char *)functionName;
// Return the names of the functions that hold sync on the object, or nil if none.
+ (NSArray *)functionsHoldingSynchronizationOnObject:(id)object;
@end


#else

#define CTLSyncMonitorSynchronized(obj) do { } while (0)
#define CTLSyncMonitorRecursiveSynchronized(obj) do { } while (0)
#define CTLSyncMonitorCheckSynchronized(obj) do { } while (0)
#define CTLSyncMonitorCheckNotSynchronized(obj) do { } while (0)

#endif


#endif
