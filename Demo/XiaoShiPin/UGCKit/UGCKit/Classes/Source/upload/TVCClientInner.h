//
//  TVCClientInner.h
//  TVCClientSDK
//
//  Created by tomzhu on 16/10/20.
//  Copyright © 2016年 tencent. All rights reserved.
//

#import "TVCHeader.h"


#define UGC_HOST        @"vod2.qcloud.com"
#define UGC_HOST_BAK    @"vod2.dnsv1.com"

// Maximum number of requests
#define kMaxRequestCount 2

#pragma mark - UCG rsp parse

#define kCode           @"code"
#define kMessage        @"message"
#define kData           @"data"

#define TVCVersion @"1.2.4.0"

#pragma mark - COS config
// Field deprecated, used as a placeholder field for InitUploadUGC
#define kRegion @"gz"
// Timeout
#define kTimeoutInterval 20

@interface TVCUGCResult : NSObject

@property(nonatomic,strong) NSString * videoFileId;

@property(nonatomic,strong) NSString * imageFileId;

/**
 Number in JSON
 json中为数字
 */
@property(nonatomic,strong) NSString * uploadAppid;

@property(nonatomic,strong) NSString * uploadBucket;

@property(nonatomic,strong) NSString * videoPath;

@property(nonatomic,strong) NSString * imagePath;

@property(nonatomic,strong) NSString * videoSign;

@property(nonatomic,strong) NSString * imageSign;

@property(nonatomic,strong) NSString * uploadSession;

@property(nonatomic,strong) NSString * uploadRegion;

@property(nonatomic,strong) NSString * domain;

@property(atomic,assign) int useCosAcc;

@property(nonatomic,strong) NSString * cosAccDomain;

@property(nonatomic,strong) NSString * userAppid;           // User appid, used for data reporting

@property(nonatomic,strong) NSString * tmpSecretId;         // COS temporary secret key SecretId

@property(nonatomic,strong) NSString * tmpSecretKey;        // COS temporary secret key SecretKey

@property(nonatomic,strong) NSString * tmpToken;            // COS temporary secret key Token

@property(atomic,assign) uint64_t  tmpExpiredTime;          // COS temporary secret key ExpiredTime

@property(atomic,assign) uint64_t  currentTS;               // Calibrated timestamp returned by the backend

@end

@interface TVCUploadContext : NSObject

@property(nonatomic,strong) TVCUploadParam * uploadParam;

@property(nonatomic,strong) TVCResultBlock resultBlock;

@property(nonatomic,strong) TVCProgressBlock progressBlock;

@property(nonatomic,assign) BOOL isUploadVideo;

@property(nonatomic,assign) BOOL isUploadCover;

@property(atomic,assign) TVCResult lastStatus;

@property(nonatomic,strong) NSString * desc;

@property(nonatomic,strong) TVCUGCResult * cugResult;

@property(nonatomic,strong) dispatch_group_t gcdGroup;

@property(nonatomic,strong) dispatch_semaphore_t gcdSem;

@property(nonatomic,strong) dispatch_queue_t gcdQueue;

@property(atomic,assign) uint64_t videoSize;

@property(atomic,assign) uint64_t coverSize;

@property(atomic,assign) uint64_t currentUpload;

@property(atomic,assign) uint64_t videoLastModTime; // Last modified time of the file

@property(atomic,assign) uint64_t coverLastModTime; // Last modified time of the cover
// Request start time, used to calculate the time consumption of each request
@property(atomic,assign) uint64_t reqTime;
// Request upload time, used to concatenate the publishing process with the last modified
// time of the video to form reqKey
@property(atomic,assign) uint64_t initReqTime;
// Retry due to temporary signature expiration causing upload failure
@property(nonatomic,assign) BOOL isShouldRetry;

@property(nonatomic,assign) int vodCmdRequestCount;   // VOD signaling request times
// Msg for main domain name request failure, used for backup domain name request failure reporting
@property(nonatomic,copy) NSString* mainVodServerErrMsg;

@property(nonatomic,strong) NSData * resumeData;    // COS chunk upload resumeData

@property(atomic, assign) BOOL isQuic;

@end


@interface TVCReportInfo : NSObject

@property(atomic,assign) int reqType;

@property(atomic,assign) int errCode;

@property(atomic,assign) int vodErrCode;

@property(nonatomic,strong) NSString * cosErrCode;

@property(nonatomic,strong) NSString * errMsg;

@property(atomic,assign) uint64_t reqTime;

@property(atomic,assign) uint64_t reqTimeCost;

@property(atomic,assign) uint64_t fileSize;

@property(nonatomic,strong) NSString * fileType;

@property(nonatomic,strong) NSString * fileName;

@property(nonatomic,strong) NSString * fileId;

@property(atomic,assign) uint64_t appId;

@property(nonatomic,strong) NSString * reqServerIp;

@property(nonatomic,strong) NSString * reportId;

@property(nonatomic,strong) NSString * reqKey;

@property(nonatomic,strong) NSString * vodSessionKey;

@property(atomic,assign) int useHttpDNS;

@property(nonatomic,strong) NSString * cosRegion;

@property(atomic,assign) int useCosAcc;

@property(atomic, strong) NSString *cosVideoPath;

@property(atomic,assign) uint64_t tcpConnTimeCost;

@property(atomic,assign) uint64_t recvRespTimeCost;

@property(atomic,assign) int retryCount;

@property(nonatomic,assign) BOOL reporting;

@property(nonatomic,strong) NSString * requestId;

@end

/**
 Resume cache
 */
@interface ResumeCacheData : NSObject
// Upload session
// 上传session
@property(nonatomic,strong) NSString * vodSessionKey;
// COS chunk upload resumeData
// cos分片上传resumeData
@property(nonatomic,strong) NSData * resumeData;
// Last modified time of the file
// 文件最后修改时间
@property(atomic,assign) uint64_t videoLastModTime;
// Last modified time of the cover
// 封面最后修改时间
@property(atomic,assign) uint64_t coverLastModTime;

@end
