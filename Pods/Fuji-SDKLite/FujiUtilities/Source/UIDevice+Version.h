//
//  UIDevice+Version.h
//  utilities
//
//  Created by Paul Wisner on 7/23/13.
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIDevice (Version)
- (BOOL)isAtLeastVersion:(NSString *)minVersion;
- (BOOL)isBeforeVersion:(NSString *)version;
@end
