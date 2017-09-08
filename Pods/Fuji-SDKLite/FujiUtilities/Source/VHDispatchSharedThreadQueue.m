//
//  VHDispatchSharedThreadQueue.m
//
//  Copyright (c) 2012-2013 VMware Inc. All rights reserved.
//

#import "VHDispatchSharedThreadQueue.h"
#import "VHDispatchURLQueuing.h"
#import "Fuji.h"

@interface VHDispatchSharedThreadQueue ()
@property (nonatomic) NSThread *thread;
@property (nonatomic) NSMutableArray *flag;
@end

/**
 * \brief Run connections on a shared thread.
 *
 * All callbacks happen on a shared NSThread that runs its own runloop separate from the main thread.
 * This policy works with NSURLConnections on both iOS 5.1 and iOS 6. This is a "classic" threading model
 * used by e.g. AFNetworking.
 */
@implementation VHDispatchSharedThreadQueue

/**
 * \brief start the shared thread
 */
- (VHDispatchSharedThreadQueue*)init
{
   if (self = [super init]) {
      self.flag = [[NSMutableArray alloc] init];
      self.thread = [[NSThread alloc] initWithTarget:[self class]
                                            selector:@selector(run:)
                                              object:self.flag];
      [self.thread start];
   }
   return self;
}

/**
 * \brief tell run: to stop
 */
- (void)dealloc
{
   LOG_DEBUG(@"dealloc");
   NSMutableArray *flag = _flag;
   [VHDispatchSharedThreadQueue performSelector:@selector(performBlock:)
                                       onThread:_thread
                                     withObject:^{
                                        [flag addObject:@""];
                                        LOG_DEBUG(@"set flag %@", flag);
                                     }
                                  waitUntilDone:NO];
}

/**
 * \brief method which performs queued blocks
 *
 * \param block Block to perform
 */
+ (void)performBlock:(dispatch_block_t)block
{
   block();
}

/**
 * \brief thread function that pumps the run loop until flag is non-empty
 *
 * \param flag Run until flag is non-empty.
 */
+ (void)run:(NSMutableArray *)flag
{
   while (flag.count == 0) {
      @autoreleasepool {
         [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
      }
   }
   LOG_DEBUG(@"exit");
}

#pragma mark - VHDispatchSerialQueuing

- (void)enqueue:(dispatch_block_t)block
{
   [VHDispatchSharedThreadQueue performSelector:@selector(performBlock:)
                                       onThread:self.thread
                                     withObject:block
                                  waitUntilDone:NO];
}

#pragma mark - VHDispatchURLQueuing

- (NSURLConnection *)newConnectionWithRequest:(NSURLRequest *)request
                                     delegate:(id<NSURLConnectionDelegate>)delegate;
{
   NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                 delegate:delegate
                                                         startImmediately:NO];
   NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
   [connection scheduleInRunLoop:runLoop forMode:NSRunLoopCommonModes];
   return connection;
}

- (id<VHDispatchURLQueuing>)detachQueue
{
   // All connections should share our thread
   return self;
}

@end
