//
//  ProxyAuthTokenHelper.h
//  AirWatch
//
//  Created by Vishal Patel on 7/9/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#ifndef _PROXYAUTHTOKENHELPER_H
#define _PROXYAUTHTOKENHELPER_H

void initTokenGenerator();

// return can be either a valid value or null if there was an internal error or memory restrictions
char * getProxyAuthToken();
int isTokenValid(const char * tokenToVerify);

#endif
