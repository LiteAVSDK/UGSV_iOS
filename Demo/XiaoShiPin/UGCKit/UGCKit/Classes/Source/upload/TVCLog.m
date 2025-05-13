//
//  TVCLog.m
//  TXUGCUploadDemo
//
//  Created by Kongdywang on 2023/8/1.
//  Copyright © 2023 tencent. All rights reserved.
//

#import "TVCLog.h"

@implementation TVCLog

+ (instancetype)sharedLogger {
    static TVCLog *vodLogger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        vodLogger = [[TVCLog alloc] init];
    });
    return vodLogger;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        // log all
        self.logLevel = QCloudLogLevelVerbose;
    }
    return self;
}

- (void)setLogLevel:(QCloudLogLevel)logLevel {
    _logLevel = logLevel;
    [QCloudLogger sharedLogger].logLevel = self.logLevel;
}

- (void)logMessageWithLevel:(QCloudLogLevel)level cmd:(const char *)commandInfo line:(int)line file:(const char *)file format:(NSString *)format, ... NS_FORMAT_FUNCTION(5, 6) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    NSString *traceMsg = [[NSString alloc] initWithFormat:@"[TVCUpload]%@", message];
    [[QCloudLogger sharedLogger] logMessageWithLevel:level cmd:commandInfo line:line file:file format:traceMsg];
    va_end(args);
}

@end
