//
//  TVCLog.h
//  TXUGCUploadDemo
//
//  Created by Kongdywang on 2023/8/1.
//  Copyright © 2023 tencent. All rights reserved.
//

#import <QCloudCore/QCloudLogger.h>
#import <Foundation/Foundation.h>

#ifndef TVCLog_h
#define TVCLog_h
#define VodLog(level, frmt, ...) \
    [[TVCLog sharedLogger] logMessageWithLevel:level cmd:__PRETTY_FUNCTION__ line:__LINE__ file:__FILE__ format:(frmt), ##__VA_ARGS__]

#define VodLogError(frmt, ...) VodLog(QCloudLogLevelError, (frmt), ##__VA_ARGS__)

#define VodLogWarning(frmt, ...) VodLog(QCloudLogLevelWarning, (frmt), ##__VA_ARGS__)

#define VodLogInfo(frmt, ...) VodLog(QCloudLogLevelInfo, (frmt), ##__VA_ARGS__)

#define VodLogDebug(frmt, ...) VodLog(QCloudLogLevelDebug, (frmt), ##__VA_ARGS__)

#define VodLogVerbose(frmt, ...) VodLog(QCloudLogLevelVerbose, (frmt), ##__VA_ARGS__)

#define VodLogException(exception) QCloudLogException(exception)

#define VodLogTrance() QCloudLogTrance()

@interface TVCLog : NSObject

@property (nonatomic, assign) QCloudLogLevel logLevel;

+ (instancetype)sharedLogger;

- (void)setLogLevel:(QCloudLogLevel)logLevel;

- (void)logMessageWithLevel:(QCloudLogLevel)level cmd:(const char *)commandInfo line:(int)line file:(const char *)file format:(NSString *)format, ...;

@end


#endif /* TVCLog_h */
