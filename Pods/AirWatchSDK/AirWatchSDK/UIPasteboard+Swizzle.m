//
//  UIPasteboard+Swizzle.m
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import <AWSDK/AWSDK-Swift.h>
#import "UIPasteboard+Swizzle.h"
#import "UITextField+AWClipboard.m"
#import "UITextView+AWClipboard.m"
#import "UIWebView+AWClipboard.m"
#import "UIApplication+URLSchemesAdditions.m"

@import MobileCoreServices;

@implementation UIPasteboard (Swizzle)

#pragma mark - Initializations

+(void) setUpAWPasteboard {
    BOOL isAirWatchClipboardEnabled = [[SDKDefaultSettings sharedSettings] isAirWatchClipboardEnabled];
    if (isAirWatchClipboardEnabled) {
        MethodSwizzle([self class], @selector(generalPasteboard), @selector(awswizzled_generalPasteboard), YES);
        [UIApplication setUpURLSchemeHandling];
    }
}

#pragma mark - Swizzling

+(UIPasteboard *) awswizzled_generalPasteboard {
    BOOL preventCopyPaste = [[AWClipboard sharedInstance] preventCopyPaste];
    if (preventCopyPaste) {
        return [self awprivatePasteboard];
    }
    return [self awswizzled_generalPasteboard];
}

#pragma mark - Public methods

+(UIPasteboard *) awgeneralPasteboard {
    UIPasteboard *pasteboard;
    
    if ([[AWClipboard sharedInstance] isAirWatchClipboardEnabled]) {
        pasteboard = [self awswizzled_generalPasteboard];
    }else {
        pasteboard = [self generalPasteboard];
    }
    
    return pasteboard;
}

+(UIPasteboard *) awprivatePasteboard {
    UIPasteboard *privatePasteboard = [UIPasteboard pasteboardWithName:@"AWClipboard" create:YES];
    return privatePasteboard;
}

#pragma mark - Utility methods

-(void) removeItemForPasteboardType:(CFStringRef) itemType {
    if (itemType != NULL) {
        CFComparisonResult result = CFStringCompare(itemType, kUTTypeImage, kCFCompareCaseInsensitive);
        if (result == kCFCompareEqualTo) {
            NSMutableArray *items = [self.items mutableCopy];
            for (NSDictionary *pasteboardItem in items) {
                NSArray *pasteboardItemKeys = [pasteboardItem allKeys];
                if ([pasteboardItemKeys containsObject:(__bridge_transfer NSString *) kUTTypePNG] || [pasteboardItemKeys containsObject:(__bridge_transfer NSString *) kUTTypeJPEG]) {
                    [items removeObject:pasteboardItem];
                }
            }
            
            if (items.count != self.items.count) {
                self.items = items;
            }
        }
    }
}

@end
