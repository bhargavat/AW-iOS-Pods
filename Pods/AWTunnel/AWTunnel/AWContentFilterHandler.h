//
//  AWContentFilterHandler.h
//  AirWatch
//
//  Created by Vishal Patel on 11/19/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */

#import <Foundation/Foundation.h>

typedef enum
{
    AWContentFilterSetupErrorPayloadEmpty=23000,
    AWContentFilterSetupErrorTypeNotSupported,
    AWContentFilterSetupErrorWebsensePacAddressEmpty,
    AWContentFilterSetupErrorWebsenseAccountIDEmpty,
    AWContentFilterSetupErrorWebsenseSecurityKeyEmpty,
    AWContentFilterSetupErrorNotConfigured
    
}AWContentFilterSetupError;


typedef void (^contentFilterSetupCompletion)(BOOL success,NSError *xUerror);


@protocol AWContentFilterDelegate;
@protocol AWContentFilteringPayload;

@interface AWContentFilterHandler : NSObject
@property (nonatomic,unsafe_unretained) id<AWContentFilterDelegate> delegate;

+ (AWContentFilterHandler *)sharedInstance;

- (void)setupContentFilter:(id<AWContentFilteringPayload>)contentFilterPayload withCompletion:(contentFilterSetupCompletion)callback;
@end
