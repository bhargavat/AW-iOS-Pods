//
//  AWTunnelLogger.h
//  AWTunnel
//
//  Created by Troy Liu on 5/30/17.
//  Copyright © 2017 VMWare, Inc. All rights reserved.
//

#ifndef AWTunnelLogger_h
#define AWTunnelLogger_h


#endif /* AWTunnelLogger_h */

#define AWLogError(frmt, ...) [[TunnelLogger sharedInstance] logWithError:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
file:[NSString stringWithUTF8String:__FILE__]\
line:__LINE__]

#define AWLogWarning(frmt, ...) [[TunnelLogger sharedInstance] logWithWarning:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
file:[NSString stringWithUTF8String:__FILE__]\
line:__LINE__]


#define AWLogInfo(frmt, ...) [[TunnelLogger sharedInstance] logWithInfo:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
file:[NSString stringWithUTF8String:__FILE__]\
line:__LINE__]

#define AWLogVerbose(frmt, ...) [[TunnelLogger sharedInstance] logWithVerbose:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
file:[NSString stringWithUTF8String:__FILE__]\
line:__LINE__]

#define AWLogDebug(frmt, ...) [[TunnelLogger sharedInstance] logWithDebug:[NSString stringWithFormat:(frmt), ##__VA_ARGS__]\
function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]\
file:[NSString stringWithUTF8String:__FILE__]\
line:__LINE__]
