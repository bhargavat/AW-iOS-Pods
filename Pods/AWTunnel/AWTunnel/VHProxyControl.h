//
//  VHProxyControl.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class vmPolicies;
@class VHProxyService;

void ApplyConnectivitySettings(void *policies);
VHProxyService *SharedProxyService();

