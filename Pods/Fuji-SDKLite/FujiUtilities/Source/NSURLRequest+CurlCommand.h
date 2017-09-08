//
//  NSURLRequest+CurlCommand.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (CurlCommand)
- (NSString *)curlCommand;
@end
