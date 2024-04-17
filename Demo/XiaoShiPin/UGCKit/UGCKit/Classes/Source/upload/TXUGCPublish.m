#import "TXUGCPublish.h"
#import "TVCHeader.h"
#import "TVCClient.h"
#import "TXUGCPublishOptCenter.h"
#import "TXUGCPublishUtil.h"
#import "UploadResumeDefaultController.h"
#import "TVCConfig.h"
#import "TVCLog.h"

#undef _MODULE_
#define _MODULE_ "TXUGCPublish"

@implementation TXPublishParam
- (id)init {
    if ((self = [super init])) {
        _enableHTTPS = NO;
        _enableResume = YES;
        _enablePreparePublish = YES;
    }
    return self;
}
@end

@implementation TXPublishResult
@end

@implementation TXMediaPublishParam
- (id)init {
    if ((self = [super init])) {
        _enableHTTPS = NO;
        _enableResume = YES;
        _enablePreparePublish = YES;
    }
    return self;
}
@end

@implementation TXMediaPublishResult
@end

@interface TXUGCPublish () {
    TVCConfig *_tvcConfig;
    TVCUploadParam *_tvcParam;
    TVCClient *_tvcClient;
    NSString *_userID;
    BOOL _isCancel;
}

@property(nonatomic, assign) BOOL publishing;

@end

@implementation TXUGCPublish

- (id)init {
    self = [super init];
    if (self != nil) {
        _userID = @"";
        _isCancel = NO;
        [self setIsDebug:true];
    }
    return self;
}

- (id)initWithUserID:(NSString *)userID {
    self = [super init];
    if (self != nil) {
        _userID = userID;
        _isCancel = NO;
    }
    return self;
}

- (void)setIsDebug:(_Bool)isDebug {
    [[TVCLog sharedLogger] setLogLevel: isDebug ? QCloudLogLevelVerbose : QCloudLogLevelNone];
}

- (int)publishVideoImpl:(TXPublishParam *)param {
    VodLogInfo(@"start publishVideoImpl");
    if (param.videoPath == nil || param.videoPath.length == 0 ||
        [[NSFileManager defaultManager] fileExistsAtPath:param.videoPath] == NO) {
        VodLogError(@"publishVideo: invalid video file");
        return TVC_ERR_INVALID_VIDEOPATH;
    }
    _tvcConfig = [[TVCConfig alloc] init];
    _tvcConfig.signature = param.signature;
    _tvcConfig.enableHttps = param.enableHTTPS;
    _tvcConfig.userID = _userID;
    _tvcConfig.enableResume = param.enableResume;
    _tvcConfig.sliceSize = param.sliceSize;
    _tvcConfig.concurrentCount = param.concurrentCount;
    _tvcConfig.trafficLimit = param.trafficLimit;
    if(param.uploadResumController != nil) {
        _tvcConfig.uploadResumController = param.uploadResumController;
    } else {
        _tvcConfig.uploadResumController = [[UploadResumeDefaultController alloc] init];
    }

    _tvcParam = [[TVCUploadParam alloc] init];

    _tvcParam.videoPath = param.videoPath;

    _tvcParam.coverPath = param.coverPath;

    _tvcParam.videoName = param.fileName;

    __weak __typeof(self) weakSelf = self;

    if (_tvcClient == nil) {
        _tvcClient = [[TVCClient alloc] initWithConfig:_tvcConfig];
    } else {
        [_tvcClient updateConfig:_tvcConfig];
        [[TXUGCPublishOptCenter shareInstance] updateSignature:param.signature];
    }

    long publishStartTime = [[NSDate date] timeIntervalSince1970];
    [_tvcClient uploadVideo:_tvcParam
        result:^(TVCUploadResponse *resp) {
          VodLogInfo(@"uploadCostTime:%f", ([[NSDate date] timeIntervalSince1970] - publishStartTime));
          __strong __typeof(weakSelf) self = weakSelf;
          if (self == nil) {
              VodLogError(@"weakSelf release");
              return;
          }

          if (resp) {
              VodLogInfo(@"publish video result: retCode = %d descMsg = %s videoId = %s videoUrl = %s "
                    @"coverUrl = %s",
                    resp.retCode, [resp.descMsg UTF8String], [resp.videoId UTF8String],
                    [resp.videoURL UTF8String], [resp.coverURL UTF8String]);

              TXPublishResult *result = [[TXPublishResult alloc] init];
              result.retCode = resp.retCode;
              result.descMsg = resp.descMsg;
              result.videoId = resp.videoId;
              result.videoURL = resp.videoURL;
              result.coverURL = resp.coverURL;

              dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate &&
                    [self.delegate respondsToSelector:@selector(onPublishComplete:)]) {
                    [self.delegate onPublishComplete:result];
                }
              });
          }
          self.publishing = NO;
        }
        progress:^(NSInteger bytesUpload, NSInteger bytesTotal) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(onPublishProgress:
                                                                                    totalBytes:)]) {
                [self.delegate onPublishProgress:bytesUpload totalBytes:bytesTotal];
            }
          });
        }];

    return 0;
}

