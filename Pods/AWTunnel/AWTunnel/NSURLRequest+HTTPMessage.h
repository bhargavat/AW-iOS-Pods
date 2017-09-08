//  NSURLRequest+HTTPMessage.h
//  AWBrowserProxyPlugin
//
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (HTTPMessage)

- (CFHTTPMessageRef)createHTTPMessage  __attribute__((cf_returns_retained));
- (CFDataRef)createHTTPMessageSerial  __attribute__((cf_returns_retained));
- (NSDictionary *)getCookieDict;

@end