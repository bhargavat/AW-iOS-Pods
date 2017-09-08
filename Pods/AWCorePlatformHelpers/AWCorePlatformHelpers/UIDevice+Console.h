//
//  UIDevice+Console.h
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


#import <UIKit/UIKit.h>

@interface AWConsoleLog: NSObject
@property (nonatomic, strong) NSDate *logDate;
@property (nonatomic, strong) NSString *logDescription;
@property (nonatomic, strong) NSString *logLevel;
@end

@interface UIDevice (Console)

+ (NSString *)getLevelFromInt:(int)lvl;
+ (int)getIntEquivalentOfLogLevel:(NSString *)lvl;

- (NSString *)getConsoleLogWithApplication:(NSString *)app NumberOfEntries:(int)maxEntries;
- (NSArray *)getConsoleLogsWithApplication:(NSString *)app NumberOfEntries:(int)maxEntries;
- (NSArray *)AW_ConsoleLogsWithApplication:(NSString *)app; // all the log of respective application

- (NSArray*)getIosDeviceLogs;
- (NSArray*)getIOSDeviceLogsFilterWithRunningApp:(NSString *)filterAppName;

@end