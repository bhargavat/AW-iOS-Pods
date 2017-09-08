//
//  UIWebView+AWClipboard.m
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import "UIWebView+AWClipboard.h"
#import "AWClipboard.h"
@import AWHelpers;

@implementation UIWebView (AWClipboard)

#pragma mark - Initializations

+(void) load {
    BOOL isAirWatchClipboardEnabled = [[SDKDefaultSettings sharedSettings] isAirWatchClipboardEnabled];
    if (isAirWatchClipboardEnabled) {
        MethodSwizzle([self class], @selector(canPerformAction:withSender:), @selector(aw_canPerformAction:withSender:), NO);
    }
}

-(BOOL) aw_canPerformAction:(SEL)action withSender:(id)sender {
    
    BOOL isAirWatchClipboardActivated = [[AWClipboard sharedInstance] preventCopyPaste];
    if (isAirWatchClipboardActivated) {
        BOOL supportsAction = [AWClipboard supportsAction:action withSender:sender];
        if (supportsAction) {
            return [self aw_canPerformAction:action withSender:sender];
        }
        return NO;
    }
    
    // Secure clipboard isn't activated in console. Fallback to default behavior.
    return [self aw_canPerformAction:action withSender:sender];
}

@end
