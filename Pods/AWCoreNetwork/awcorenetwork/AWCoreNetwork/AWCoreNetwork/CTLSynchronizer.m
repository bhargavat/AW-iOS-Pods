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
#import "CTLSynchronizer.h"


@implementation CTLSynchronizer


static NSRecursiveLock *syncLock;


+(void)synchronized:(void (^)(void))block
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        syncLock = [[NSRecursiveLock alloc] init];
    });

    [syncLock lock];

    // Initialize sync monitor (recursive lock)
    CTLSyncMonitorRecursiveSynchronized(syncLock);

    block();

    [syncLock unlock];
}

+(void)requireSynchronized
{
    CTLSyncMonitorCheckSynchronized(syncLock);
}

+(void)requireNoSynchronized
{
    CTLSyncMonitorCheckNotSynchronized(syncLock);
}


@end


#if DEBUG


@implementation CTLSyncMonitorInternal {
    NSValue *_objectKey;        // The synchronize target object.
    const char *_functionName;  // The function containing the monitored sync block.
}

-(instancetype)initWithSynchronizationObject:(id)object
                              allowRecursive:(BOOL)allowRecursive
                                functionName:(const char *)functionName
{
    self = [super init];
    if (self) {
        Class threadKey = [CTLSyncMonitorInternal class];
        _objectKey = [NSValue valueWithNonretainedObject:object];
        _functionName = functionName;
        
        NSMutableDictionary *threadDict = [NSThread currentThread].threadDictionary;
        NSMutableDictionary *counters = threadDict[threadKey];
        if (counters == nil) {
            counters = [NSMutableDictionary dictionary];
            threadDict[(id)threadKey] = counters;
        }
        NSCountedSet *functionNamesCounter = counters[_objectKey];
        NSUInteger numberOfSyncingFunctions = functionNamesCounter.count;
        
        if (!allowRecursive) {
            BOOL isTopLevelSyncScope = (numberOfSyncingFunctions == 0);
            NSArray *stack = [NSThread callStackSymbols];
            NSAssert(isTopLevelSyncScope,
                     @"*** Recursive sync on %@ at %s; previous sync at %@\n%@",
                     [object class], functionName, functionNamesCounter.allObjects,
                     [stack subarrayWithRange:NSMakeRange(1, stack.count - 1)]);
        }
        
        if (!functionNamesCounter) {
            functionNamesCounter = [NSCountedSet set];
            counters[_objectKey] = functionNamesCounter;
        }
        [functionNamesCounter addObject:@(functionName)];
    }
    return self;
}

-(void)dealloc
{
    Class threadKey = [CTLSyncMonitorInternal class];
    
    NSMutableDictionary *threadDict = [NSThread currentThread].threadDictionary;
    NSMutableDictionary *counters = threadDict[threadKey];
    NSCountedSet *functionNamesCounter = counters[_objectKey];
    NSString *functionNameStr = @(_functionName);
    NSUInteger numberOfSyncsByThisFunction = [functionNamesCounter countForObject:functionNameStr];
    NSArray *stack = [NSThread callStackSymbols];
    NSAssert(numberOfSyncsByThisFunction > 0, @"Sync not found on %@ at %s\n%@",
             [_objectKey.nonretainedObjectValue class], _functionName,
             [stack subarrayWithRange:NSMakeRange(1, stack.count - 1)]);
    [functionNamesCounter removeObject:functionNameStr];
    if (functionNamesCounter.count == 0) {
        [counters removeObjectForKey:_objectKey];
    }
}

+(NSArray *)functionsHoldingSynchronizationOnObject:(id)object
{
    Class threadKey = [CTLSyncMonitorInternal class];
    NSValue *localObjectKey = [NSValue valueWithNonretainedObject:object];
    
    NSMutableDictionary *threadDict = [NSThread currentThread].threadDictionary;
    NSMutableDictionary *counters = threadDict[threadKey];
    NSCountedSet *functionNamesCounter = counters[localObjectKey];
    return functionNamesCounter.count > 0 ? functionNamesCounter.allObjects : nil;
}

@end


#endif
