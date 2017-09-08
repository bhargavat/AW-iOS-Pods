//
//  NSString+Version.h
//  utilities
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Version)
- (NSComparisonResult)compareVersion:(NSString *)argVersion;
@end
