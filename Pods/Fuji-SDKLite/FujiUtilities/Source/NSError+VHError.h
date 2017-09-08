//
//  NSError+VHError.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VHError.h"

#import <Foundation/Foundation.h>

@interface NSError (VHError)
- (BOOL)isVHErrorWithCode:(VHErrorCode)code;
- (BOOL)isVHError;
@end