- (int)publishVideo:(TXPublishParam *)param {
    VodLogInfo(@"vodPublish version:%@", TVCVersion);
    if (_publishing == YES) {
        VodLogError(@"there is existing uncompleted publish task");
        return TVC_ERR_ERR_UGC_PUBLISHING;
    }

    if (param == nil) {
        VodLogError(@"publishVideo: invalid param");
        return TVC_ERR_UGC_INVALID_PARAME;
    }

    if (param.signature == nil || param.signature.length == 0) {
        VodLogError(@"publishVideo: invalid signature");
        return TVC_ERR_INVALID_SIGNATURE;
    }

    _publishing = YES;
    _isCancel = NO;

    if (param.enablePreparePublish) {
        __weak typeof(self) weakSelf = self;
        [[TXUGCPublishOptCenter shareInstance] prepareUpload:param.signature
                                       prepareUploadComplete:^{
            VodLogInfo(@"prepareUploadComplete");
            __strong __typeof(weakSelf) self = weakSelf;
            if (_isCancel) {
                _isCancel = NO;
                _publishing = NO;
                VodLogWarning(@"upload is cancel after prepare upload");
                TXPublishResult *result = [[TXPublishResult alloc] init];
                result.retCode = TVC_ERR_USER_CANCLE;
                result.descMsg = [NSString stringWithFormat:@"upload video, user cancled"];
                [self notifyResult:result];
                return;
            }
            if (self != nil) {
                int ret = [self publishVideoImpl:param];
                self->_publishing = (ret == 0);
            } else {
                VodLogError(@"weak self release");
            }
        }];
        return 0;
    } else {
        [[TXUGCPublishOptCenter shareInstance] prepareUpload:param.signature
                                       prepareUploadComplete:nil];
        int ret = [self publishVideoImpl:param];
        _publishing = (ret == 0);
        return ret;
    }
}
- (int)publishMediaImpl:(TXMediaPublishParam *)param {
    if (param.mediaPath == nil || param.mediaPath.length == 0 ||
        [[NSFileManager defaultManager] fileExistsAtPath:param.mediaPath] == NO) {
        VodLogError(@"publishMedia: invalid video file");
        return TVC_ERR_INVALID_VIDEOPATH;
    }

    _tvcConfig = [[TVCConfig alloc] init];
    _tvcConfig.signature = param.signature;
    _tvcConfig.enableHttps = param.enableHTTPS;
    _tvcConfig.userID = _userID;
    _tvcConfig.enableResume = param.enableResume;
    _tvcConfig.sliceSize = param.sliceSize;
    _tvcConfig.concurrentCount = param.concurrentCount;
    _tvcConfig.trafficLimit = param.trafficLimit;
    if(param.uploadResumController != nil) {
        _tvcConfig.uploadResumController = param.uploadResumController;
    } else {
        _tvcConfig.uploadResumController = [[UploadResumeDefaultController alloc] init];
    }


    _tvcParam = [[TVCUploadParam alloc] init];

    _tvcParam.videoPath = param.mediaPath;

    _tvcParam.videoName = param.fileName;
    __weak __typeof(self) weakSelf = self;
    if (_tvcClient == nil) {
        _tvcClient = [[TVCClient alloc] initWithConfig:_tvcConfig];
    } else {
        [_tvcClient updateConfig:_tvcConfig];
        [[TXUGCPublishOptCenter shareInstance] updateSignature:param.signature];
    }
    long publishStartTime = [[NSDate date] timeIntervalSince1970];
    [_tvcClient uploadVideo:_tvcParam
        result:^(TVCUploadResponse *resp) {
          VodLogInfo(@"uploadCostTime:%f", ([[NSDate date] timeIntervalSince1970] - publishStartTime));
          __strong __typeof(weakSelf) self = weakSelf;
          if (self == nil) {
              return;
          }

          if (resp) {
              VodLogInfo(@"publish media result: retCode = %d descMsg = %s mediaId = %s mediaUrl = %s",
                    resp.retCode, [resp.descMsg UTF8String], [resp.videoId UTF8String],
                    [resp.videoURL UTF8String]);

              TXMediaPublishResult *result = [[TXMediaPublishResult alloc] init];
              result.retCode = resp.retCode;
              result.descMsg = resp.descMsg;
              result.mediaId = resp.videoId;
              result.mediaURL = resp.videoURL;

              dispatch_async(dispatch_get_main_queue(), ^{
                if (self.mediaDelegate &&
                    [self.mediaDelegate respondsToSelector:@selector(onMediaPublishComplete:)]) {
                    [self.mediaDelegate onMediaPublishComplete:result];
                }
              });
          }
          self.publishing = NO;
        }
        progress:^(NSInteger bytesUpload, NSInteger bytesTotal) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (self.mediaDelegate && [self.mediaDelegate respondsToSelector:@selector
                                                          (onMediaPublishProgress:totalBytes:)]) {
                [self.mediaDelegate onMediaPublishProgress:bytesUpload totalBytes:bytesTotal];
            }
          });
        }];
    return 0;
}

