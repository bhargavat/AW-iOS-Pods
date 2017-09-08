//
//  VHFinally.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VHFinally : NSObject
+ (VHFinally *)newFinally:(dispatch_block_t)block;
+ (VHFinally *)newFinallyAndNow:(dispatch_block_t)block;
- (void)reset;
- (void)set:(dispatch_block_t)block;
- (BOOL)isSet;
@end
