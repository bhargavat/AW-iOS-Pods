//  AWSignatureCacheEntry.m
//  AirWatch
//
//  Created by Vishal Patel on 2/18/14.

/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#import "AWSignatureCacheEntry.h"

@implementation AWSignatureCacheEntry



- (AWSignatureCacheEntry *)initWithSignatue:(NSData *)data dateAdded:(NSDate *)da
{
    self = [super init];
    if (self)
	{
        self.signature = data;
        self.dateAdded = da;
    }
    return self;
}

@end