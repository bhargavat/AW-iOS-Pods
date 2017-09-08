//  AWSignatureCacheEntry.h
//  AirWatch
//
//  Created by Vishal Patel on 2/18/14.

/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#import <Foundation/Foundation.h>

@interface AWSignatureCacheEntry : NSObject


@property (nonatomic, strong) NSData *signature;
@property (nonatomic, strong) NSDate *dateAdded;

- (AWSignatureCacheEntry *)initWithSignatue:(NSData *) signature dateAdded:(NSDate *)dateAdded;

@end