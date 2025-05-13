#ifndef TXUGCPublishTypeDef_H
#define TXUGCPublishTypeDef_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "IUploadResumeController.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Short video publishing result error code definition, short video publishing process is divided into three steps:
 *  step1: Request to upload file
 *  step2: Upload file
 *  step3: Request to publish short video
 *
 * 短视频发布结果错误码定义，短视频发布流程分为三步
 *    step1: 请求上传文件
 *    step2: 上传文件
 *    step3: 请求发布短视频
 */
typedef NS_ENUM(NSInteger, TXPublishResultCode)
{
    /// Publish successfully
    /// 发布成功
    PUBLISH_RESULT_OK                               = 0,
    /// step1: "File upload request" failed to send
    /// step1: “文件上传请求”发送失败
    PUBLISH_RESULT_UPLOAD_REQUEST_FAILED            = 1001,
    /// step1: "File upload request" received an error response
    /// step1: “文件上传请求”收到错误响应
    PUBLISH_RESULT_UPLOAD_RESPONSE_ERROR            = 1002,
    /// step2: "Video file" upload failed
    /// step2: “视频文件”上传失败
    PUBLISH_RESULT_UPLOAD_VIDEO_FAILED              = 1003,
    /// step2: "Cover file" upload failed
    /// step2: “封面文件”上传失败
    PUBLISH_RESULT_UPLOAD_COVER_FAILED              = 1004,
    /// step3: "Short video publishing request" failed to send
    /// step3: “短视频发布请求”发送失败
    PUBLISH_RESULT_PUBLISH_REQUEST_FAILED           = 1005,
    /// step3: "Short video publishing request" received an error response
    /// step3: “短视频发布请求”收到错误响应
    PUBLISH_RESULT_PUBLISH_RESPONSE_ERROR           = 1006,
};

/**
 * Short video publishing parameters
 * 短视频发布参数
 */
@interface TXPublishParam : NSObject
/// secretId, deprecated parameter, do not fill
/// secretId，废弃的参数，不用填
@property (nonatomic, strong) NSString*             secretId;
/// signature
@property (nonatomic, strong) NSString*             signature;
/// Cover image path
/// 封面图路径
@property (nonatomic, strong) NSString *            coverPath;
/// videoPath
@property (nonatomic, strong) NSString*             videoPath;
/// Video name, if not filled, the local file name will be taken
/// 视频名称，不填的话取本地文件名
@property (nonatomic, strong) NSString*             fileName;
/// Resume controller, can customize the control of breakpoints, default to create UploadResumeDefaultController
/// 续点控制器，可自定义对于续点的控制，默认创建UploadResumeDefaultController
@property (nonatomic, strong) id<IUploadResumeController>  uploadResumController;
/// Enable HTTPS, default off
/// 开启HTTPS，默认关闭
@property (nonatomic, assign) BOOL                  enableHTTPS;
/// Enable breakpoint resume, default on
/// 开启断点续传，默认开启
@property (nonatomic, assign) BOOL                  enableResume;
/// Whether to enable pre-upload mechanism, default on, Note: The pre-upload mechanism can greatly improve the upload quality of files
/// 是否开启预上传机制，默认开启，备注：预上传机制可以大幅提升文件的上传质量
@property (nonatomic, assign) BOOL                  enablePreparePublish;
/// Chunk size, supports a minimum of 1M, a maximum of 10M, default 0, which means the uploaded file size is divided by 10
/// 分片大小,支持最小为1M,最大10M，默认0，代表上传文件大小除以10
@property (nonatomic, assign) long                  sliceSize;
/// The speed limit value is set between 819200~838860800, that is, 100KB/s~100MB/s. If it exceeds this range, a 400 error will be returned. It is not recommended to set the value too small to prevent timeout. -1 means no speed limit
/// 限速值设置范围为819200~838860800，即100KB/s~100MB/s，如果超出该范围会返回400错误。不建议将该值设置太小，防止超时。-1 表示不限速
@property (nonatomic, assign) long                  trafficLimit;
/// The maximum number of concurrent uploads for chunked uploads, <=0 means the default within the SDK is 4
/// 分片上传最大并发数量，<=0 则表示SDK内部默认为4个
@property (nonatomic, assign) int                   concurrentCount;
@end

/**
 * Short video publishing result
 * 短视频发布结果
 */
@interface TXPublishResult : NSObject
/// Error code
/// 错误码
@property (nonatomic, assign) int                   retCode;
/// Error description information
/// 错误描述信息
@property (nonatomic, strong) NSString*             descMsg;
/// Video file ID
/// 视频文件id
@property (nonatomic, strong) NSString*             videoId;
/// Video playback address
/// 视频播放地址
@property (nonatomic, strong) NSString*             videoURL;
/// Cover storage address
/// 封面存储地址
@property (nonatomic, strong) NSString*             coverURL;
@end


