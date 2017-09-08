//
//  VHProxyUtils.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "Fuji.h"

extern BOOL proxyTraceEnabled;

#define PROXY_TRACE(...) do { if (proxyTraceEnabled) { LOG_DEBUG(__VA_ARGS__); } } while (0)

void ConfigureProxyTrace();


