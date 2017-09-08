//
//  VHHTTPError.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VHHTTPStatus.h"

extern NSString *const kVHHTTPErrorDomain;

@interface VHHTTPError : NSObject
+ (NSError *)errorWithStatusCode:(VHHTTPStatusCode)statusCode;
+ (BOOL)fill:(NSError **)error withStatusCode:(VHHTTPStatusCode)statusCode;
@end
