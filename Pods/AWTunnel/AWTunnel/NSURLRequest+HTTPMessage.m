//
//  NSURLRequest+HTTPMessage.m
//  AWBrowserProxyPlugin
//
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#import "NSURLRequest+HTTPMessage.h"

#define HTTPVer   kCFHTTPVersion1_1

@interface NSURLRequest ()
{
	BOOL _isProxyBound;
}

@end

@implementation NSURLRequest (HTTPMessage)

- (CFHTTPMessageRef)createHTTPMessage __attribute__((cf_returns_retained))
{
    CFHTTPMessageRef result = CFHTTPMessageCreateRequest(NULL,
                                                         (__bridge CFStringRef)[self HTTPMethod],
                                                         (__bridge CFURLRef)[self URL],
                                                         HTTPVer);
    
    NSDictionary *HTTPHeaderFields = [self allHTTPHeaderFields];
    NSEnumerator *HTTPHeaderFieldsEnumerator = [HTTPHeaderFields keyEnumerator];
    NSString *aHTTPHeaderField;
    
    while (aHTTPHeaderField = [HTTPHeaderFieldsEnumerator nextObject])
    {
        NSString *hdr = [HTTPHeaderFields objectForKey:aHTTPHeaderField];
        CFHTTPMessageSetHeaderFieldValue(result,
                                         (__bridge CFStringRef)aHTTPHeaderField,
                                         (__bridge CFStringRef)hdr);
    }
    
    NSData *body = [self HTTPBody];
    
    if (body) {
        CFHTTPMessageSetBody(result, (__bridge CFDataRef)body);
    }
    
    return result;  // retained.
} /* makeHTTPMessage */

- (CFDataRef)createHTTPMessageSerial __attribute__((cf_returns_retained))
{
    CFHTTPMessageRef result = CFHTTPMessageCreateRequest(NULL,
                                                         (__bridge CFStringRef)[self HTTPMethod],
                                                         (__bridge CFURLRef)[self URL],
                                                         HTTPVer);
    
    NSString *firstLine = [self buildRequestLine];
	
	NSString *hostHeaderValue = self.URL.host;
	
	if ([[self HTTPMethod] compare:@"CONNECT" options:NSCaseInsensitiveSearch] != NSOrderedSame)
	{
		if (self.URL.port)
		{
			hostHeaderValue = [NSString stringWithFormat:@"%@:%@", self.URL.host, self.URL.port];
		}
	}
    
    
    CFHTTPMessageSetHeaderFieldValue(result, CFSTR("host"), (__bridge CFStringRef)hostHeaderValue);
    
    NSDictionary *HTTPHeaderFields = [self allHTTPHeaderFields];
    NSEnumerator *HTTPHeaderFieldsEnumerator = [HTTPHeaderFields keyEnumerator];
    NSString *aHTTPHeaderField;
    
    while (aHTTPHeaderField = [HTTPHeaderFieldsEnumerator nextObject])
    {
        NSString *hdr = [HTTPHeaderFields objectForKey:aHTTPHeaderField];
        CFHTTPMessageSetHeaderFieldValue(result,
                                         (__bridge CFStringRef)aHTTPHeaderField,
                                         (__bridge CFStringRef)hdr);
    }
    
    NSData *body = [self HTTPBody];
    
    if (body) {
        CFHTTPMessageSetBody(result, (__bridge CFDataRef)body);
    }
    
    CFDataRef http = CFStringCreateExternalRepresentation(NULL,
                                                          HTTPVer,
                                                          kCFStringEncodingASCII,
                                                          0);
    
    CFDataRef msg = CFHTTPMessageCopySerializedMessage(result);
    CFRelease(result);
    CFRange rng = CFDataFind(msg, http, CFRangeMake(0, CFDataGetLength(msg)), 0ul);
    
    CFMutableDataRef newMsg = CFDataCreateMutable(NULL, firstLine.length + CFDataGetLength(msg) - rng.location);
    CFDataAppendBytes(newMsg, (const UInt8 *)[firstLine cStringUsingEncoding:NSUTF8StringEncoding], [firstLine length]);
    CFDataAppendBytes(newMsg, CFDataGetBytePtr(msg) + rng.location + rng.length, CFDataGetLength(msg) - rng.location - rng.length);
    
    NSString *debugText = (NSString *)CFBridgingRelease(CFStringCreateFromExternalRepresentation(NULL, newMsg, kCFStringEncodingASCII));
    
    //TODO: Fix me when AWLogger is available
    //AWLogVerbose
    NSLog(@"Message header written \n%@",debugText );
    
    CFRelease(msg);
    CFRelease(http);
    
    return newMsg;  // retained.
}

- (NSDictionary *)getCookieDict
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[self URL]];
    if (!cookies) {
        return nil;
    }
    NSDictionary *cookieHeader = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
    return cookieHeader;
}

- (NSString *)buildRequestLine
{
	
	if ([[self HTTPMethod] compare:@"CONNECT" options:NSCaseInsensitiveSearch] == NSOrderedSame)
	{
		return [NSString stringWithFormat:@"%@ %@:%@ %@",
                self.HTTPMethod,
                self.URL.host,
                self.URL.port,
                HTTPVer];
	}
	
	NSString *firstLine = nil;
	
	
	/* if the request is HTTPS it will be tunneled through a CONNECT and the message will be sent directly to the
	 origin server, I've had issues with some server's (GE) handling absolute URIs in the request line -Nolan
     */
	if ([self.URL.scheme caseInsensitiveCompare:@"https"] == NSOrderedSame)
	{
        
		NSString *absURL = [self.URL absoluteString];
        NSString *schemeHost = nil;
        
        if(self.URL.port)
            schemeHost = [NSString stringWithFormat:@"%@://%@:%@",self.URL.scheme, self.URL.host, self.URL.port];
        else
            schemeHost = [NSString stringWithFormat:@"%@://%@",self.URL.scheme, self.URL.host];
        
		
		NSRange schemeHostRange = [absURL rangeOfString:schemeHost];
		
		NSString *urlPath = [absURL substringFromIndex:schemeHostRange.length];
		
		firstLine = [NSString stringWithFormat:@"%@ %@ %@",
					 self.HTTPMethod,
					 urlPath,
					 HTTPVer];
	} else // were sending this to a proxy
	{
		firstLine = [NSString stringWithFormat:@"%@ %@ %@",
					 [self HTTPMethod],
					 [[self URL] absoluteString],
					 HTTPVer];
	}
    
	return firstLine;
}

@end
