//  AWSignatureCache.m
//  AirWatch
//
//  Created by Vishal Patel on 2/18/14.

/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#import "AWSignatureCache.h"
#import "AWSignatureCacheEntry.h"

#define CACHE_EXPIRE_TIME 120
#define CACHE_COUNT_LIMIT 200

@implementation AWSignatureCache

+(id) sharedInstance {
    
	static AWSignatureCache *sharedCache = nil;
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedCache = [[self alloc] init];
	});
    return sharedCache;
}


- (id)init
{
    if (self = [super init]) {
        self.signatureCache = [[NSCache alloc] init];
        [self.signatureCache setCountLimit:CACHE_COUNT_LIMIT];
    }
    return self;
}

-(void)setObject:(id)obj forKey:(id)aKey
{
    @synchronized(self)
    {
        if(aKey) {
            AWSignatureCacheEntry * entry = [[AWSignatureCacheEntry alloc] init];
            entry.signature = obj;
            entry.dateAdded = [NSDate date];
            [self.signatureCache setObject:entry forKey:aKey];
        }
    }
}

-(id)objectForKey:(id)aKey {
    AWSignatureCacheEntry * entry = nil;
    @synchronized(self)
    {
        entry = [self.signatureCache objectForKey:aKey];
        if (entry)
		{
            NSTimeInterval cachTimeDelta = [[NSDate date] timeIntervalSinceDate:entry.dateAdded];

            if(cachTimeDelta >= CACHE_EXPIRE_TIME)
			{
                //if its been more than 2 mintues remove frome cache
                [self.signatureCache removeObjectForKey:aKey];
                entry = nil;
            }
        }
    }
    return entry;
}


@end