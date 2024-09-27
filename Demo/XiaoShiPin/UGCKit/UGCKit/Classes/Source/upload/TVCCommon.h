//
//  VCCommon.h
//  VCDemo
//
//  Created by kennethmiao on 16/10/18.
//  Copyright © 2016年 kennethmiao. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - PRELOAD_TIME_OUT

/// quic total timeout
#define PRE_UPLOAD_QUIC_DETECT_TIMEOUT 2000
/// Here IOS represents the total timeout time, so it will be slightly larger than Android
#define PRE_UPLOAD_HTTP_DETECT_COMMON_TIMEOUT 3000
#define PRE_UPLOAD_TIMEOUT 5000
#define PRE_UPLOAD_ANA_DNS_TIME_OUT 3000
/// upload time out
#define UPLOAD_TIME_OUT_SEC 120
#define UPLOAD_CONNECT_TIME_OUT_MILL 5000


typedef NS_ENUM(NSInteger, TVCResult){
    TVC_OK = 0,                            // Success
    // UGC upload request failed
    // UGC请求上传失败
    TVC_ERR_UGC_REQUEST_FAILED = 1001,
    // UGC information parsing failed
    // UGC信息解析失败
    TVC_ERR_UGC_PARSE_FAILED = 1002,
    // COS video upload failed
    // COS上传视频失败
    TVC_ERR_VIDEO_UPLOAD_FAILED = 1003,
    // COS cover upload failed
    // COS上传封面失败
    TVC_ERR_COVER_UPLOAD_FAILED = 1004,
    // UGC end upload request failed
    // UGC结束上传请求失败
    TVC_ERR_UGC_FINISH_REQ_FAILED = 1005,
    // UGC end upload response failed
    // UGC结束上传响应失败
    TVC_ERR_UGC_FINISH_RSP_FAILED = 1006,
    // The file does not exist on the given file path
    // 传入的文件路径上文件不存在
    TVC_ERR_FILE_NOT_EXIST = 1008,
    // Video is being uploaded
    // 视频正在上传中
    TVC_ERR_ERR_UGC_PUBLISHING = 1009,
    // Invalid parameter
    // 无效参数
    TVC_ERR_UGC_INVALID_PARAME = 1010,
    // Short video upload signature is empty
    // 短视频上传签名为空
    TVC_ERR_INVALID_SIGNATURE = 1012,
    // Video path is empty
    // 视频路径为空
    TVC_ERR_INVALID_VIDEOPATH = 1013,
    // User cancels upload
    // 用户调用取消上传
    TVC_ERR_USER_CANCLE = 1017,
    // COS failed to upload video using QUIC, switch to HTTP upload
    // COS使用quic上传视频失败，转http上传
    TVC_ERR_UPLOAD_QUIC_FAILED = 1019,
    // Signature expired
    // 签名过期
    TVC_ERR_UPLOAD_SIGN_EXPIRED = 1020,
};

/**
 * Definition of short video publishing data reporting
 * 短视频发布数据上报定义
 */
typedef NS_ENUM(NSInteger, TXPublishEventCode)
{
    // UGC publishing request upload
    // UGC发布请求上传
    TVC_UPLOAD_EVENT_ID_INIT    = 10001,
    // UGC publishing calls COS upload
    // UGC发布调用COS上传
    TVC_UPLOAD_EVENT_ID_COS     = 20001,
    // UGC publishing ends upload
    // UGC发布结束上传
    TVC_UPLOAD_EVENT_ID_FINISH  = 10002,
    // Short video upload DAU reporting
    // 短视频上传DAU上报
    TVC_UPLOAD_EVENT_DAU        = 40001,
    // VOD HTTPDNS request result
    // vod http dns请求结果
    TVC_UPLOAD_EVENT_ID_REQUEST_VOD_DNS_RESULT            =   11001,
    // PrepareUploadUGC request result
    // PrepareUploadUGC请求结果
    TVC_UPLOAD_EVENT_ID_REQUEST_PREPARE_UPLOAD_RESULT     =   11002,
    // Detection of optimal region result (including COS iplist)
    // 检测最优园区结果(包含cos iplist)
    TVC_UPLOAD_EVENT_ID_DETECT_DOMAIN_RESULT              =   11003,
};

@interface TVCUploadParam : NSObject
/// Local path of the video
/// 视频本地路径
@property (nonatomic, strong) NSString *videoPath;
/// Local path of the cover
/// 封面本地路径
@property (nonatomic, strong) NSString *coverPath;
/// Video file name
/// 视频文件名
@property (nonatomic, strong) NSString *videoName;
@end


@interface TVCUploadResponse : NSObject
/// Error code
/// 错误码
@property (nonatomic, assign) int retCode;
/// Description information
/// 描述信息
@property (nonatomic, strong) NSString *descMsg;
/// Video file ID
/// 视频文件id
@property (nonatomic, strong) NSString *videoId;
/// Video playback address
/// 视频播放地址
@property (nonatomic, strong) NSString *videoURL;
/// Cover storage address
/// 封面存储地址
@property (nonatomic, strong) NSString *coverURL;
@end

typedef void (^TVCResultBlock) (TVCUploadResponse *resp);
typedef void (^TVCProgressBlock) (NSInteger bytesUpload, NSInteger bytesTotal);
