//
//  UIApplication+URLSchemesAdditions.m
//  AirWatch
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


#import "UIApplication+URLSchemesAdditions.h"
#import "AWClipboard.h"
#import "AWURLSchemeInterceptor.h"
@import AWLocalization;
@import AWHelpers;


@implementation UIApplication (URLSchemesAdditions)

+(void) setUpURLSchemeHandling {

    BOOL isEnabled = [[AWURLSchemeInterceptor sharedInstance] redirectWebURLEnabled] || [[AWURLSchemeInterceptor sharedInstance] redirectComposeEmailEnabled];

    if (isEnabled == NO || [[AWURLSchemeInterceptor sharedInstance] isActive]) {
        // No need to swizzle scheme interceptor
        return;
    }

    if([self instancesRespondToSelector:@selector(openURL:)]) {
        MethodSwizzle([self class], @selector(openURL:), @selector(awSwizzle_openURL:), NO);
    }

    if ([self instancesRespondToSelector:@selector(openURL:options:completionHandler:)]) {
        MethodSwizzle([self class], @selector(openURL:options:completionHandler:), @selector(awSwizzle_openURL:options:completionHandler:), NO);
    }
}

+(void) stopURLSchemeHandling {
    if ([[AWURLSchemeInterceptor sharedInstance] isActive]) { ///make sure it is Active so that it can be un-swizzled

        if([self instancesRespondToSelector:@selector(openURL:)]) {
            MethodSwizzle([self class], @selector(awSwizzle_openURL:), @selector(openURL:), NO);
        }

        if ([self instancesRespondToSelector:@selector(openURL:options:completionHandler:)]) {
            MethodSwizzle([self class], @selector(awSwizzle_openURL:options:completionHandler:), @selector(awSwizzle_openURL:options:completionHandler:), NO);
        }
    }
}

-(BOOL) awSwizzle_openURL:(NSURL *_Nullable) url {
    if (url != nil) {
        BOOL isActivated = [[AWURLSchemeInterceptor sharedInstance] isSchemeActivated:url.scheme];

        if (isActivated) {
            NSString *targetScheme = [[AWURLSchemeInterceptor sharedInstance] awURLSchemeForScheme:url.scheme];
            if (targetScheme.length > 0) {
                NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
                components.scheme = targetScheme;
                NSURL *targetURL = components.URL;
                BOOL opened = [self awSwizzle_openURL:targetURL];
                if (!opened) {
                    NSString *alertTitle = AWSDKLocalizedString(@"ErrorTitle", nil);
                    NSString *schemeName = [[AWURLSchemeInterceptor sharedInstance] schemeName:url.scheme];
                    NSString *alertMessage = [NSString stringWithFormat:AWSDKLocalizedString(@"TargetAppNotInstalledMessage", nil), schemeName];
                    KeyWindowAlert *alert = [[KeyWindowAlert alloc] initWithTitle: alertTitle message:alertMessage actions:nil];
                    id result __attribute__((unused)) = [alert show];
                }
                return opened;
            }
        }
    }

    return [self awSwizzle_openURL:url];
}

-(void) awSwizzle_openURL:(NSURL*_Nullable)url options:(NSDictionary<NSString *, id> *_Nonnull)options completionHandler:(void (^ __nullable)(BOOL success))completion {
    if (url != nil) {
        BOOL isActivated = [[AWURLSchemeInterceptor sharedInstance] isSchemeActivated:url.scheme];

        if (isActivated) {
            NSString *targetScheme = [[AWURLSchemeInterceptor sharedInstance] awURLSchemeForScheme:url.scheme];
            if (targetScheme.length > 0) {
                NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
                components.scheme = targetScheme;
                NSURL *targetURL = components.URL;

                [self awSwizzle_openURL:targetURL options:options completionHandler:^(BOOL success) {
                    if (success == NO) {
                        NSString *alertTitle = AWSDKLocalizedString(@"ErrorTitle", nil);
                        NSString *schemeName = [[AWURLSchemeInterceptor sharedInstance] schemeName:url.scheme];
                        NSString *alertMessage = [NSString stringWithFormat:AWSDKLocalizedString(@"TargetAppNotInstalledMessage", nil), schemeName];
                        KeyWindowAlert *alert = [[KeyWindowAlert alloc] initWithTitle: alertTitle message:alertMessage actions:nil];
                        id result __attribute__((unused)) = [alert show];
                    }
                    if (completion != NULL) {
                        completion(success);
                    }
                }];

                return;
            }
        }
    }

    // Fall back to the default behavior.
    [self awSwizzle_openURL:url options:options completionHandler:completion];
}

@end
