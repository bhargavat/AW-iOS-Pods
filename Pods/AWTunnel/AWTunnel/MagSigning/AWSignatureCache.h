//  AWSignatureCache.h
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

@class AWSignatureCache;

@interface AWSignatureCache : NSObject

@property (nonatomic, strong) NSCache *signatureCache;

+(id)sharedInstance;

-(void)setObject:(id)obj forKey:(id<NSCopying>)aKey;
-(id)objectForKey:(id)aKey;
@end