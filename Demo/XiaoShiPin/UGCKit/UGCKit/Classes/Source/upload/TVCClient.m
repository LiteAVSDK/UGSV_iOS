//
//  TVCClient.m
//  VCDemo
//
//  Created by kennethmiao on 16/10/18.
//  Copyright © 2016年 kennethmiao. All rights reserved.
//

#import "TVCClient.h"
#import "TVCClientInner.h"
#import "TVCCommon.h"
#import "TVCHttpMessageURLProtocol.h"
#import "TVCReport.h"
#import "TXUGCPublishOptCenter.h"
#import <AVFoundation/AVFoundation.h>
#import <QCloudCOSXML/QCloudCOSXML.h>
#import <QCloudCore/QCloudAuthentationV5Creator.h>
#import <QCloudCore/QCloudCore.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/types.h>
#import "QuicClient.h"
#import "QCloudQuicConfig.h"
#import "TVCConfig.h"
#import "TVCLog.h"

#define TVCMultipartResumeSessionKey        @"TVCMultipartResumeSessionKey"         // 点播vodSessionKey
#define TVCMultipartResumeExpireTimeKey     @"TVCMultipartResumeExpireTimeKey"      // vodSessionKey过期时间
#define TVCMultipartFileLastModTime         @"TVCMultipartFileLastModTime"          // 文件最后修改时间，用于在断点续传的时候判断文件是否修改
#define TVCMultipartCoverFileLastModTime    @"TVCMultipartCoverFileLastModTime"     // 封面文件最后修改时间
#define TVCMultipartResumeData              @"TVCMultipartUploadResumeData"         // cos分片上传文件resumeData

#define TVCUGCUploadCosKey                  @"ugc_upload"

#define VIRTUAL_TOTAL_PERCENT               10

// slice constant
#define SLICE_SIZE_MIN                      1024 * 1024
#define SLICE_SIZE_MAX                      1024 * 1024 * 10
#define SLICE_SIZE_ADAPTATION               0

@interface TVCClient () <QCloudSignatureProvider, NSURLSessionTaskDelegate>
@property (nonatomic, strong) TVCConfig *config;
@property (nonatomic, strong) QCloudAuthentationV5Creator *creator;
@property (nonatomic, strong) NSString *reqKey;
@property(nonatomic, strong) NSString* uploadKey;
@property (nonatomic, strong) NSString *serverIP;
@property (nonatomic, strong) QCloudCOSXMLUploadObjectRequest *uploadRequest;
// 上传节点信息
@property (nonatomic, strong) TVCUploadContext *uploadContext;
@property (nonatomic, strong) TVCReportInfo *reportInfo;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, weak) NSTimer *timer;
@property (atomic, assign) int virtualPercent;
@property (atomic, assign) BOOL realProgressFired;
@property(nonatomic, strong) NSString* saveVodSessionKey;
@property(nonatomic, strong) TVCUploadContext *savaUploadContext;
@property(nonatomic, strong) NSString *cosVideoPath;
// 当前上传续点视频文件的最后修改时间
@property(atomic,assign) uint64_t videoLastModTime;
// 当前上传续点视频封面文件的最后修改时间
@property(atomic,assign) uint64_t coverLastModTime;
@property(atomic, assign) BOOL cancelFlag;
@end

@implementation TVCClient

- (void)dealloc {
    VodLogInfo(@"dealloc TVCClient");
}

- (instancetype)initWithConfig:(TVCConfig *)config {
    self = [super init];
    if (self) {
        self.config = config;
        self.reqKey = @"";
        self.uploadKey = @"";
        self.serverIP = @"";
        self.reportInfo = [[TVCReportInfo alloc] init];
        self.timer = nil;
        self.virtualPercent = 0;
        self.realProgressFired = NO;
        self.videoLastModTime = 0;
        self.coverLastModTime = 0;
        self.cancelFlag = NO;
        // sdk最小1M,最大10M，如果不设置，置为0，则为文件大小的十分之一
        if (config.sliceSize == 0) {
            self.config.sliceSize = SLICE_SIZE_ADAPTATION;
        } else {
            self.config.sliceSize = [self fixSliceSize:config.sliceSize];
        }
    }
    return self;
}

- (void)updateConfig:(TVCConfig *)config {
    self.config = config;
    // sdk最小1M,最大10M，如果不设置，置为0，则为文件大小的十分之一
    if (config.sliceSize == 0) {
        self.config.sliceSize = SLICE_SIZE_ADAPTATION;
    } else {
        self.config.sliceSize = [self fixSliceSize:config.sliceSize];
    }
}

- (long)fixSliceSize:(long)sliceSize {
    if (sliceSize < SLICE_SIZE_MIN) {
        sliceSize = SLICE_SIZE_MIN;
    } else if (sliceSize > SLICE_SIZE_MAX) {
        sliceSize = SLICE_SIZE_MAX;
    }
    return sliceSize;
}

- (void)uploadVideo:(TVCUploadParam *)param result:(TVCResultBlock)result progress:(TVCProgressBlock)progress {
    VodLogInfo(@"start tvcClient uploadVideo");
    TVCUploadResponse *rsp = nil;
    // reset
    self.cosVideoPath = nil;
    self.cancelFlag = NO;
    // check config
    rsp = [self checkConfig:self.config];
    if (rsp.retCode != TVC_OK) {
        dispatch_async(dispatch_get_main_queue(), ^{
            result(rsp);
        });
        return;
    }
    // check param
    rsp = [self checkParam:param];
    if (rsp.retCode != TVC_OK) {
        dispatch_async(dispatch_get_main_queue(), ^{
            result(rsp);
        });
        return;
    }

    // init upload context;
    TVCUploadContext *uploadContext = [[TVCUploadContext alloc] init];
    self.uploadContext = uploadContext;
    uploadContext.uploadParam = param;
    uploadContext.resultBlock = result;
    uploadContext.progressBlock = progress;
    if (param.videoPath.length > 0) {
        uploadContext.isUploadVideo = YES;
    }
    if (param.coverPath.length > 0) {
        uploadContext.isUploadCover = YES;
    }

    // get file information
    unsigned long long fileSize = 0;
    unsigned long long coverSize = 0;
    unsigned long long fileLastModTime = 0;
    NSFileManager *manager = [NSFileManager defaultManager];
    long long reqTime = [[NSDate date] timeIntervalSince1970] * 1000;
    if ([manager fileExistsAtPath:param.videoPath]) {
        fileSize = [[manager attributesOfItemAtPath:param.videoPath error:nil] fileSize];
        if(fileSize > 0) {
            fileLastModTime = [[[manager attributesOfItemAtPath:param.videoPath error:nil] fileModificationDate] timeIntervalSince1970];
            uploadContext.videoSize = fileSize;
            uploadContext.videoLastModTime = fileLastModTime;

            if (uploadContext.isUploadCover) {
                if ([manager fileExistsAtPath:param.coverPath]) {
                    coverSize = [[manager attributesOfItemAtPath:param.coverPath error:nil] fileSize];
                    uploadContext.coverSize = coverSize;
                    uploadContext.coverLastModTime = [[[manager attributesOfItemAtPath:param.coverPath
                                                                                 error:nil] fileModificationDate] timeIntervalSince1970];
                } else {
                    [self txReport:TVC_UPLOAD_EVENT_ID_INIT errCode:TVC_ERR_FILE_NOT_EXIST vodErrCode:0 cosErrCode:@"" errInfo:@"coverPath is not exist"
                                    reqTime:reqTime
                                reqTimeCost:0
                                     reqKey:@""
                                      appId:0
                                   fileSize:0
                                   fileType:[self getFileType:param.coverPath]
                                   fileName:[self getFileName:param.coverPath]
                                 sessionKey:@""
                                     fileId:@""
                                  cosRegion:@""
                                  useCosAcc:0
                               cosRequestId:@""
                         cosTcpConnTimeCost:0
                        cosRecvRespTimeCost:0];
                    VodLogWarning(@"coverPath is not exist");
                    TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
                    rsp.retCode = TVC_ERR_FILE_NOT_EXIST;
                    rsp.descMsg = @"coverPath is not exist";
                    dispatch_async(dispatch_get_main_queue(), ^{
                        result(rsp);
                    });
                    return;
                }
            }
        } else{
            [self notifyEmptyFileError:reqTime withParams:param result:result];
            return;
        }
    } else {
        [self notifyEmptyFileError:reqTime withParams:param result:result];
        return;
    }

    VodLogInfo(@"start pick resume session");
    // 1.获取cos参数
    NSString *vodSessionKey = nil;
    if ([[TXUGCPublishOptCenter shareInstance] isPublishingPublishing:param.videoPath] == NO && self.config.enableResume == YES) {
        vodSessionKey = [self getSessionFromFilepath:uploadContext];
    }
    [[TXUGCPublishOptCenter shareInstance] addPublishing:param.videoPath];
    [self applyUploadUGC:uploadContext withVodSessionKey:vodSessionKey];
}

