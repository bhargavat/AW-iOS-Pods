//
//  VHURLUtil.h
//
//  Copyright (c) 2012 VMware Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VHURLUtil : NSObject
+ (NSDictionary *)dictionaryFromQuery:(NSString *)query;
+ (NSString *)queryFromDictionary:(NSDictionary *)dictionary;
+ (NSURL *)urlWithScheme:(NSString *)scheme
              withDomain:(NSString *)domain
                withPath:(NSString *)path
               withQuery:(NSDictionary *)query;
@end
