//  AWRequestSigner.h
//  AirWatch
//
//  Created by Nolan Roberson on 11/1/13.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#if !TARGET_IPHONE_SIMULATOR
#import "MobileAPI.h"
#endif

typedef enum
{
    AWRequestSignerTypeNONE = 0,
    AWRequestSignerTypeMAG,
    AWRequestSignerTypeBASIC,
    AWRequestSignerTypeWebSense
}AWRequestSignerType;

//@class AWMutableURLRequest;
#define AWMutableURLRequest NSMutableURLRequest

@class AWProxyCertService;

#import <Foundation/Foundation.h>

@interface AWRequestSigner : NSObject {
#if !TARGET_IPHONE_SIMULATOR
    MobileAPI *mMobileAPI;
    BOOL mMobileAPIInitialized;
    NSString *jsonString;
#endif
    
}

@property (nonatomic, nullable, retain) AWProxyCertService *proxyCertService;

+(AWRequestSigner* _Nonnull)sharedInstance;

- (AWMutableURLRequest * _Nonnull)MAGSignedRequestWithPort:(NSNumber * _Nullable)hostPort
                                       andRequest:(NSURLRequest * _Nonnull)origRequest
                                            error:(NSError * _Nullable* _Nullable)outError;


- (NSString * _Nonnull)newSignedBasicAuthFor: (NSString * _Nonnull)user
                                     password: (NSString * _Nonnull)password
                                        error: (NSError * _Nullable * _Nullable)outError;

- (AWMutableURLRequest * _Nonnull)newSignedRequestForWebSense:(NSURLRequest * _Nonnull)origRequest
                                                         error:(NSError * _Nullable * _Nullable)outError;

#if !TARGET_IPHONE_SIMULATOR
typedef NS_ENUM(NSUInteger, AWRSAAADeviceInfoLevel)
{
    AWRSAAABasicData = 0,
    AWRSAAADeviceData = 1,
    AWRSAAAAllDeviceData = 2
    
};

@property (nonatomic, assign) AWRSAAADeviceInfoLevel dataCollectionLevel;
- (void) updateRSAJSONString;
#endif
@property (nonatomic, assign) BOOL useCmsv2;

@end
