//
//  TVCConfig.h
//  TXLiteAVDemo
//
//  Created by Kongdywang on 2022/12/26.
//  Copyright © 2022 Tencent. All rights reserved.
//

#import "IUploadResumeController.h"
#import <Foundation/Foundation.h>

#ifndef TVCConfig_h
#define TVCConfig_h

/**
 Upload configuration
 上传配置
 */
@interface TVCConfig : NSObject
// Upload signature
// 上传签名
@property (nonatomic, strong) NSString *signature;
// Timeout, default 8 seconds
// 超时时间，默认8秒
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
// Enable HTTPS
// 是否开启https
@property (nonatomic, assign) BOOL enableHttps;
// User ID
// 用户id
@property (nonatomic, strong) NSString *userID;
// Enable resumable upload capability
// 是否开启续点上传能力
@property (nonatomic, assign) BOOL enableResume;
// Upload slice size
// 上传分片大小
@property (nonatomic, assign) long sliceSize;
// Upload concurrency
// 上传并发数量
@property (nonatomic, assign) int concurrentCount;
// upload traffic limit
@property (nonatomic, assign) long trafficLimit;
/// Breakpoint controller, customizable for breakpoint control, default creation of UploadResumeDefaultController
/// 续点控制器，可自定义对于续点的控制，默认创建UploadResumeDefaultController
@property (nonatomic, strong) id<IUploadResumeController>  uploadResumController;
@end

#endif /* TVCConfig_h */
