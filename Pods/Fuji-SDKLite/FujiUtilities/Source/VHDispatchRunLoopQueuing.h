//
//  VHDispatchRunLoopQueuing.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHDispatchSerialQueuing.h"

/**
 * \brief A "tag" that indicates that a serial queuing implementation guarantees run loop affinity
 *
 * Always using the same run loop is required for many Cocoa and Core Foundation APIs that have run
 * loop affinity.
 */
@protocol VHDispatchRunLoopQueuing <VHDispatchSerialQueuing>

@end
