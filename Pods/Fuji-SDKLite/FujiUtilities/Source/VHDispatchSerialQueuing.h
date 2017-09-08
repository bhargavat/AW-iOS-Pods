//
//  VHDispatchSerialQueuing.h
//
//  Copyright (c) 2012 VMware Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * \brief Abstract serial queue
 *
 * This abstract queue interface can be used to inject queuing behavior.
 *
 * \todo Write more precise documentation for VHDispatchSerialQueuing.
 *
 */
@protocol VHDispatchSerialQueuing <NSObject>

/**
 * \brief enqueue a block that will execute on the queue in FIFO order.
 *
 * \param block Block to enqueue
 */
- (void)enqueue:(dispatch_block_t)block;

@end
