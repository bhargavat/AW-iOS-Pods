//
//  AWLogger.h
//  AWLog
//
//  Copyright © 2016 VMware, Inc. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the United States and
//  other countries as well as by international treaties.
//  AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
//


#import <UIKit/UIKit.h>

//! Project version number for AWLog.
FOUNDATION_EXPORT double AWLogVersionNumber;

//! Project version string for AWLog.
FOUNDATION_EXPORT const unsigned char AWLogVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <AWLog/PublicHeader.h>

#define AWLogError(frmt, ...) [[AWLogger sharedInstance] logError:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
                                                                                    function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
                                                                                        file:[NSString stringWithUTF8String:__FILE__]\
                                                                                        line:__LINE__]

#define AWLogWarning(frmt, ...) [[AWLogger sharedInstance] logWarning:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
                                                                                        function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
                                                                                            file:[NSString stringWithUTF8String:__FILE__]\
                                                                                            line:__LINE__]


#define AWLogInfo(frmt, ...) [[AWLogger sharedInstance] logInfo:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
                                                                                  function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
                                                                                      file:[NSString stringWithUTF8String:__FILE__]\
                                                                                      line:__LINE__]

#define AWLogVerbose(frmt, ...) [[AWLogger sharedInstance] logVerbose:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
                                                                                        function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
                                                                                            file:[NSString stringWithUTF8String:__FILE__]\
                                                                                            line:__LINE__]