- (BOOL)cancleUploadVideo {
    VodLogInfo(@"call cancelUploadVideo");
    self.cancelFlag = YES;
    if (self.uploadRequest) {
        NSError *error;
        NSData* resumeData = [self.uploadRequest cancelByProductingResumeData:&error];
        if (error) {
            return NO;
        } else {
            [self setSession:self.uploadContext.cugResult.uploadSession resumeData:resumeData lastModTime:self.uploadContext.videoLastModTime
                coverLastModTime:self.uploadContext.coverLastModTime
                    withFilePath:self.uploadContext.uploadParam.videoPath];
            return YES;
        }
    }
    return NO;
}

- (void)notifyEmptyFileError:(long long)reqTime withParams:(TVCUploadParam *)param result:(TVCResultBlock)result {
    [self txReport:TVC_UPLOAD_EVENT_ID_INIT errCode:TVC_ERR_FILE_NOT_EXIST vodErrCode:0 cosErrCode:@"" errInfo:@"videoPath is not exist"
                    reqTime:reqTime
                reqTimeCost:0
                     reqKey:@""
                      appId:0
                   fileSize:0
                   fileType:[self getFileType:param.videoPath]
                   fileName:[self getFileName:param.videoPath]
                 sessionKey:@""
                     fileId:@""
                  cosRegion:@""
                  useCosAcc:0
               cosRequestId:@""
         cosTcpConnTimeCost:0
        cosRecvRespTimeCost:0];
    VodLogError(@"videoPath is not exist");
    TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
    rsp.retCode = TVC_ERR_FILE_NOT_EXIST;
    rsp.descMsg = @"videoPath is not exist";
    dispatch_async(dispatch_get_main_queue(), ^{
        result(rsp);
    });
}

+ (NSString *)getVersion {
    return TVCVersion;
}

#pragma mark - InnerMethod

- (TVCUploadResponse *)checkConfig:(TVCConfig *)config {
    TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
    rsp.retCode = TVC_OK;
    //    if(config.secretId.length <= 0){
    //        rsp.retCode = TVC_ERR_UGC_REQUEST_FAILED;
    //        rsp.descMsg = @"secretId should not be empty";
    //    }
    if (config.signature.length <= 0) {
        rsp.retCode = TVC_ERR_INVALID_SIGNATURE;
        rsp.descMsg = @"signature should not be empty";
    }
    return rsp;
}

- (TVCUploadResponse *)checkParam:(TVCUploadParam *)param {
    TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
    rsp.retCode = TVC_OK;
    if (param.videoPath.length <= 0) {
        rsp.retCode = TVC_ERR_INVALID_VIDEOPATH;
        rsp.descMsg = @"video path should not be empty";
    }

    if (param.videoName.length <= 0) {
        param.videoName = [self getFileName:param.videoPath];
    }
    return rsp;
}

- (NSMutableURLRequest *)getCosInitURLRequest:(NSString *)domain
                                  withContext:(TVCUploadContext *)uploadContext
                            withVodSessionKey:(NSString *)vodSessionKey {
    TVCUploadParam *param = uploadContext.uploadParam;
    // set body
    NSMutableDictionary *dictParam = [[NSMutableDictionary alloc] init];
    [dictParam setValue:self.config.signature forKey:@"signature"];

    // 有vodSessionKey的话表示是断点续传
    if (vodSessionKey && vodSessionKey.length) {
        [dictParam setValue:vodSessionKey forKey:@"vodSessionKey"];
    }

    [dictParam setValue:param.videoName forKey:@"videoName"];
    [dictParam setValue:[self getFileType:param.videoPath] forKey:@"videoType"];
    [dictParam setValue:@(uploadContext.videoSize) forKey:@"videoSize"];
    if (uploadContext.isUploadCover) {
        [dictParam setValue:[self getFileName:param.coverPath] forKey:@"coverName"];
        [dictParam setValue:[self getFileType:param.coverPath] forKey:@"coverType"];
        [dictParam setValue:@(uploadContext.coverSize) forKey:@"coverSize"];
    }

    [dictParam setValue:self.config.userID forKey:@"clientReportId"];
    [dictParam setValue:TVCVersion forKey:@"clientVersion"];
    NSString *region = [[TXUGCPublishOptCenter shareInstance] getCosRegion];
    if ([region length] > 0) {
        [dictParam setValue:region forKey:@"storageRegion"];
    }

    NSError *error = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:dictParam options:0 error:&error];
    if (error) {
        return nil;
    }

    NSString *host = domain;
    NSArray *ipLists = [[TXUGCPublishOptCenter shareInstance] query:host];
    NSString *ip = ([ipLists count] > 0 ? ipLists[0] : nil);
    if (ip != nil) {
        host = ip;
        self.serverIP = ip;
    } else {
        [self queryIpWithDomain:host];
    }
    VodLogInfo(@"domain %@ use ip:%@",domain, host);
    // set url
    NSString *baseUrl = [[@"https://" stringByAppendingString:host] stringByAppendingString:@"/v3/index.php?Action=ApplyUploadUGC"];

    // create request
    NSURL *url = [NSURL URLWithString:baseUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[NSString stringWithFormat:@"%ld", (long)[bodyData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:UGC_HOST forHTTPHeaderField:@"host"];
    if (ip != nil) {
        [request addValue:[[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding] forHTTPHeaderField:@"originalBody"];
    } else {
        [request setHTTPBody:bodyData];
    }

    VodLogInfo(@"cos begin req : %s", [baseUrl UTF8String]);

    return request;
}

- (NSMutableURLRequest *)getCosEndURLRequest:(NSString *)domain withContext:(TVCUploadContext *)uploadContext {
    NSString *baseUrl;
    TVCUploadParam *param = uploadContext.uploadParam;
    TVCUGCResult *ugc = uploadContext.cugResult;

    // set body
    NSMutableDictionary *dictParam = [[NSMutableDictionary alloc] init];
    [dictParam setValue:self.config.signature forKey:@"signature"];
    [dictParam setValue:ugc.uploadSession forKey:@"vodSessionKey"];
    NSError *error = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:dictParam options:0 error:&error];
    if (error) {
        return nil;
    }

    // create request
    NSString *host = domain;
    NSArray *ipLists = [[TXUGCPublishOptCenter shareInstance] query:host];
    NSString *ip = ([ipLists count] > 0 ? ipLists[0] : nil);
    if (ip != nil) {
        host = ip;
        self.serverIP = ip;
    } else {
        [self queryIpWithDomain:host];
    }

    baseUrl = [NSString stringWithFormat:@"https://%@/v3/index.php?Action=CommitUploadUGC", host];
    baseUrl = [baseUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"#%^{}\"[]|\\<> "].invertedSet];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:baseUrl]];
    [request setValue:[NSString stringWithFormat:@"%ld", (long)[bodyData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];

    if (ip != nil) {
        [request addValue:[[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding] forHTTPHeaderField:@"originalBody"];
    } else {
        [request setHTTPBody:bodyData];
    }

    [request setValue:ugc.domain forHTTPHeaderField:@"host"];

    VodLogInfo(@"cos end req : %s", [baseUrl UTF8String]);

    return request;
}

// 去点播申请上传：获取 COS 上传信息
- (void)applyUploadUGC:(TVCUploadContext *)uploadContext withVodSessionKey:(NSString *)vodSessionKey {
    VodLogInfo(@"start applyUploadUGC");
    self.saveVodSessionKey = vodSessionKey;
    self.savaUploadContext = uploadContext;
    if (self.timer == nil) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:uploadContext forKey:@"uploadContext"];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0f / VIRTUAL_TOTAL_PERCENT target:self selector:@selector(postVirtualProgress:)
                                                        userInfo:dict
                                                         repeats:YES];
        });
    }

    uploadContext.reqTime = [[NSDate date] timeIntervalSince1970] * 1000;
    uploadContext.initReqTime = uploadContext.reqTime;
    self.reqKey = [NSString stringWithFormat:@"%lld;%lld", uploadContext.videoLastModTime, uploadContext.initReqTime];
    self.uploadKey = [NSString stringWithFormat:@"%lld_%lld_%i", uploadContext.videoLastModTime, uploadContext.initReqTime * 1000,arc4random()];
    
    NSURLSessionConfiguration *initCfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    [initCfg setRequestCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    if (self.config.timeoutInterval > 0) {
        [initCfg setTimeoutIntervalForRequest:self.config.timeoutInterval];
    } else {
        [initCfg setTimeoutIntervalForRequest:kTimeoutInterval];
    }
    NSArray *protocolArray = @[[TVCHttpMessageURLProtocol class]];
    initCfg.protocolClasses = protocolArray;
    self.session = [NSURLSession sessionWithConfiguration:initCfg delegate:self delegateQueue:nil];

    [self getCosInitParam:uploadContext withVodSessionKey:vodSessionKey withDomain:UGC_HOST];
}

