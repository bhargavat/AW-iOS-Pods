//
//  UIDevice+Console.m
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


#import "UIDevice+Console.h"
#include <asl.h>

@implementation AWConsoleLog

-(instancetype)initWithLevel:(NSString*)level date:(NSDate*)date description:(NSString*)description {
    if (self = [super init]) {
        self.logLevel = level;
        self.logDate = date;
        self.logDescription = description;
    }
    return self;
}

@end

@implementation UIDevice (Console)

+ (NSArray*)logLevels
{
    static NSArray* logLevels = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logLevels = @[
                          [NSString stringWithCString: ASL_STRING_EMERG encoding:NSUTF8StringEncoding],
                          [NSString stringWithCString: ASL_STRING_ALERT encoding:NSUTF8StringEncoding],
                          [NSString stringWithCString: ASL_STRING_CRIT encoding:NSUTF8StringEncoding],
                          [NSString stringWithCString: ASL_STRING_ERR encoding:NSUTF8StringEncoding],
                          [NSString stringWithCString: ASL_STRING_WARNING encoding:NSUTF8StringEncoding],
                          [NSString stringWithCString: ASL_STRING_NOTICE encoding:NSUTF8StringEncoding],
                          [NSString stringWithCString: ASL_STRING_INFO encoding:NSUTF8StringEncoding],
                          [NSString stringWithCString: ASL_STRING_DEBUG encoding:NSUTF8StringEncoding]
                      ];
    });
    return logLevels;
}

+ (int)getIntEquivalentOfLogLevel:(NSString *)level
{
    NSArray *logLevels = [UIDevice logLevels];
    NSInteger index = [logLevels indexOfObject:level];
    if (index == NSNotFound) {
        return 0;
    }
    
    return (int)index;
}

+ (NSString *)getLevelFromInt:(int)level
{
    NSArray *logLevels = [UIDevice logLevels];
    if(level >=0 && level < logLevels.count) {
        return logLevels[level];
    }
    return nil;
}

+(AWConsoleLog*) consoleLogForMessage:(aslmsg)message
{
    NSString *logLevel = [UIDevice getLevelFromInt:atoi(asl_get(message, ASL_KEY_LEVEL))];
    NSDate *logDate = [NSDate dateWithTimeIntervalSince1970:atof(asl_get(message, ASL_KEY_TIME))];
    NSString *logDescription = [NSString stringWithFormat:@"%s[%s]: %s", asl_get(message, ASL_KEY_SENDER), asl_get(message, ASL_KEY_PID), asl_get(message, ASL_KEY_MSG)];
    
    return [[AWConsoleLog alloc] initWithLevel: logLevel
                                          date: logDate
                                   description: logDescription];
    
}

- (NSString *)getConsoleLogWithApplication:(NSString *)app NumberOfEntries:(int)maxEntries
{
    NSArray *logs = [self queryConsoleLogsLimitBy:maxEntries forApplication:app filteringApplication:nil];
    return [logs componentsJoinedByString:@" \n"];
}

- (NSArray *)getConsoleLogsWithApplication:(NSString *)app NumberOfEntries:(int)maxEntries
{
    return [self queryConsoleLogsLimitBy:maxEntries forApplication:app filteringApplication:nil];
}
- (NSArray *)AW_ConsoleLogsWithApplication:(NSString *)app
{
    return [self queryConsoleLogsLimitBy:NSUIntegerMax forApplication:app filteringApplication:nil];
}


-(NSArray*) getIosDeviceLogs
{
    return [self queryConsoleLogsLimitBy:NSUIntegerMax forApplication:nil filteringApplication:nil];
}

-(NSArray*)getIOSDeviceLogsFilterWithRunningApp:(NSString *)filterAppName
{
    return [self queryConsoleLogsLimitBy:NSUIntegerMax forApplication:nil filteringApplication:filterAppName];
}

-(NSArray*) queryConsoleLogsLimitBy:(NSUInteger)limit forApplication:(NSString*)queryingApp filteringApplication:(NSString*)filteringApp
{
    NSMutableArray *logsList = [[NSMutableArray alloc]init];
    aslmsg q = asl_new(ASL_TYPE_QUERY);
    
    if (queryingApp != nil) {
        asl_set_query(q, ASL_KEY_SENDER, [queryingApp cStringUsingEncoding:NSUTF8StringEncoding], ASL_QUERY_OP_EQUAL);
    }

    
    if (filteringApp != nil) {
        asl_set_query(q, ASL_KEY_SENDER, [filteringApp cStringUsingEncoding:NSUTF8StringEncoding], ASL_QUERY_OP_NOT_EQUAL);
    }
    
    aslresponse r = asl_search(NULL, q);
    aslmsg m = asl_next(r);
    while (m != NULL && logsList.count < limit)
    {
        [logsList addObject:[UIDevice consoleLogForMessage:m]];
        m = asl_next(r);
    }
    
    asl_release(r);
    return logsList;
}

@end