- (int)publishMedia:(TXMediaPublishParam *)param {
    VodLogInfo(@"vodPublish version:%@", TVCVersion);
    if (_publishing == YES) {
        VodLogError(@"there is existing uncompleted publish task");
        return TVC_ERR_ERR_UGC_PUBLISHING;
    }

    if (param == nil) {
        VodLogError(@"publishVideo: invalid param");
        return TVC_ERR_UGC_INVALID_PARAME;
    }

    if (param.signature == nil || param.signature.length == 0) {
        VodLogError(@"publishVideo: invalid signature");
        return TVC_ERR_INVALID_SIGNATURE;
    }

    _publishing = YES;
    _isCancel = NO;
    if (param.enablePreparePublish) {
        __weak typeof(self) weakSelf = self;
        [[TXUGCPublishOptCenter shareInstance] prepareUpload:param.signature
                                       prepareUploadComplete:^{
                                        VodLogInfo(@"prepareUploadComplete");
                                         __strong __typeof(weakSelf) self = weakSelf;
                                        if (_isCancel) {
                                            _isCancel = NO;
                                            _publishing = NO;
                                            VodLogWarning(@"upload is cancel after prepare upload");
                                            TXPublishResult *result = [[TXPublishResult alloc] init];
                                            result.retCode = TVC_ERR_USER_CANCLE;
                                            result.descMsg = [NSString stringWithFormat:@"upload media, user cancled"];
                                            [self notifyResult:result];
                                            return;
                                        }
                                         if (self != nil) {
                                             int ret = [self publishMediaImpl:param];
                                             self->_publishing = (ret == 0);
                                         }
                                       }];

        return 0;
    } else {
        [[TXUGCPublishOptCenter shareInstance] prepareUpload:param.signature
                                       prepareUploadComplete:nil];
        int ret = [self publishMediaImpl:param];
        _publishing = (ret == 0);
        return ret;
    }

    return 0;
}

/*
 -(BOOL) canclePublish;
 */
- (BOOL)canclePublish {
    VodLogInfo(@"call canclePublish");
    BOOL result = NO;
    _isCancel = YES;
    if (_tvcClient != nil) {
        result = [_tvcClient cancleUploadVideo];
    }
    if (result) {
        _publishing = NO;
    }
    return result;
}

- (void)setAppId:(int)appId {
    if (_tvcClient != nil) {
        [_tvcClient setAppId:appId];
    }
}

/*
 * 获取上报信息
 */
- (NSDictionary *)getStatusInfo {
    if (_tvcClient != nil) {
        return [_tvcClient getStatusInfo];
    }
    return nil;
}

- (void)notifyResult:(TXPublishResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.delegate) {
            [self.delegate onPublishComplete:result];
        }
    });
}

@end
