//
//  VHDispatchURLQueuing.h
//
//  Copyright (c) 2012 VMware Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "VHDispatchSerialQueuing.h"

/**
 * \brief Abstract serial queue for use with NSURLConnection delegates
 *
 * Queues conforming to this protocol can allocate NSURLConnections such that they make their delegate
 * callbacks on the queue. A typical object using such a queue might have an implementation like this:
 *
 * - (void)start
 * {
 *    [self.queue enqueue:
 *     ^{
 *         self.connection = [self.queue newConnectionWithRequest:self.request
 *                                                       delegate:self];
 *         [self.connection start];
 *     }];
 * }
 */
@protocol VHDispatchURLQueuing <VHDispatchSerialQueuing>

/**
 * \brief create an NSURLConnection that makes delegate callbacks on the receiver.
 *
 * This method must be called on the queue. The connection is not started.
 *
 * \param request The request to be made by the connection.
 * \param delegate The connection delegate. Delegate methods will be called on this queue.
 *
 * \return a newly allocated, un-started connection.
 */
- (NSURLConnection *)newConnectionWithRequest:(NSURLRequest *)request
                                     delegate:(id<NSURLConnectionDelegate>)delegate;

/**
 * \brief detach a new queue for an NSURLConnection.
 *
 * Depending on the queue implementation this may simply return the receiver, or it may create
 * an entirely new queue.
 *
 * \todo This is a "poor-man's" substitute for a proper factory class. Using this technique saves
 * introducing three new classes/six files.
 */
- (id<VHDispatchURLQueuing>)detachQueue;

@end