- (void)getCosInitParam:(TVCUploadContext *)uploadContext withVodSessionKey:(NSString *)vodSessionKey withDomain:(NSString *)domain {
    VodLogInfo(@"start getCosInitParam");
    TVCResultBlock result = uploadContext.resultBlock;
    NSMutableURLRequest *cosRequest = [self getCosInitURLRequest:domain withContext:uploadContext withVodSessionKey:vodSessionKey];
    if (cosRequest == nil) {
        [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];
        if (uploadContext.resultBlock) {
            TVCUploadResponse *initResp = [[TVCUploadResponse alloc] init];
            initResp.retCode = TVC_ERR_UGC_REQUEST_FAILED;
            initResp.descMsg = @"create ugc publish request failed";
            [self notifyResult:result resp:initResp];
            return;
        }
    }

    __weak TVCClient *ws = self;
    NSURLSessionTask *initTask =
        [self.session dataTaskWithRequest:cosRequest
                        completionHandler:^(NSData *_Nullable initData, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                            if (error || httpResponse.statusCode != 200 || initData == nil) {  // 失败
                                if ([domain isEqualToString:UGC_HOST]) {                       // 原域名
                                    if (++uploadContext.vodCmdRequestCount < kMaxRequestCount) {
                                        [ws getCosInitParam:uploadContext withVodSessionKey:vodSessionKey withDomain:UGC_HOST];
                                    } else {
                                        uploadContext.vodCmdRequestCount = 0;
                                        uploadContext.mainVodServerErrMsg = [NSString stringWithFormat:@"main vod fail code:%ld", (long)error.code];
                                        [ws getCosInitParam:uploadContext withVodSessionKey:vodSessionKey withDomain:UGC_HOST_BAK];
                                    }
                                } else if ([domain isEqualToString:UGC_HOST_BAK]) {  // 备份域名
                                    if (++uploadContext.vodCmdRequestCount < kMaxRequestCount) {
                                        [ws getCosInitParam:uploadContext withVodSessionKey:vodSessionKey withDomain:UGC_HOST_BAK];
                                    } else {
                                        // 删除session
                                        [ws setSession:nil resumeData:nil lastModTime:0 withFilePath:uploadContext.uploadParam.videoPath];
                                        [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];

                                        TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
                                        // 1步骤出错
                                        VodLogError(@"ugc init http req fail : error=%ld response=%s", (long)error.code, [httpResponse.description UTF8String]);
                                        rsp.retCode = TVC_ERR_UGC_REQUEST_FAILED;
                                        rsp.descMsg = [NSString stringWithFormat:@"ugc code:%ld, ugc desc:%@", (long)error.code, @"ugc init http req fail"];

                                        if (uploadContext.mainVodServerErrMsg != nil && uploadContext.mainVodServerErrMsg.length > 0) {
                                            rsp.descMsg = [NSString stringWithFormat:@"%@|%@", rsp.descMsg, uploadContext.mainVodServerErrMsg];
                                        }

                                        unsigned long long reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
                                        [ws txReport:TVC_UPLOAD_EVENT_ID_INIT errCode:rsp.retCode vodErrCode:error.code cosErrCode:@""
                                                        errInfo:rsp.descMsg
                                                        reqTime:uploadContext.reqTime
                                                    reqTimeCost:reqTimeCost
                                                         reqKey:ws.reqKey
                                                          appId:0
                                                       fileSize:uploadContext.videoSize
                                                       fileType:[ws getFileType:uploadContext.uploadParam.videoPath]
                                                       fileName:[ws getFileName:uploadContext.uploadParam.videoPath]
                                                     sessionKey:@""
                                                         fileId:@""
                                                      cosRegion:@""
                                                      useCosAcc:0
                                                   cosRequestId:@""
                                             cosTcpConnTimeCost:0
                                            cosRecvRespTimeCost:0];
                                        if (result) {
                                            [ws notifyResult:result resp:rsp];
                                        }
                                        return;
                                    }
                                }
                                return;
                            }

                            uploadContext.vodCmdRequestCount = 0;
                            uploadContext.mainVodServerErrMsg = @"";
                            [ws parseInitRsp:initData withContex:uploadContext withVodSessionKey:vodSessionKey];
                        }];
    [initTask resume];
}

