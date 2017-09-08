//
//  AWTunnel.h
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import <UIKit/UIKit.h>

//! Project version number for AWTunnel.
FOUNDATION_EXPORT double AWTunnelVersionNumber;

//! Project version string for AWTunnel.
FOUNDATION_EXPORT const unsigned char AWTunnelVersionString[];

#import "AWProxy.h"
#import "AWProxyHandler.h"
#import "AWRequestSigner.h"
#import "MobileAPI.h"

static inline NSError *AWErrorMacro(NSString *const errorDomain,
                                    NSInteger errorCode,
                                    NSString *localizedDescription,
                                    NSString *localizedRecoverySuggestion,
                                    NSString *localizedFailureReason) {
    
    NSMutableDictionary *errorUserInfo = [NSMutableDictionary dictionary];
    
    if (localizedDescription != nil) {
        
        [errorUserInfo setValue:localizedDescription forKey:NSLocalizedDescriptionKey];
        
    }
    
    if (localizedRecoverySuggestion != nil) {
        
        [errorUserInfo setValue:localizedRecoverySuggestion forKey:NSLocalizedRecoverySuggestionErrorKey];
        
    }
    
    if (localizedFailureReason != nil) {
        
        [errorUserInfo setValue:localizedFailureReason forKey:NSLocalizedFailureReasonErrorKey];
        
    }
    
    NSError *error = [NSError errorWithDomain:errorDomain code:errorCode userInfo:errorUserInfo];
    
    return error;
    
}