///////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * Media publishing result error code definition, media publishing process is divided into three steps:
 * step1: Request to upload file
 * step2: Upload file
 * step3: Request to publish media
 * 媒体发布结果错误码定义，媒体发布流程分为三步
 *    step1: 请求上传文件
 *    step2: 上传文件
 *    step3: 请求发布媒体
 */
typedef NS_ENUM(NSInteger, TXMediaPublishResultCode)
{
    /// Publish successfully
    /// 发布成功
    MEDIA_PUBLISH_RESULT_OK                               = 0,
    /// step1: "File upload request" failed to send
    /// step1: “文件上传请求”发送失败
    MEDIA_PUBLISH_RESULT_UPLOAD_REQUEST_FAILED            = 1001,
    /// step1: "File upload request" received an error response
    /// step1: “文件上传请求”收到错误响应
    MEDIA_PUBLISH_RESULT_UPLOAD_RESPONSE_ERROR            = 1002,
    /// step2: "Media" upload failed
    /// step2: “媒体”上传失败
    MEDIA_PUBLISH_RESULT_UPLOAD_VIDEO_FAILED              = 1003,
    /// step3: "Media publishing request" failed to send
    /// step3: “媒体发布请求”发送失败
    MEDIA_PUBLISH_RESULT_PUBLISH_REQUEST_FAILED           = 1005,
    /// step3: "Media publishing request" received an error response
    /// step3: “媒体发布请求”收到错误响应
    MEDIA_PUBLISH_RESULT_PUBLISH_RESPONSE_ERROR           = 1006,
};

/**
 * Media publishing parameters
 * 媒体发布参数
 */
@interface TXMediaPublishParam : NSObject
/// signature
@property (nonatomic, strong) NSString*             signature;
/// mediaPath
@property (nonatomic, strong) NSString*             mediaPath;
/// Media name, if not filled, the local file name will be taken
/// 媒体名称，不填的话取本地文件名
@property (nonatomic, strong) NSString*             fileName;
/// Enable HTTPS, default off
/// 开启HTTPS，默认关闭
@property (nonatomic, assign) BOOL                  enableHTTPS;
/// Enable breakpoint resume, default on
/// 开启断点续传，默认开启
@property (nonatomic, assign) BOOL                  enableResume;
/// Whether to enable pre-upload mechanism, default on, Note: The pre-upload mechanism can greatly improve the upload quality of files
/// 是否开启预上传机制，默认开启，备注：预上传机制可以大幅提升文件的上传质量
@property (nonatomic, assign) BOOL                  enablePreparePublish;
/// Chunk size, supports a minimum of 1M, a maximum of 10M, default 0, which means the uploaded file size is divided by 10
/// 分片大小,支持最小为1M,最大10M，默认0，代表上传文件大小除以10
@property (nonatomic, assign) long                  sliceSize;
/// The maximum number of concurrent uploads for chunked uploads, <=0 means the default within the SDK is 4
/// 分片上传最大并发数量，<=0 则表示SDK内部默认为4个
@property (nonatomic, assign) int                   concurrentCount;
/// The speed limit value is set between 819200~838860800, that is, 100KB/s~100MB/s. If it exceeds this range, a 400 error will be returned. It is not recommended to set the value too small to prevent timeout. -1 means no speed limit
/// 限速值设置范围为819200~838860800，即100KB/s~100MB/s，如果超出该范围会返回400错误。不建议将该值设置太小，防止超时。-1 表示不限速.
@property (nonatomic, assign) long                  trafficLimit;
/// Resume controller, can customize the control of breakpoints, default to create UploadResumeDefaultController
/// 续点控制器，可自定义对于续点的控制，默认创建UploadResumeDefaultController
@property (nonatomic, strong) id<IUploadResumeController>  uploadResumController;
@end


/**
 * Media publishing result
 * 媒体发布结果
 */
@interface TXMediaPublishResult : NSObject
/// Error code
/// 错误码
@property (nonatomic, assign) int                   retCode;
/// Error description information
/// 错误描述信息
@property (nonatomic, strong) NSString*             descMsg;
/// Media file ID
/// 媒体文件id
@property (nonatomic, strong) NSString*             mediaId;
/// Media address
/// 媒体地址
@property (nonatomic, strong) NSString*             mediaURL;
@end

typedef NS_ENUM(NSInteger, TXUploadEnv) {
    /// evn for DOMESTIC
    /// 国内环境
    ENV_DOMESTIC,
    /// env for INTL
    /// 国际环境
    ENV_INTL
};

static TXUploadEnv txUploadEvnType = ENV_DOMESTIC;

#endif
