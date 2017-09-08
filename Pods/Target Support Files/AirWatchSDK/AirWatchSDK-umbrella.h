#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AirWatchSDK.h"
#import "AWClipboard.h"
#import "AWSDK.h"
#import "AWURLSchemeInterceptor.h"
#import "AWProfilePayload.h"
#import "UIApplication+URLSchemesAdditions.h"
#import "UIPasteboard+Swizzle.h"
#import "UITextField+AWClipboard.h"
#import "UITextView+AWClipboard.h"
#import "UIWebView+AWClipboard.h"

FOUNDATION_EXPORT double AWSDKVersionNumber;
FOUNDATION_EXPORT const unsigned char AWSDKVersionString[];

