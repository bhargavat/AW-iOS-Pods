//  AWProxy_F5.h
//  AirWatch
//
//  Created by AW on 8/23/13.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//
#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR

@import AWServices;
@import AWCrypto;
@import AWLocalization;

//#import "AWSDK.h"
#import "AWProxy.h"
//#import "AWProxyPayload.h"


@interface AWProxy ()

@property (nonatomic, assign) AWF5AuthenticationMode f5ProxyAuthType;

/**
 The F5 proxy Client Certificate p12 data.
 */
@property (nonatomic, strong) NSData *p12CertDataForF5;

/**
 The F5 proxy Client Certificate passphrase.
 */
@property(nonatomic, copy)NSString *passPhraseForF5Cert;

/*!
 @method configure
 @abstract Configure the F5 Proxy
 @discussion Configure F5 Proxy with host, port, auth type, username, password and client certificate p12 data.
 */
- (void)configureF5ProxyWithHost:(NSString *)proxyHost
                            port:(NSInteger)proxyPort
                        authType:(AWF5AuthenticationMode)authType
                        userName:(NSString *)name
                        password:(NSString *)pwd
                        certData:(NSData *)certData
					  passPhrase:(NSString *)pphrase;

@end

#endif
