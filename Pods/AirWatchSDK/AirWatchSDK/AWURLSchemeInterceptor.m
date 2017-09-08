//
//  AWURLSchemeInterceptor.m
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import "AWURLSchemeInterceptor.h"
#import "UIApplication+URLSchemesAdditions.m"

NSString *const httpURLScheme = @"http";
NSString *const httpsURLScheme = @"https";
NSString *const mailtoURLScheme = @"mailto";

NSString *const awbrowserURLScheme = @"awb";
NSString *const awsecurebrowserURLScheme = @"awbs";
NSString *const awemailURLScheme = @"awemailclient";

NSString *const awmailtoSchemeConfiguration = @"AWMailtoSchemeConfiguration";
NSString *const awURLSchemeConfiguration = @"AWURLSchemeConfiguration";

@interface AWURLSchemeInterceptor()
@property (nonatomic) BOOL isActive;

@end


@implementation AWURLSchemeInterceptor

@synthesize dataLossPreventionEnabled;
@synthesize redirectComposeEmailEnabled;
@synthesize redirectWebURLEnabled;

+ (id)sharedInstance {
    static AWURLSchemeInterceptor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    if (self) {
        dataLossPreventionEnabled = NO;
        redirectComposeEmailEnabled = NO;
        redirectWebURLEnabled = NO;
    }
    return self;
}


-(void)updateInterceptingActivity {
    //(1) check if either redirectComposeEmail or redirectWebURL is enabled, (2) DLP is enabled,
    if (dataLossPreventionEnabled && (redirectComposeEmailEnabled || redirectWebURLEnabled)) {
        //swizzle openURLIn if it has not already been swizzled
        if (!_isActive) {
            [UIApplication setUpURLSchemeHandling];
            _isActive = true;
        }
    } else if (_isActive) { ///need to unswizzle since it is no longer enabled
        [UIApplication stopURLSchemeHandling];
        _isActive = NO;
    }
}

-(BOOL)isSchemeActivated:(NSString*)scheme {
    if (scheme.length > 0) {
        if ([scheme caseInsensitiveCompare:httpURLScheme] == NSOrderedSame || [scheme caseInsensitiveCompare:httpsURLScheme] == NSOrderedSame) {
            return redirectWebURLEnabled;
        }else if ([scheme caseInsensitiveCompare:mailtoURLScheme] == NSOrderedSame) {
            return redirectComposeEmailEnabled;
        }
    }
    return NO;
}

- (NSString *) awURLSchemeForScheme:(NSString *)scheme {
    if (scheme.length > 0) {
        // Convert the scheme to lower case as the links may have the scheme in any case.
        NSString *sourceScheme = [scheme lowercaseString];
        
        // Check if scheme is enabled in the app's plist.
        BOOL isActivated = [self isSchemeActivated:scheme];
        if (isActivated) {
            
            // Get the scheme configuration from app's plist.
            NSDictionary *configuration = [self schemeConfiguration:sourceScheme];
            
            if (configuration) {
                
                NSString *awScheme = configuration[sourceScheme];
                if (awScheme.length <= 0) {
                    
                    // App's plist doesn't specify the target scheme. Default to corresponding airwatch schemes.
                    awScheme = [self defaultAWSchemeForScheme:scheme];
                }
                return awScheme;
            }
        }
    }
    return nil;
}


-(BOOL)isActive {
    return _isActive;
}

-(NSString *) schemeName:(NSString *)scheme {
    if (scheme.length > 0) {
        if ([scheme caseInsensitiveCompare:httpURLScheme] == NSOrderedSame || [scheme caseInsensitiveCompare:httpsURLScheme] == NSOrderedSame) {
            return @"open link";
        }else if ([scheme caseInsensitiveCompare:mailtoURLScheme] == NSOrderedSame) {
            return @"compose email";
        }
    }
    return nil;
}

#pragma mark - Private methods

-(NSDictionary *) mailtoSchemeConfiguration {
    id obj = [[SDKDefaultSettings sharedSettings] getRedirectComposeEmailConfiguration];
    if(obj && [obj isKindOfClass:[NSDictionary class]])
    {
        return obj;
    }
    
    return nil;
}

-(NSDictionary *) urlSchemeConfiguration {
    id obj = [[SDKDefaultSettings sharedSettings] getRedirectWebURLConfiguration];
    if(obj && [obj isKindOfClass:[NSDictionary class]])
    {
        return obj;
    }
    
    return nil;
}

-(NSDictionary *) schemeConfiguration:(NSString *)scheme {
    if (scheme.length > 0) {
        if ([scheme caseInsensitiveCompare:httpURLScheme] == NSOrderedSame || [scheme caseInsensitiveCompare:httpsURLScheme] == NSOrderedSame) {
            return [self urlSchemeConfiguration];
        }else if ([scheme caseInsensitiveCompare:mailtoURLScheme] == NSOrderedSame) {
            return [self mailtoSchemeConfiguration];
        }
    }
    return nil;
}

//+(void) activateScheme:(NSString *)scheme activate:(BOOL) activate {
//    if (scheme.length > 0) {
//        if ([scheme caseInsensitiveCompare:httpURLScheme] == NSOrderedSame || [scheme caseInsensitiveCompare:httpsURLScheme] == NSOrderedSame) {
//            isRedirectURLActivated = activate;
//        }else if ([scheme caseInsensitiveCompare:mailtoURLScheme] == NSOrderedSame) {
//            isComposeEmailActivated = activate;
//        }
//    }
//}

-(NSString *) defaultAWSchemeForScheme:(NSString *)scheme {
    
    NSString *defaultScheme;
    
    if(scheme.length > 0) {
        if ([scheme caseInsensitiveCompare:httpURLScheme] == NSOrderedSame) {
            defaultScheme = awbrowserURLScheme;
        }if([scheme caseInsensitiveCompare:httpsURLScheme] == NSOrderedSame) {
            defaultScheme = awsecurebrowserURLScheme;
        }else if([scheme caseInsensitiveCompare:mailtoURLScheme] == NSOrderedSame) {
            defaultScheme = awemailURLScheme;
        }
    }
    
    return defaultScheme;
}

@end
