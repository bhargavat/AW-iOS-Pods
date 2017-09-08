//
//  ProfilePayload.m
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import "AWProfilePayload.h"

@interface AWProfilePayload ()
@property (nonatomic, strong) NSDictionary *infoDictionary;
@end

@implementation AWProfilePayload

- (instancetype)init {
    return [self initWithDictionary:@{}];
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    if ((self = [super init]))
    {
        _infoDictionary = [dictionary copy];
    }

    return self;
}


+ (NSString *)payloadType
{
    return nil;
}

+ (NSString *)payloadTypeV2
{
    return [AWProfilePayload payloadType];
}

- (NSDictionary *)toDictionary
{
    return self.infoDictionary;
}

- (NSString *)stringFromDictionaryForKey:(NSString *)key
{
    return (NSString *)[self.infoDictionary objectForKey:key];
}

- (BOOL)isEqual:(AWProfilePayload*)other
{
    if (other == self) {
        return YES;
    } else if ([other isKindOfClass:[AWProfilePayload class]]){
        return [self.infoDictionary isEqual:other.infoDictionary];
    }

    return [super isEqual:other];
}

- (NSUInteger)hash
{
    return self.infoDictionary.hash;
}

@end
