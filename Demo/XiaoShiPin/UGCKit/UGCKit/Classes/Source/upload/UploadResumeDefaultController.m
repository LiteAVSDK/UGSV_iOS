//
//  UploadResumeDefaultController.m
//  TXLiteAVDemo
//
//  Created by Kongdywang on 2022/12/26.
//  Copyright © 2022 Tencent. All rights reserved.
//

#import "UploadResumeDefaultController.h"
#import "TXUGCPublishUtil.h"
#import "TVCLog.h"

@implementation UploadResumeDefaultController

- (NSMutableDictionary*)getCacheDicByKey:(NSString*)key {
    NSError *jsonErr = nil;
    NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (str == nil) {
        VodLogError(@"%@ is nil", TVCMultipartResumeSessionKey);
        return nil;
    }
    NSMutableDictionary *dic = [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:NSJSONReadingAllowFragments
                                                                 error:&jsonErr];
    if (jsonErr) {
        VodLogError(@"%@ is not json format: %@", TVCMultipartResumeSessionKey, str);
        return nil;
    }
    return dic;
}

- (void)saveUserData:(NSData*)data withKey:(NSString*)key
{
    NSString *strData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [[NSUserDefaults standardUserDefaults] setObject:strData forKey:key];
}

- (void)clearLocalCache {
    NSMutableDictionary *sessionDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *timeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *lastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *coverLastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *resumeDataDic = [[NSMutableDictionary alloc] init];
    NSError *jsonErr = nil;
    NSInteger nowTime = (NSInteger)[[NSDate date] timeIntervalSince1970] + 1;
    
    sessionDic = [self getCacheDicByKey:TVCMultipartResumeSessionKey];
    if (sessionDic == nil) {
        VodLogError(@"TVCMultipartResumeSessionKey is nil");
        return;
    }
    
    timeDic = [self getCacheDicByKey:TVCMultipartResumeExpireTimeKey];
    if (timeDic == nil) {
        VodLogError(@"TVCMultipartResumeExpireTimeKey is nil");
        return;
    }
    
    lastModTimeDic = [self getCacheDicByKey:TVCMultipartFileLastModTime];
    if (lastModTimeDic == nil) {
        VodLogError(@"TVCMultipartFileLastModTime is nil");
        return;
    }
    
    coverLastModTimeDic = [self getCacheDicByKey:TVCMultipartCoverFileLastModTime];
    if (coverLastModTimeDic == nil) {
        VodLogError(@"TVCMultipartCoverFileLastModTime is nil");
        return;
    }
    
    resumeDataDic = [self getCacheDicByKey:TVCMultipartResumeData];
    if (resumeDataDic == nil) {
        VodLogError(@"TVCMultipartReumeData is nil");
        return;
    }

    // 删除过期的session，并保存
    NSMutableDictionary *newSessionDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newLastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newCoverLastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newResumeDataDic = [[NSMutableDictionary alloc] init];
    for (NSString *key in timeDic) {
        NSInteger expireTime = [[timeDic objectForKey:key] integerValue];
        if (nowTime < expireTime) {
            [newSessionDic setValue:[sessionDic objectForKey:key] forKey:key];
            [newTimeDic setValue:[timeDic objectForKey:key] forKey:key];
            [newLastModTimeDic setValue:[lastModTimeDic objectForKey:key] forKey:key];
            [newCoverLastModTimeDic setValue:[coverLastModTimeDic objectForKey:key] forKey:key];
            [newResumeDataDic setValue:[resumeDataDic objectForKey:key] forKey:key];
        }
    }

    // 将newSessionDic 和 newTimeDic 保存文件
    NSData *newSessionJsonData = [NSJSONSerialization dataWithJSONObject:newSessionDic options:0 error:&jsonErr];
    NSData *newTimeJsonData = [NSJSONSerialization dataWithJSONObject:newTimeDic options:0 error:&jsonErr];
    NSData *newLastModTimeJsonData = [NSJSONSerialization dataWithJSONObject:newLastModTimeDic options:0 error:&jsonErr];
    NSData *newCoverLastModTimeJsonData = [NSJSONSerialization dataWithJSONObject:newCoverLastModTimeDic options:0 error:&jsonErr];
    NSData *newResumeDataJsonData = [NSJSONSerialization dataWithJSONObject:newResumeDataDic options:0 error:&jsonErr];

    NSString *strNeweSession = [[NSString alloc] initWithData:newSessionJsonData encoding:NSUTF8StringEncoding];
    NSString *strNewTime = [[NSString alloc] initWithData:newTimeJsonData encoding:NSUTF8StringEncoding];
    NSString *strNewLastModTime = [[NSString alloc] initWithData:newLastModTimeJsonData encoding:NSUTF8StringEncoding];
    NSString *strNewCoverLastModTime = [[NSString alloc] initWithData:newCoverLastModTimeJsonData encoding:NSUTF8StringEncoding];
    NSString *strNewResumeData = [[NSString alloc] initWithData:newResumeDataJsonData encoding:NSUTF8StringEncoding];

    [[NSUserDefaults standardUserDefaults] setObject:strNeweSession forKey:TVCMultipartResumeSessionKey];
    [[NSUserDefaults standardUserDefaults] setObject:strNewTime forKey:TVCMultipartResumeExpireTimeKey];
    [[NSUserDefaults standardUserDefaults] setObject:strNewLastModTime forKey:TVCMultipartFileLastModTime];
    [[NSUserDefaults standardUserDefaults] setObject:strNewCoverLastModTime forKey:TVCMultipartCoverFileLastModTime];
    [[NSUserDefaults standardUserDefaults] setObject:strNewResumeData forKey:TVCMultipartResumeData];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (ResumeCacheData *)getResumeData:(NSString *)filePath {
    if (filePath == nil || filePath.length == 0) {
        return nil;
    }
    // 使用md5作为key
    NSString *sessionKey = [TXUGCPublishUtil getFileMD5StrFromPath:filePath];
    ResumeCacheData *cacheData = [[ResumeCacheData alloc] init];

    NSMutableDictionary *sessionDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *timeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *lastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *coverLastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *resumeDataDic = [[NSMutableDictionary alloc] init];

    NSError *jsonErr = nil;

    sessionDic = [self getCacheDicByKey:TVCMultipartResumeSessionKey];
    if (sessionDic == nil) {
        VodLogError(@"TVCMultipartResumeSessionKey is nil");
        return nil;
    }
    
    timeDic = [self getCacheDicByKey:TVCMultipartResumeExpireTimeKey];
    if (timeDic == nil) {
        VodLogError(@"TVCMultipartResumeExpireTimeKey is nil");
        return nil;
    }
    
    lastModTimeDic = [self getCacheDicByKey:TVCMultipartFileLastModTime];
    if (lastModTimeDic == nil) {
        VodLogError(@"TVCMultipartFileLastModTime is nil");
        return nil;
    }
    
    coverLastModTimeDic = [self getCacheDicByKey:TVCMultipartCoverFileLastModTime];
    if (coverLastModTimeDic == nil) {
        VodLogError(@"TVCMultipartCoverFileLastModTime is nil");
        return nil;
    }
    
    resumeDataDic = [self getCacheDicByKey:TVCMultipartResumeData];
    if (resumeDataDic == nil) {
        VodLogError(@"TVCMultipartReumeData is nil");
        return nil;
    }

    NSString *session = [sessionDic objectForKey:sessionKey];
    NSInteger expireTime = [[timeDic objectForKey:sessionKey] integerValue];
    unsigned long long lastModTime = [[lastModTimeDic objectForKey:sessionKey] unsignedLongLongValue];
    unsigned long long coverLastModTime = [[coverLastModTimeDic objectForKey:sessionKey] unsignedLongLongValue];
    NSString *sResumeData = [resumeDataDic objectForKey:sessionKey];
    NSInteger nowTime = (NSInteger)[[NSDate date] timeIntervalSince1970] + 1;

    if (session && nowTime < expireTime && sResumeData != nil && sResumeData.length != 0) {
        NSData *resumeData = [[NSData alloc] initWithBase64EncodedString:sResumeData options:0];
        cacheData.vodSessionKey = session;
        cacheData.resumeData = resumeData;
        cacheData.videoLastModTime = lastModTime;
        cacheData.coverLastModTime = coverLastModTime;
    } else {
        VodLogWarning(@"TVCMultipartReumeData is invalid");
    }

    // 删除过期的session，并保存
    NSMutableDictionary *newSessionDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newLastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newCoverLastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newResumeDataDic = [[NSMutableDictionary alloc] init];
    for (NSString *key in timeDic) {
        NSInteger expireTime = [[timeDic objectForKey:key] integerValue];
        if (nowTime < expireTime) {
            [newSessionDic setValue:[sessionDic objectForKey:key] forKey:key];
            [newTimeDic setValue:[timeDic objectForKey:key] forKey:key];
            [newLastModTimeDic setValue:[lastModTimeDic objectForKey:key] forKey:key];
            [newCoverLastModTimeDic setValue:[coverLastModTimeDic objectForKey:key] forKey:key];
            [newResumeDataDic setValue:[resumeDataDic objectForKey:key] forKey:key];
        }
    }

    // 将newSessionDic 和 newTimeDic 保存文件
    // 保存文件
    NSData *newSessionJsonData = [NSJSONSerialization dataWithJSONObject:sessionDic options:0 error:&jsonErr];
    NSData *newTimeJsonData = [NSJSONSerialization dataWithJSONObject:timeDic options:0 error:&jsonErr];
    NSData *newLastModTimeJsonData = [NSJSONSerialization dataWithJSONObject:lastModTimeDic options:0 error:&jsonErr];
    NSData *newCoverLastModTimeJsonData = [NSJSONSerialization dataWithJSONObject:coverLastModTimeDic options:0 error:&jsonErr];
    NSData *newResumeDaaJsonData = [NSJSONSerialization dataWithJSONObject:resumeDataDic options:0 error:&jsonErr];
    [self saveUserData:newSessionJsonData withKey:TVCMultipartResumeSessionKey];
    [self saveUserData:newTimeJsonData withKey:TVCMultipartResumeExpireTimeKey];
    [self saveUserData:newLastModTimeJsonData withKey:TVCMultipartFileLastModTime];
    [self saveUserData:newCoverLastModTimeJsonData withKey:TVCMultipartCoverFileLastModTime];
    [self saveUserData:newResumeDaaJsonData withKey:TVCMultipartResumeData];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return cacheData;
}

- (BOOL)isResumeUploadVideo:(TVCUploadContext *)uploadContext withSessionKey:(NSString *)vodSessionKey
            withFileModTime:(uint64_t)videoLastModTime withCoverModTime:(uint64_t)coverLastModTime {
    return uploadContext.resumeData && uploadContext.resumeData.length > 0 && uploadContext && vodSessionKey && vodSessionKey.length > 0;
}

- (void)saveSession:(NSString *)filePath withSessionKey:(NSString *)vodSessionKey withResumeData:(NSData *)resumeData
     withUploadInfo:(TVCUploadContext *)uploadContext {
    if (filePath == nil || filePath.length == 0) {
        return;
    }
    // 使用md5作为keyfileSystemFileNumber
    NSString *sessionKey = [TXUGCPublishUtil getFileMD5StrFromPath:filePath];

    NSMutableDictionary *sessionDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *timeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *lastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *coverLastModTimeDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *resumeDataDic = [[NSMutableDictionary alloc] init];
    NSError *jsonErr = nil;

    NSString *strPathToSession = [[NSUserDefaults standardUserDefaults] objectForKey:TVCMultipartResumeSessionKey];
    if (strPathToSession) {
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[strPathToSession dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:NSJSONReadingAllowFragments
                                                              error:&jsonErr];
        sessionDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    }

    NSString *strPathToExpireTime = [[NSUserDefaults standardUserDefaults] objectForKey:TVCMultipartResumeExpireTimeKey];
    if (strPathToExpireTime) {
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[strPathToExpireTime dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:NSJSONReadingAllowFragments
                                                              error:&jsonErr];
        timeDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    }

    NSString *strPathToLastModTime = [[NSUserDefaults standardUserDefaults] objectForKey:TVCMultipartFileLastModTime];
    if (strPathToLastModTime) {
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[strPathToLastModTime dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:NSJSONReadingAllowFragments
                                                              error:&jsonErr];
        lastModTimeDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    }

    NSString *strPathToCoverLastModTime = [[NSUserDefaults standardUserDefaults] objectForKey:TVCMultipartFileLastModTime];
    if (strPathToCoverLastModTime) {
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[strPathToCoverLastModTime dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:NSJSONReadingAllowFragments
                                                              error:&jsonErr];
        coverLastModTimeDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    }

    // read [itemPath, resumeData]
    NSString *strPathToResumeData = [[NSUserDefaults standardUserDefaults] objectForKey:TVCMultipartResumeData];
    if (strPathToResumeData) {
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[strPathToResumeData dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:NSJSONReadingAllowFragments
                                                              error:&jsonErr];
        resumeDataDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    }

    // 设置过期时间为1天
    NSInteger expireTime = (NSInteger)[[NSDate date] timeIntervalSince1970] + 24 * 60 * 60;
    uint64_t lastModTime = 0;
    uint64_t coverLastModTime = 0;
    if(uploadContext != nil) {
        lastModTime = uploadContext.videoLastModTime;
        coverLastModTime = uploadContext.coverLastModTime;
    }

    // session、resumeDataDic 为空，lastModTime为0就表示删掉该 [key, value]
    if (vodSessionKey == nil || vodSessionKey.length == 0 || resumeData == nil || resumeData.length == 0 || lastModTime == 0) {
        [sessionDic removeObjectForKey:sessionKey];
        [timeDic removeObjectForKey:sessionKey];
        [lastModTimeDic removeObjectForKey:sessionKey];
        [coverLastModTimeDic removeObjectForKey:sessionKey];
        [resumeDataDic removeObjectForKey:sessionKey];
    } else {
        [sessionDic setValue:vodSessionKey forKey:sessionKey];
        [timeDic setValue:@(expireTime) forKey:sessionKey];
        [lastModTimeDic setValue:@(lastModTime) forKey:sessionKey];
        [coverLastModTimeDic setValue:@(coverLastModTime) forKey:sessionKey];
        NSString *sResumeData = [resumeData base64EncodedStringWithOptions:0];
        [resumeDataDic setValue:sResumeData forKey:sessionKey];
    }

    // 保存文件
    NSData *newSessionJsonData = [NSJSONSerialization dataWithJSONObject:sessionDic options:0 error:&jsonErr];
    NSData *newTimeJsonData = [NSJSONSerialization dataWithJSONObject:timeDic options:0 error:&jsonErr];
    NSData *newLastModTimeJsonData = [NSJSONSerialization dataWithJSONObject:lastModTimeDic options:0 error:&jsonErr];
    NSData *newCoverLastModTimeJsonData = [NSJSONSerialization dataWithJSONObject:coverLastModTimeDic options:0 error:&jsonErr];
    NSData *newResumeDaaJsonData = [NSJSONSerialization dataWithJSONObject:resumeDataDic options:0 error:&jsonErr];
    [self saveUserData:newSessionJsonData withKey:TVCMultipartResumeSessionKey];
    [self saveUserData:newTimeJsonData withKey:TVCMultipartResumeExpireTimeKey];
    [self saveUserData:newLastModTimeJsonData withKey:TVCMultipartFileLastModTime];
    [self saveUserData:newCoverLastModTimeJsonData withKey:TVCMultipartCoverFileLastModTime];
    [self saveUserData:newResumeDaaJsonData withKey:TVCMultipartResumeData];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end