- (void)parseInitRsp:(NSData *)initData withContex:(TVCUploadContext *)uploadContext withVodSessionKey:(NSString *)vodSessionKey {
    VodLogInfo(@"start parseInitRsp:%@", initData);
    if(self.cancelFlag) {
        self.cancelFlag = NO;
        VodLogWarning(@"upload cancel when parseInitRsp");
        [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];
        TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
        rsp.retCode = TVC_ERR_USER_CANCLE;
        rsp.descMsg = [NSString stringWithFormat:@"upload video, user cancled"];
        [self notifyResult:uploadContext.resultBlock resp:rsp];
        return;
    }
    TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
    TVCResultBlock result = uploadContext.resultBlock;
    unsigned long long reqTimeCost = 0;
    NSError *jsonErr = nil;
    NSDictionary *initDict = [NSJSONSerialization JSONObjectWithData:initData options:NSJSONReadingAllowFragments error:&jsonErr];
    if (jsonErr || ![initDict isKindOfClass:[NSDictionary class]]) {
        // 删除session
        [self setSession:nil resumeData:nil lastModTime:0 withFilePath:uploadContext.uploadParam.videoPath];
        [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];

        rsp.retCode = TVC_ERR_UGC_PARSE_FAILED;
        rsp.descMsg = [NSString stringWithFormat:@"ugc code:%ld, ugc desc:%@", jsonErr.code, @"ugc parse init http fail"];

        reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
        [self txReport:TVC_UPLOAD_EVENT_ID_INIT errCode:rsp.retCode vodErrCode:jsonErr.code cosErrCode:@"" errInfo:rsp.descMsg
                        reqTime:uploadContext.reqTime
                    reqTimeCost:reqTimeCost
                         reqKey:self.reqKey
                          appId:0
                       fileSize:uploadContext.videoSize
                       fileType:[self getFileType:uploadContext.uploadParam.videoPath]
                       fileName:[self getFileName:uploadContext.uploadParam.videoPath]
                     sessionKey:@""
                         fileId:@""
                      cosRegion:@""
                      useCosAcc:0
                   cosRequestId:@""
             cosTcpConnTimeCost:0
            cosRecvRespTimeCost:0];

        if (result) {
            [self notifyResult:result resp:rsp];
        }
        return;
    }

    int code = -1;
    if ([[initDict objectForKey:kCode] isKindOfClass:[NSNumber class]]) {
        code = [[initDict objectForKey:kCode] intValue];
    }
    NSString *msg;
    
    if ([[initDict objectForKey:kMessage] isKindOfClass:[NSString class]]) {
        msg = [initDict objectForKey:kMessage];
    }

    if (code != TVC_OK) {
        // 签名过期不上报
        if(code == 10010) {
            rsp.retCode = TVC_ERR_UPLOAD_SIGN_EXPIRED;
        } else {
            rsp.retCode = TVC_ERR_UGC_PARSE_FAILED;

            reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
            [self txReport:TVC_UPLOAD_EVENT_ID_INIT errCode:rsp.retCode vodErrCode:code cosErrCode:@"" errInfo:rsp.descMsg reqTime:uploadContext.reqTime
                        reqTimeCost:reqTimeCost
                             reqKey:self.reqKey
                              appId:0
                           fileSize:uploadContext.videoSize
                           fileType:[self getFileType:uploadContext.uploadParam.videoPath]
                           fileName:[self getFileName:uploadContext.uploadParam.videoPath]
                         sessionKey:@""
                             fileId:@""
                          cosRegion:@""
                          useCosAcc:0
                       cosRequestId:@""
                 cosTcpConnTimeCost:0
                cosRecvRespTimeCost:0];
        }
        rsp.descMsg = [NSString stringWithFormat:@"ugc code:%d, ugc desc:%@", code, msg];
        // 删除session
        [self setSession:nil resumeData:nil lastModTime:0 withFilePath:uploadContext.uploadParam.videoPath];
        [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];

        // 1步骤出错
        if (result) {
            [self notifyResult:result resp:rsp];
        }
        return;
    }

    NSDictionary *dataDict = nil;
    if ([[initDict objectForKey:kData] isKindOfClass:[NSDictionary class]]) {
        dataDict = [initDict objectForKey:kData];
    }
    if (!dataDict) {
        // 删除session
        [self setSession:nil resumeData:nil lastModTime:0 withFilePath:uploadContext.uploadParam.videoPath];
        [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];

        rsp.retCode = TVC_ERR_UGC_PARSE_FAILED;
        rsp.descMsg = @"data is not json string";

        reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
        [self txReport:TVC_UPLOAD_EVENT_ID_INIT errCode:rsp.retCode vodErrCode:3 cosErrCode:@"" errInfo:rsp.descMsg reqTime:uploadContext.reqTime
                    reqTimeCost:reqTimeCost
                         reqKey:self.reqKey
                          appId:0
                       fileSize:uploadContext.videoSize
                       fileType:[self getFileType:uploadContext.uploadParam.videoPath]
                       fileName:[self getFileName:uploadContext.uploadParam.videoPath]
                     sessionKey:@""
                         fileId:@""
                      cosRegion:@""
                      useCosAcc:0
                   cosRequestId:@""
             cosTcpConnTimeCost:0
            cosRecvRespTimeCost:0];

        if (result) {
            [self notifyResult:result resp:rsp];
        }
        return;
    }

    // print json log
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:initDict options:NSJSONWritingPrettyPrinted error:&parseError];
    NSString *initDictStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    VodLogInfo(@"init cos dic : %s", [initDictStr UTF8String]);

    TVCUGCResult *ugc = [[TVCUGCResult alloc] init];

    if ([[dataDict objectForKey:@"video"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *videoDict = [dataDict objectForKey:@"video"];
        ugc.videoSign = [videoDict objectForKey:@"storageSignature"];
        ugc.videoPath = [videoDict objectForKey:@"storagePath"];
    }

    if ([[dataDict objectForKey:@"cover"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *coverDict = [dataDict objectForKey:@"cover"];
        ugc.imageSign = [coverDict objectForKey:@"storageSignature"];
        ugc.imagePath = [coverDict objectForKey:@"storagePath"];
    }

    if ([[dataDict objectForKey:@"appId"] isKindOfClass:[NSNumber class]]) {
        ugc.userAppid = [[dataDict objectForKey:@"appId"] stringValue];
    }

    if ([[dataDict objectForKey:@"tempCertificate"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *cosTmp = [dataDict objectForKey:@"tempCertificate"];
        ugc.tmpSecretId = [cosTmp objectForKey:@"secretId"];
        ugc.tmpSecretKey = [cosTmp objectForKey:@"secretKey"];
        ugc.tmpToken = [cosTmp objectForKey:@"token"];
        ugc.tmpExpiredTime = [[cosTmp objectForKey:@"expiredTime"] longLongValue];
    }
    if ([[dataDict objectForKey:@"timestamp"] isKindOfClass:[NSNumber class]]) {
        ugc.currentTS = [[dataDict objectForKey:@"timestamp"] longLongValue];
    }

    if ([[dataDict objectForKey:@"storageAppId"] isKindOfClass:[NSNumber class]]) {
        ugc.uploadAppid = [[dataDict objectForKey:@"storageAppId"] stringValue];
    }
    if ([[dataDict objectForKey:@"storageBucket"] isKindOfClass:[NSString class]]) {
        //从5.4.10升级到5.4.20之后，废除了setAppIdAndRegion接口，需要自行拼接保证costBucket格式为 bucket-appId
        ugc.uploadBucket = [NSString stringWithFormat:@"%@-%@", [dataDict objectForKey:@"storageBucket"], ugc.uploadAppid];
    }
    if ([[dataDict objectForKey:@"vodSessionKey"] isKindOfClass:[NSString class]]) {
        ugc.uploadSession = [dataDict objectForKey:@"vodSessionKey"];
    }
    if ([[dataDict objectForKey:@"storageRegionV5"] isKindOfClass:[NSString class]]) {
        ugc.uploadRegion = [dataDict objectForKey:@"storageRegionV5"];
    }
    if ([[dataDict objectForKey:@"domain"] isKindOfClass:[NSString class]]) {
        ugc.domain = [dataDict objectForKey:@"domain"];
    }
    if ([[dataDict objectForKey:@"cosAcc"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *cosAcc = [dataDict objectForKey:@"cosAcc"];
        ugc.useCosAcc = [[cosAcc objectForKey:@"isOpen"] intValue];
        ugc.cosAccDomain = [cosAcc objectForKey:@"domain"];
    }

    self.cosVideoPath = ugc.videoPath;
    uploadContext.cugResult = ugc;

    VodLogInfo(@"init cugResult %s", [[uploadContext.cugResult description] UTF8String]);

    reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
    [self txReport:TVC_UPLOAD_EVENT_ID_INIT errCode:TVC_OK vodErrCode:0 cosErrCode:@"" errInfo:@"" reqTime:uploadContext.reqTime
                reqTimeCost:reqTimeCost
                     reqKey:self.reqKey
                      appId:ugc.userAppid
                   fileSize:uploadContext.videoSize
                   fileType:[self getFileType:uploadContext.uploadParam.videoPath]
                   fileName:[self getFileName:uploadContext.uploadParam.videoPath]
                 sessionKey:ugc.uploadSession
                     fileId:@""
                  cosRegion:ugc.uploadRegion
                  useCosAcc:ugc.useCosAcc
               cosRequestId:@""
         cosTcpConnTimeCost:0
        cosRecvRespTimeCost:0];

    [self setupCOSXMLShareService:uploadContext];

    // 2.开始上传
    uploadContext.reqTime = [[NSDate date] timeIntervalSince1970] * 1000;
    if ([self.config.uploadResumController isResumeUploadVideo:uploadContext
                                                withSessionKey:vodSessionKey withFileModTime:self.videoLastModTime
                                              withCoverModTime:self.coverLastModTime]) {
        [self commitCosUpload:uploadContext withResumeUpload:YES];
    } else {
        [self commitCosUpload:uploadContext withResumeUpload:NO];
    }
}

- (void)signatureWithFields:(QCloudSignatureFields *)fileds
                    request:(QCloudBizHTTPRequest *)request
                 urlRequest:(NSMutableURLRequest *)urlRequst
                  compelete:(QCloudHTTPAuthentationContinueBlock)continueBlock {
    QCloudSignature *signature = nil;
    if (_creator != nil) {
        signature = [_creator signatureForData:urlRequst];
    }
    continueBlock(signature, nil);
}

- (void)setupCOSXMLShareService:(TVCUploadContext *)uploadContext {
    QCloudCredential *credential = [QCloudCredential new];
    credential.secretID = uploadContext.cugResult.tmpSecretId;
    credential.secretKey = uploadContext.cugResult.tmpSecretKey;
    credential.token = uploadContext.cugResult.tmpToken;
    long long nowTime = [[NSDate date] timeIntervalSince1970];
    long long serverTS = uploadContext.cugResult.currentTS;
    //如果本地时间戳跟后台返回的当前时间戳相差太大，就用后台返回的时间戳。避免本地时间错误导致403
    if (serverTS != 0 && nowTime - serverTS > 10 * 60) {
        credential.startDate = [NSDate dateWithTimeIntervalSince1970:serverTS];
    }
    credential.expirationDate = [NSDate dateWithTimeIntervalSince1970:uploadContext.cugResult.tmpExpiredTime];
    _creator = [[QCloudAuthentationV5Creator alloc] initWithCredential:credential];

    QCloudServiceConfiguration *configuration = [QCloudServiceConfiguration new];
    
    /**
      判断上传的region和竞速出来的region是否一致，用来打开quic的开关
    */
    [QCloudQuicConfig shareConfig].total_timeout_millisec_ = UPLOAD_TIME_OUT_SEC * 1000;
    if([[TXUGCPublishOptCenter shareInstance] isNeedEnableQuic:uploadContext.cugResult.uploadRegion]){
        configuration.enableQuic = true;
        [QCloudQuicConfig shareConfig].race_type = QCloudRaceTypeOnlyQUIC;
        [QCloudQuicConfig shareConfig].is_custom = NO;
        [QCloudQuicConfig shareConfig].port = 443;
    }else{
        configuration.enableQuic = false;
        [QCloudQuicConfig shareConfig].port = 80;
        [QCloudQuicConfig shareConfig].race_type = QCloudRaceTypeOnlyHTTP;
    }
    uploadContext.isQuic = configuration.enableQuic;

    VodLogInfo(@"doamin:%@,isQuic:%d", uploadContext.cugResult.uploadRegion, configuration.enableQuic);

    configuration.appID = uploadContext.cugResult.uploadAppid;
    configuration.signatureProvider = self;
    configuration.timeoutInterval = UPLOAD_TIME_OUT_SEC;

    QCloudCOSXMLEndPoint *endpoint;
    // 是否开启动态加速
    if (uploadContext.cugResult.useCosAcc == 1) {
        NSString *accDomain = uploadContext.cugResult.cosAccDomain;
        NSString *accUrl = accDomain;
        if (![accUrl hasPrefix:@"http"]) {
            if (self.config.enableHttps) {
                accUrl = [@"https://" stringByAppendingString:accDomain];
            } else {
                accUrl = [@"http://" stringByAppendingString:accDomain];
            }
        }
        endpoint = [[QCloudCOSXMLEndPoint alloc] initWithLiteralURL:[NSURL URLWithString:accUrl]];
        endpoint.regionName = uploadContext.cugResult.uploadRegion;
        [self queryIpWithDomain:accUrl];
    } else {
        endpoint = [[QCloudCOSXMLEndPoint alloc] init];
        endpoint.regionName = uploadContext.cugResult.uploadRegion;
        NSString *reqHost = [endpoint serverURLWithBucket:uploadContext.cugResult.uploadBucket appID:uploadContext.cugResult.uploadAppid
                                               regionName:uploadContext.cugResult.uploadRegion]
            .host;
        [self queryIpWithDomain:reqHost];
        NSArray *ipList = [[TXUGCPublishOptCenter shareInstance] query:reqHost];
        NSString *ip = nil;
        if (ipList && ipList.count > 0) {
            ip = ipList[0];
        }
        if (ip) {
            [[QCloudHttpDNS shareDNS] setIp:ip forDomain:reqHost];
        }
    }
    
    endpoint.useHTTPS = self.config.enableHttps;
    configuration.endpoint = endpoint;
    if(self.config.concurrentCount > 0) {
        [QCloudHTTPSessionManager shareClient].maxConcurrentCountLimit = self.config.concurrentCount;
    } else {
        // default max concurrent count is 4
        [QCloudHTTPSessionManager shareClient].maxConcurrentCountLimit = 4;
    }
    
    if(![QCloudCOSXMLService hasCosxmlServiceForKey:self.uploadKey]){
        [QCloudCOSXMLService registerCOSXMLWithConfiguration:configuration withKey:self.uploadKey];
        [QCloudCOSTransferMangerService registerCOSTransferMangerWithConfiguration:configuration withKey:self.uploadKey];
    }
}

- (long)getSliceSize:(uint64_t)videoSize {
    long sliceSize = self.config.sliceSize;
    if (sliceSize == SLICE_SIZE_ADAPTATION) {
         if (videoSize > 0) {
             sliceSize = [self fixSliceSize:videoSize / 10];
         } else {
             VodLogInfo(@"file size invalid,set sliceSize to SLICE_SIZE_MIN");
             sliceSize = SLICE_SIZE_MIN;
         }
     }
     return sliceSize;
}

- (void)commitCosUpload:(TVCUploadContext *)uploadContext withResumeUpload:(BOOL)isResumeUpload {
    VodLogInfo(@"start commitCosUpload");
    dispatch_group_t group = dispatch_group_create();
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    uploadContext.gcdGroup = group;
    uploadContext.gcdSem = semaphore;
    uploadContext.gcdQueue = queue;
    // 2-1.开始上传视频
    TVCUploadParam *param = uploadContext.uploadParam;
    TVCUGCResult *cug = uploadContext.cugResult;

    VodLogInfo(@"uploadCosVideo begin : cosBucket:%@ ,cos videoPath:%@, path:%@", cug.uploadBucket, cug.videoPath, param.videoPath);

    __block uint64_t tcpConenctionTimeCost = 0;
    __block uint64_t recvRspTimeCost = 0;
    __block long long reqTimeCost = 0;
    __weak TVCClient *ws = self;
    if (uploadContext.isUploadVideo) {
        dispatch_group_async(group, queue, ^{
            if(self.cancelFlag) {
                self.cancelFlag = NO;
                VodLogWarning(@"upload is cancel when ready to upload to cos");
                [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];
                TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
                rsp.retCode = TVC_ERR_USER_CANCLE;
                rsp.descMsg = [NSString stringWithFormat:@"upload video, user cancled"];
                [self notifyResult:uploadContext.resultBlock resp:rsp];
                return;
            }
            QCloudCOSXMLUploadObjectRequest *videoUpload;

            if (uploadContext.resumeData != nil && uploadContext.resumeData.length != 0) {
                videoUpload = [QCloudCOSXMLUploadObjectRequest requestWithRequestData:uploadContext.resumeData];
            } else {
                videoUpload = [QCloudCOSXMLUploadObjectRequest new];
                videoUpload.body = [NSURL fileURLWithPath:param.videoPath];
                videoUpload.bucket = cug.uploadBucket;
                videoUpload.object = cug.videoPath;
                videoUpload.sliceSize = [self getSliceSize:uploadContext.videoSize];

                [videoUpload setRequstsMetricArrayBlock:^(NSMutableArray *requstMetricArray) {
                    if ([requstMetricArray count] > 0 && [requstMetricArray[0] isKindOfClass:[NSDictionary class]]) {
                        if ([[requstMetricArray[0] allValues] count] > 0) {
                            NSDictionary *dic = [requstMetricArray[0] allValues][0];
                            tcpConenctionTimeCost = ([dic[@"kDnsLookupTookTime"] doubleValue] + [dic[@"kConnectTookTime"] doubleValue] +
                                                        [dic[@"kSignRequestTookTime"] doubleValue])
                                                    * 1000;
                            recvRspTimeCost = ([dic[@"kTaskTookTime"] doubleValue] + [dic[@"kReadResponseHeaderTookTime"] doubleValue] +
                                                  [dic[@"kReadResponseBodyTookTime"] doubleValue])
                                              * 1000;
                        }
                    }
                }];

                [videoUpload setInitMultipleUploadFinishBlock:^(
                    QCloudInitiateMultipartUploadResult *multipleUploadInitResult, QCloudCOSXMLUploadObjectResumeData resumeData) {
                    if (multipleUploadInitResult != nil && resumeData != nil) {
                        [self setSession:cug.uploadSession resumeData:resumeData lastModTime:uploadContext.videoLastModTime
                            coverLastModTime:uploadContext.coverLastModTime
                                withFilePath:param.videoPath];
                    }
                }];
            }

            [videoUpload setFinishBlock:^(QCloudUploadObjectResult *result, NSError *error) {
                VodLogInfo(@"uploadCosVideo finish : cosBucket:%@ ,cos videoPath:%@, path:%@, size:%lld", cug.uploadBucket, cug.videoPath, param.videoPath,
                    uploadContext.videoSize);
                reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
                
                [self handleUploadBlock:result withError:error withContext:uploadContext
                                withCug:cug withTcpTimeOut:tcpConenctionTimeCost withRspTime:recvRspTimeCost];
            }];

            TVCProgressBlock progress = uploadContext.progressBlock;
            [videoUpload setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
                if (!ws.realProgressFired) {
                    [ws.timer setFireDate:[NSDate distantFuture]];
                    ws.realProgressFired = YES;
                }

                if (progress) {
                    uint64_t total = uploadContext.videoSize + uploadContext.coverSize;
                    uploadContext.currentUpload = totalBytesSent;
                    if (uploadContext.currentUpload > total) {
                        uploadContext.currentUpload = total;
                        ws.virtualPercent = 100 - VIRTUAL_TOTAL_PERCENT;
                        [ws.timer setFireDate:[NSDate date]];  //上传完成，启动结束虚拟进度
                    } else {
                        progress(uploadContext.currentUpload * (100 - 2 * VIRTUAL_TOTAL_PERCENT) / 100 + VIRTUAL_TOTAL_PERCENT * total / 100, total);
                    }
                }
            }];
            ws.uploadRequest = videoUpload;
            [[QCloudCOSTransferMangerService costransfermangerServiceForKey:self.uploadKey] UploadObject:videoUpload];
        });
    }

    [self notifyCosUploadEnd:uploadContext];
}

- (void)handleUploadBlock:(QCloudUploadObjectResult *)result withError:(NSError *)error withContext:(TVCUploadContext *)uploadContext
                  withCug:(TVCUGCResult *)cug withTcpTimeOut:(uint64_t)tcpConenctionTimeCost withRspTime:(uint64_t)recvRspTimeCost {
    __weak TVCClient *ws = self;
    NSString *requestId = [result.__originHTTPURLResponse__.allHeaderFields objectForKey:@"x-cos-request-id"];
    __block uint64_t reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
    TVCUploadParam *param = uploadContext.uploadParam;
    dispatch_semaphore_t semaphore = uploadContext.gcdSem;
    
    if (error) {
        BOOL isQuic = uploadContext.isQuic;
        NSString *errInfo = error.description;
        NSString *cosErrorCode = @"";
        if (error.userInfo != nil) {
            errInfo = error.userInfo.description;
        }
        errInfo = [NSString stringWithFormat:@"%@,isQuic:%@" ,errInfo ,isQuic ? @"true" : @"false"];
        cosErrorCode = [NSString stringWithFormat:@"%ld", (long)error.code];
        // 取消的情况不清除session缓存，错误码定义见 https://cloud.tencent.com/document/product/436/30443
        if (error.code == 30000) {
            uploadContext.lastStatus = TVC_ERR_USER_CANCLE;
            uploadContext.desc = [NSString stringWithFormat:@"upload video, user cancled"];

            [ws txReport:TVC_UPLOAD_EVENT_ID_COS errCode:TVC_ERR_USER_CANCLE vodErrCode:0 cosErrCode:cosErrorCode errInfo:errInfo
                            reqTime:uploadContext.reqTime
                        reqTimeCost:reqTimeCost
                             reqKey:ws.reqKey
                              appId:cug.userAppid
                           fileSize:uploadContext.videoSize
                           fileType:[ws getFileType:uploadContext.uploadParam.videoPath]
                           fileName:[ws getFileName:uploadContext.uploadParam.videoPath]
                         sessionKey:cug.uploadSession
                             fileId:@""
                          cosRegion:cug.uploadRegion
                          useCosAcc:cug.useCosAcc
                       cosRequestId:requestId
                 cosTcpConnTimeCost:tcpConenctionTimeCost
                cosRecvRespTimeCost:recvRspTimeCost];
        } else {
            int errorCode = TVC_ERR_VIDEO_UPLOAD_FAILED;
            uploadContext.lastStatus = TVC_ERR_VIDEO_UPLOAD_FAILED;
            uploadContext.desc = [NSString stringWithFormat:@"upload video, cos code:%ld, cos desc:%@", (long)error.code, error.description];
            //网络断开，不清除session缓存
            if (error.code != -1009 || isQuic) {
                [ws setSession:nil resumeData:nil lastModTime:0 withFilePath:param.videoPath];
            }
            if (isQuic) {
                /**
                 quic上传失败，使用http上传
                */
                VodLogWarning(@"quic request failed,trans to http");
                uploadContext.lastStatus = TVC_ERR_UPLOAD_QUIC_FAILED;
                errorCode = TVC_ERR_UPLOAD_QUIC_FAILED;
                [[TXUGCPublishOptCenter shareInstance] disableQuicIfNeed];
                [self applyUploadUGC:self.savaUploadContext withVodSessionKey:self.saveVodSessionKey];
            }

            [ws txReport:TVC_UPLOAD_EVENT_ID_COS errCode:errorCode vodErrCode:0 cosErrCode:cosErrorCode errInfo:errInfo
                            reqTime:uploadContext.reqTime
                        reqTimeCost:reqTimeCost
                             reqKey:ws.reqKey
                              appId:cug.userAppid
                           fileSize:uploadContext.videoSize
                           fileType:[ws getFileType:uploadContext.uploadParam.videoPath]
                           fileName:[ws getFileName:uploadContext.uploadParam.videoPath]
                         sessionKey:cug.uploadSession
                             fileId:@""
                          cosRegion:cug.uploadRegion
                          useCosAcc:cug.useCosAcc
                       cosRequestId:requestId
                 cosTcpConnTimeCost:tcpConenctionTimeCost
                cosRecvRespTimeCost:recvRspTimeCost];
        }
        dispatch_semaphore_signal(semaphore);
        if (uploadContext.isUploadCover) {
            dispatch_semaphore_signal(semaphore);
        }
    } else {
        uploadContext.lastStatus = TVC_OK;
        VodLogInfo(@"upload video succ");
        //视频上传完成，上报视频上传信息，清除session缓存
        [ws txReport:TVC_UPLOAD_EVENT_ID_COS errCode:0 vodErrCode:0 cosErrCode:@"" errInfo:@"" reqTime:uploadContext.reqTime
                    reqTimeCost:reqTimeCost
                         reqKey:ws.reqKey
                          appId:cug.userAppid
                       fileSize:uploadContext.videoSize
                       fileType:[ws getFileType:uploadContext.uploadParam.videoPath]
                       fileName:[ws getFileName:uploadContext.uploadParam.videoPath]
                     sessionKey:cug.uploadSession
                         fileId:@""
                      cosRegion:cug.uploadRegion
                      useCosAcc:cug.useCosAcc
                   cosRequestId:requestId
             cosTcpConnTimeCost:tcpConenctionTimeCost
            cosRecvRespTimeCost:recvRspTimeCost];
        [ws setSession:nil resumeData:nil lastModTime:0 withFilePath:param.videoPath];
        // 2-2.开始上传封面
        if (uploadContext.isUploadCover) {
            uploadContext.reqTime = [[NSDate date] timeIntervalSince1970] * 1000;

            QCloudCOSXMLUploadObjectRequest *coverUpload = [QCloudCOSXMLUploadObjectRequest new];
            coverUpload.body = [NSURL fileURLWithPath:param.coverPath];
            coverUpload.bucket = cug.uploadBucket;
            coverUpload.object = cug.imagePath;

            __block uint64_t tcpConenctionTimeCost = 0;
            __block uint64_t recvRspTimeCost = 0;

            [coverUpload setRequstsMetricArrayBlock:^(NSMutableArray *requstMetricArray) {
                if ([requstMetricArray count] > 0 && [requstMetricArray[0] isKindOfClass:[NSDictionary class]]) {
                    if ([[requstMetricArray[0] allValues] count] > 0) {
                        NSDictionary *dic = [requstMetricArray[0] allValues][0];
                        tcpConenctionTimeCost = ([dic[@"kDnsLookupTookTime"] doubleValue] + [dic[@"kConnectTookTime"] doubleValue] +
                                                    [dic[@"kSignRequestTookTime"] doubleValue])
                                                * 1000;
                        recvRspTimeCost = ([dic[@"kTaskTookTime"] doubleValue] + [dic[@"kReadResponseHeaderTookTime"] doubleValue] +
                                              [dic[@"kReadResponseBodyTookTime"] doubleValue])
                                          * 1000;
                    }
                }
            }];

            [coverUpload setFinishBlock:^(QCloudUploadObjectResult *result, NSError *error) {
                NSString *cosErrorCode = @"";
                NSString *requestId = [result.__originHTTPURLResponse__.allHeaderFields objectForKey:@"x-cos-request-id"];

                if (error) {
                    // 2-2步骤出错
                    VodLogError(@"upload cover fail : %ld", (long)error.code);
                    NSString *errInfo = error.description;
                    if (error.userInfo != nil) {
                        errInfo = error.userInfo.description;
                    }
                    cosErrorCode = [NSString stringWithFormat:@"%ld", (long)error.code];

                    if (error.code == 30000) {
                        uploadContext.lastStatus = TVC_ERR_USER_CANCLE;
                        uploadContext.desc = [NSString stringWithFormat:@"upload cover, user cancled"];
                    } else {
                        uploadContext.lastStatus = TVC_ERR_COVER_UPLOAD_FAILED;
                        uploadContext.desc = [NSString stringWithFormat:@"upload cover, cos code:%@, cos desc:%@", cosErrorCode, errInfo];
                    }
                } else {
                    VodLogInfo(@"upload cover succ");
                }
                reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
                [ws txReport:TVC_UPLOAD_EVENT_ID_COS errCode:uploadContext.lastStatus vodErrCode:0 cosErrCode:cosErrorCode
                                errInfo:uploadContext.desc
                                reqTime:uploadContext.reqTime
                            reqTimeCost:reqTimeCost
                                 reqKey:ws.reqKey
                                  appId:cug.userAppid
                               fileSize:uploadContext.coverSize
                               fileType:[ws getFileType:uploadContext.uploadParam.coverPath]
                               fileName:[ws getFileName:uploadContext.uploadParam.coverPath]
                             sessionKey:cug.uploadSession
                                 fileId:@""
                              cosRegion:cug.uploadRegion
                              useCosAcc:cug.useCosAcc
                           cosRequestId:requestId
                     cosTcpConnTimeCost:tcpConenctionTimeCost
                    cosRecvRespTimeCost:recvRspTimeCost];
                dispatch_semaphore_signal(semaphore);
            }];

            TVCProgressBlock progress = uploadContext.progressBlock;
            [coverUpload setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
                if (progress) {
                    uint64_t total = uploadContext.videoSize + uploadContext.coverSize;
                    uploadContext.currentUpload += bytesSent;
                    if (uploadContext.currentUpload > total) {
                        uploadContext.currentUpload = total;
                        ws.virtualPercent = 100 - VIRTUAL_TOTAL_PERCENT;
                        [ws.timer setFireDate:[NSDate date]];  //上传完成，启动结束虚拟进度
                    } else {
                        progress(
                            uploadContext.currentUpload * (100 - 2 * VIRTUAL_TOTAL_PERCENT) / 100 + VIRTUAL_TOTAL_PERCENT * total / 100,
                            total);
                    }
                }
            }];
            ws.uploadRequest = coverUpload;
            [[QCloudCOSTransferMangerService costransfermangerServiceForKey:self.uploadKey] UploadObject:coverUpload];
        }
    }
    dispatch_semaphore_signal(semaphore);
}

- (void)notifyCosUploadEnd:(TVCUploadContext *)uploadContext {
    __weak TVCClient *ws = self;
    dispatch_group_notify(uploadContext.gcdGroup, uploadContext.gcdQueue, ^{
        if (uploadContext.isUploadVideo) {
            dispatch_semaphore_wait(uploadContext.gcdSem, DISPATCH_TIME_FOREVER);
        }
        if (uploadContext.isUploadCover) {
            dispatch_semaphore_wait(uploadContext.gcdSem, DISPATCH_TIME_FOREVER);
        }

        TVCResultBlock result = uploadContext.resultBlock;

        if (uploadContext.lastStatus != TVC_OK) {
            // 上传失败，由于签名时间太短，上传未完成导致的，重试
            if (uploadContext.isShouldRetry) {
                uploadContext.lastStatus = TVC_OK;
                uploadContext.isShouldRetry = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 1.获取cos参数
                    NSString *vodSessionKey = nil;
                    if (ws.config.enableResume == YES) {
                        vodSessionKey = [ws getSessionFromFilepath:uploadContext];
                    }
                    [self applyUploadUGC:uploadContext withVodSessionKey:vodSessionKey];
                });
            } else if (result && uploadContext.lastStatus != TVC_ERR_UPLOAD_QUIC_FAILED) {
                [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];
                TVCUploadResponse *rsp = [[TVCUploadResponse alloc] init];
                rsp.retCode = uploadContext.lastStatus;
                rsp.descMsg = uploadContext.desc;
                [ws notifyResult:result resp:rsp];
                return;
            }
        } else {
            uploadContext.reqTime = [[NSDate date] timeIntervalSince1970] * 1000;
            [ws completeUpload:uploadContext withDomain:UGC_HOST];
        }
    });
}

- (void)completeUpload:(TVCUploadContext *)uploadContext withDomain:(NSString *)domain {
    // 3.完成上传
    VodLogInfo(@"complete upload task");
    TVCResultBlock result = uploadContext.resultBlock;
    __weak TVCClient *ws = self;
    NSMutableURLRequest *cosFiniURLRequest = [self getCosEndURLRequest:domain withContext:uploadContext];
    NSURLSessionTask *finiTask = [self.session
        dataTaskWithRequest:cosFiniURLRequest
          completionHandler:^(NSData *_Nullable finiData, NSURLResponse *_Nullable response, NSError *_Nullable error) {
              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
              if (error || httpResponse.statusCode != 200 || finiData == nil) {
                  if ([domain isEqualToString:UGC_HOST]) {
                      if (++uploadContext.vodCmdRequestCount < kMaxRequestCount) {
                          [ws completeUpload:uploadContext withDomain:UGC_HOST];
                      } else {
                          uploadContext.vodCmdRequestCount = 0;
                          uploadContext.mainVodServerErrMsg = [NSString stringWithFormat:@"main vod fail code:%ld", (long)error.code];
                          [ws completeUpload:uploadContext withDomain:UGC_HOST_BAK];
                      }
                  } else if ([domain isEqualToString:UGC_HOST_BAK]) {
                      if (++uploadContext.vodCmdRequestCount < kMaxRequestCount) {
                          [ws completeUpload:uploadContext withDomain:UGC_HOST_BAK];
                      } else {
                          [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];
                          // 3步骤出错
                          VodLogError(@"cos end http req fail : error=%ld response=%s", (long)error.code, [httpResponse.description UTF8String]);
                          if (result) {
                              long long reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
                              TVCUploadResponse *initResp = [[TVCUploadResponse alloc] init];
                              initResp.retCode = TVC_ERR_UGC_FINISH_REQ_FAILED;
                              initResp.descMsg = [NSString stringWithFormat:@"ugc code:%ld, ugc desc:%@", (long)error.code, @"ugc finish http req fail"];
                              if (uploadContext.mainVodServerErrMsg != nil && uploadContext.mainVodServerErrMsg.length > 0) {
                                  initResp.descMsg = [NSString stringWithFormat:@"%@|%@", initResp.descMsg, uploadContext.mainVodServerErrMsg];
                              }

                              [ws txReport:TVC_UPLOAD_EVENT_ID_FINISH errCode:initResp.retCode vodErrCode:error.code cosErrCode:@"" errInfo:initResp.descMsg
                                              reqTime:uploadContext.reqTime
                                          reqTimeCost:reqTimeCost
                                               reqKey:ws.reqKey
                                                appId:uploadContext.cugResult.userAppid
                                             fileSize:uploadContext.videoSize
                                             fileType:[ws getFileType:uploadContext.uploadParam.videoPath]
                                             fileName:[ws getFileName:uploadContext.uploadParam.videoPath]
                                           sessionKey:uploadContext.cugResult.uploadSession
                                               fileId:@""
                                            cosRegion:uploadContext.cugResult.uploadRegion
                                            useCosAcc:uploadContext.cugResult.useCosAcc
                                         cosRequestId:@""
                                   cosTcpConnTimeCost:0
                                  cosRecvRespTimeCost:0];

                              [ws notifyResult:result resp:initResp];
                          }
                      }
                  }
                  return;
              }
              [ws parseFinishRsp:finiData withContex:uploadContext];
          }];
    [finiTask resume];
}

- (void)parseFinishRsp:(NSData *)finiData withContex:(TVCUploadContext *)uploadContext {
    TVCResultBlock result = uploadContext.resultBlock;
    NSDictionary *finiDict = [NSJSONSerialization JSONObjectWithData:finiData options:(NSJSONReadingMutableLeaves)error:nil];

    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:finiDict options:NSJSONWritingPrettyPrinted error:&parseError];
    NSString *finiDictStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    VodLogInfo(@"end cos dic : %@", finiDictStr);

    int code = -1;
    if ([[finiDict objectForKey:kCode] isKindOfClass:[NSNumber class]]) {
        code = [[finiDict objectForKey:kCode] intValue];
    }
    NSString *msg;
    
    if ([[finiDict objectForKey:kMessage] isKindOfClass:[NSString class]]) {
        msg = [finiDict objectForKey:kMessage];
    }

    NSDictionary *dataDict = nil;
    NSString *videoURL = @"";
    NSString *coverURL = @"";
    NSString *videoID = @"";
    if ([[finiDict objectForKey:kData] isKindOfClass:[NSDictionary class]]) {
        dataDict = [finiDict objectForKey:kData];

        NSDictionary *videoDic = nil;
        NSDictionary *coverDic = nil;
        if ([[dataDict objectForKey:@"video"] isKindOfClass:[NSDictionary class]]) {
            videoDic = [dataDict objectForKey:@"video"];
            if (self.config.enableHttps == YES) {
                videoURL = [[videoDic objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"http:" withString:@"https:"];
            } else {
                videoURL = [videoDic objectForKey:@"url"];
            }
        }
        if ([[dataDict objectForKey:@"cover"] isKindOfClass:[NSDictionary class]]) {
            coverDic = [dataDict objectForKey:@"cover"];
            if (self.config.enableHttps == YES) {
                coverURL = [[coverDic objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"http:" withString:@"https:"];
            } else {
                coverURL = [coverDic objectForKey:@"url"];
            }
        }
        if ([[dataDict objectForKey:@"fileId"] isKindOfClass:[NSString class]]) {
            videoID = [dataDict objectForKey:@"fileId"];
        }
    }

    [[TXUGCPublishOptCenter shareInstance] delPublishing:uploadContext.uploadParam.videoPath];
    TVCUploadResponse *finiResp = [[TVCUploadResponse alloc] init];
    if (code != TVC_OK) {
        // 3步骤出错
        finiResp.retCode = TVC_ERR_UGC_FINISH_RSP_FAILED;
        finiResp.descMsg = [NSString stringWithFormat:@"ugc code:%d, ugc desc:%@ ugc finish http rsp fail", code, msg];
        if (result) {
            long long reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
            [self txReport:TVC_UPLOAD_EVENT_ID_FINISH errCode:finiResp.retCode vodErrCode:code cosErrCode:@"" errInfo:finiResp.descMsg
                            reqTime:uploadContext.reqTime
                        reqTimeCost:reqTimeCost
                             reqKey:self.reqKey
                              appId:uploadContext.cugResult.userAppid
                           fileSize:uploadContext.videoSize
                           fileType:[self getFileType:uploadContext.uploadParam.videoPath]
                           fileName:[self getFileName:uploadContext.uploadParam.videoPath]
                         sessionKey:uploadContext.cugResult.uploadSession
                             fileId:@""
                          cosRegion:uploadContext.cugResult.uploadRegion
                          useCosAcc:uploadContext.cugResult.useCosAcc
                       cosRequestId:@""
                 cosTcpConnTimeCost:0
                cosRecvRespTimeCost:0];
            [self notifyResult:result resp:finiResp];
        }
        return;
    } else {
        TVCProgressBlock progress = uploadContext.progressBlock;
        if (progress) {
            uint64_t total = uploadContext.videoSize + uploadContext.coverSize;
            progress(total, total);
        }

        //所有步骤成功完成
        finiResp.retCode = TVC_OK;
        finiResp.videoId = videoID;
        finiResp.videoURL = videoURL;
        finiResp.coverURL = coverURL;
        if (result) {
            long long reqTimeCost = [[NSDate date] timeIntervalSince1970] * 1000 - uploadContext.reqTime;
            [self txReport:TVC_UPLOAD_EVENT_ID_FINISH errCode:finiResp.retCode vodErrCode:0 cosErrCode:@"" errInfo:finiResp.descMsg
                            reqTime:uploadContext.reqTime
                        reqTimeCost:reqTimeCost
                             reqKey:self.reqKey
                              appId:uploadContext.cugResult.userAppid
                           fileSize:uploadContext.videoSize
                           fileType:[self getFileType:uploadContext.uploadParam.videoPath]
                           fileName:[self getFileName:uploadContext.uploadParam.videoPath]
                         sessionKey:uploadContext.cugResult.uploadSession
                             fileId:videoID
                          cosRegion:uploadContext.cugResult.uploadRegion
                          useCosAcc:uploadContext.cugResult.useCosAcc
                       cosRequestId:@""
                 cosTcpConnTimeCost:0
                cosRecvRespTimeCost:0];
            [self notifyResult:result resp:finiResp];
        }
        return;
    }
}

- (NSString *)getLastComponent:(NSString *)filePath {
    return [filePath lastPathComponent];
}

- (NSString *)getFileName:(NSString *)filePath {
    return [[filePath lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)getFileType:(NSString *)filePath {
    return [filePath pathExtension];
}

#pragma mark-- 断点续传

// 本地保存 filePath --> session、filePath --> expireTime，filePath --> fileLastModTime, filePath --> resumeData 的映射集合，格式为json
// "TVCMultipartResumeSessionKey": {filePath1: session1, filePath2: session2, filePath3: session3}
// "TVCMultipartResumeExpireTimeKey": {filePath1: expireTime1, filePath2: expireTime2, filePath3: expireTime3}
// session的过期时间是1天
- (NSString *)getSessionFromFilepath:(TVCUploadContext *)uploadContext {
    ResumeCacheData *cacheData = [self.config.uploadResumController getResumeData:uploadContext.uploadParam.videoPath];
    if(cacheData != nil) {
        uploadContext.resumeData = cacheData.resumeData;
        self.videoLastModTime = cacheData.videoLastModTime;
        self.coverLastModTime = cacheData.coverLastModTime;
        return cacheData.vodSessionKey;
    } else {
        uploadContext.resumeData = nil;
        self.videoLastModTime = 0;
        self.coverLastModTime = 0;
        return nil;
    }
}

- (void)setSession:(NSString *)session resumeData:(NSData *)resumeData lastModTime:(uint64_t)lastModTime withFilePath:(NSString *)filePath {
    [self setSession:session resumeData:resumeData lastModTime:lastModTime coverLastModTime:0 withFilePath:filePath];
}

- (void)setSession:(NSString *)session
          resumeData:(NSData *)resumeData
         lastModTime:(uint64_t)lastModTime
    coverLastModTime:(uint64_t)coverLastModTime
        withFilePath:(NSString *)filePath {
    if (filePath == nil || filePath.length == 0) {
        return;
    }
    [self.config.uploadResumController saveSession:filePath withSessionKey:session withResumeData:resumeData withUploadInfo:self.uploadContext];
}

// 上传完成
- (void)notifyResult:(TVCResultBlock)result resp:(TVCUploadResponse *)resp {
    [self txReportDAU];
    [self.timer setFireDate:[NSDate distantFuture]];
    dispatch_async(dispatch_get_main_queue(), ^{
        result(resp);
    });
}

- (void)txReportDAU {
    self.reportInfo.reqType = TVC_UPLOAD_EVENT_DAU;
    [[TVCReport shareInstance] addReportInfo:self.reportInfo];
}

- (void)txReport:(int)eventId
                errCode:(int)errCode
             vodErrCode:(int)vodErrCode
             cosErrCode:(NSString *)cosErrCode
                errInfo:(NSString *)errInfo
                reqTime:(int64_t)reqTime
            reqTimeCost:(int64_t)reqTimeCost
                 reqKey:(NSString *)reqKey
                  appId:(NSString *)appId
               fileSize:(int64_t)fileSize
               fileType:(NSString *)fileType
               fileName:(NSString *)fileName
             sessionKey:(NSString *)sessionKey
                 fileId:(NSString *)fileId
              cosRegion:(NSString *)cosRegion
              useCosAcc:(int)useCosAcc
           cosRequestId:(NSString *)cosRequestId
     cosTcpConnTimeCost:(int64_t)cosTcpConnTimeCost
    cosRecvRespTimeCost:(int64_t)cosRecvRespTimeCost {
    self.reportInfo.reqType = eventId;
    self.reportInfo.errCode = errCode;
    self.reportInfo.errMsg = (errInfo == nil ? @"" : errInfo);
    self.reportInfo.reqTime = reqTime;
    self.reportInfo.reqTimeCost = reqTimeCost;
    self.reportInfo.fileSize = fileSize;
    self.reportInfo.fileType = fileType;
    self.reportInfo.fileName = fileName;
    if (appId != 0) {
        self.reportInfo.appId = [appId longLongValue];
    }
    self.reportInfo.reqServerIp = self.serverIP;
    self.reportInfo.reportId = self.config.userID;
    self.reportInfo.reqKey = reqKey;
    self.reportInfo.vodSessionKey = sessionKey;
    self.reportInfo.fileId = fileId;
    self.reportInfo.vodErrCode = vodErrCode;
    self.reportInfo.cosErrCode = (cosErrCode == nil ? @"" : cosErrCode);
    self.reportInfo.cosRegion = (cosRegion == nil ? @"" : cosRegion);
    self.reportInfo.useCosAcc = useCosAcc;
    self.reportInfo.cosVideoPath = self.cosVideoPath == nil ? @"" : self.cosVideoPath;

    if (eventId == TVC_UPLOAD_EVENT_ID_COS) {
        self.reportInfo.useHttpDNS = 0;
        self.reportInfo.tcpConnTimeCost = cosTcpConnTimeCost;
        self.reportInfo.recvRespTimeCost = cosRecvRespTimeCost;
        self.reportInfo.requestId = (cosRequestId == nil ? @"" : cosRequestId);
    } else {
        self.reportInfo.useHttpDNS = [[TXUGCPublishOptCenter shareInstance] useHttpDNS:UGC_HOST] ? 1 : 0;
    }

    [[TVCReport shareInstance] addReportInfo:self.reportInfo];

    return;
}

- (void)queryIpWithDomain:(NSString *)domain {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        struct hostent *hs;
        struct sockaddr_in server;
        if ((hs = gethostbyname([domain UTF8String])) != NULL) {
            server.sin_addr = *((struct in_addr *)hs->h_addr_list[0]);
            self.serverIP = [NSString stringWithUTF8String:inet_ntoa(server.sin_addr)];
        } else {
            self.serverIP = domain;
        }
    });
}

- (NSDictionary *)getStatusInfo {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:[NSString stringWithFormat:@"%d", self.reportInfo.reqType] forKey:@"reqType"];
    [info setObject:[NSString stringWithFormat:@"%d", self.reportInfo.errCode] forKey:@"errCode"];
    [info setObject:self.reportInfo.errMsg forKey:@"errMsg"];
    [info setObject:[NSString stringWithFormat:@"%lld", self.reportInfo.reqTime] forKey:@"reqTime"];
    [info setObject:[NSString stringWithFormat:@"%lld", self.reportInfo.reqTimeCost] forKey:@"reqTimeCost"];
    [info setObject:[NSString stringWithFormat:@"%lld", self.reportInfo.fileSize] forKey:@"fileSize"];
    [info setObject:self.reportInfo.fileType forKey:@"fileType"];
    [info setObject:self.reportInfo.fileName forKey:@"fileName"];
    [info setObject:self.reportInfo.fileId forKey:@"fileId"];
    [info setObject:[NSString stringWithFormat:@"%lld", self.reportInfo.appId] forKey:@"appId"];
    [info setObject:self.reportInfo.reqServerIp forKey:@"reqServerIp"];
    [info setObject:self.reportInfo.reportId forKey:@"reportId"];
    [info setObject:self.reportInfo.reqKey forKey:@"reqKey"];
    [info setObject:self.reportInfo.vodSessionKey forKey:@"vodSessionKey"];

    [info setObject:[NSString stringWithFormat:@"%d", self.reportInfo.vodErrCode] forKey:@"vodErrCode"];
    [info setObject:self.reportInfo.cosErrCode forKey:@"cosErrCode"];
    [info setObject:self.reportInfo.vodSessionKey forKey:@"cosRegion"];
    [info setObject:[NSString stringWithFormat:@"%d", self.reportInfo.useCosAcc] forKey:@"useCosAcc"];
    [info setObject:[NSString stringWithFormat:@"%d", self.reportInfo.useHttpDNS] forKey:@"useHttpDNS"];
    [info setObject:[NSString stringWithFormat:@"%lld", self.reportInfo.tcpConnTimeCost] forKey:@"tcpConnTimeCost"];
    [info setObject:[NSString stringWithFormat:@"%lld", self.reportInfo.recvRespTimeCost] forKey:@"recvRespTimeCost"];

    return info;
}

- (void)setAppId:(int)appId {
    if (appId != 0) {
        self.reportInfo.appId = appId;
    }
}

// 收集连接建立耗时、收到首包耗时。走httpdns的收集不到。
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    NSURLSessionTaskTransactionMetrics *metricsInfo = metrics.transactionMetrics[0];
    self.reportInfo.tcpConnTimeCost = [metricsInfo.connectEndDate timeIntervalSinceDate:metricsInfo.fetchStartDate] * 1000;
    self.reportInfo.recvRespTimeCost = [metricsInfo.responseStartDate timeIntervalSinceDate:metricsInfo.fetchStartDate] * 1000;
}

- (void)postVirtualProgress:(NSTimer *)timer {
    TVCUploadContext *uploadContext = [[timer userInfo] objectForKey:@"uploadContext"];
    TVCProgressBlock progress = uploadContext.progressBlock;
    if (progress) {
        long total = uploadContext.videoSize + uploadContext.coverSize;
        if ((self.virtualPercent >= 0 && self.virtualPercent < 10) || (self.virtualPercent >= 90 && self.virtualPercent < 100)) {
            ++self.virtualPercent;
            progress(self.virtualPercent * total / 100, total);
        }
    }
}

@end
