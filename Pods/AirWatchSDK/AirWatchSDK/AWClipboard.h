//
//  AWPasteboard.h
//  Clipboard
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AWClipboard : NSObject

@property (nonatomic) BOOL preventCopyPaste;
@property (nonatomic) BOOL isAirWatchClipboardEnabled;

+(AWClipboard *)sharedInstance;

+(BOOL) supportsAction:(SEL) action withSender:(id) sender;

@end
