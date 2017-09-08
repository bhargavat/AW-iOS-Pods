//
//  NSError+VHUtil.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (VHUtil)
- (BOOL)isDomain:(NSString *)domain code:(NSInteger)code;
- (BOOL)isDomain:(NSString *)domain;
@end
