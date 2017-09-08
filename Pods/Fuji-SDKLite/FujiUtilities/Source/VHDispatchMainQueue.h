//
//  VHDispatchMainQueue.h
//
//  Copyright (c) 2012-2013 VMware Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "VHDispatchURLQueuing.h"
#import "VHDispatchRunLoopQueuing.h"

@interface VHDispatchMainQueue : NSObject <VHDispatchURLQueuing, VHDispatchRunLoopQueuing>

@end

