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
 上传配置
 */
@interface TVCConfig : NSObject
// 上传签名
@property (nonatomic, strong) NSString *signature;
//超时时间，默认8秒
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
// 是否开启https
@property (nonatomic, assign) BOOL enableHttps;
// 用户id
@property (nonatomic, strong) NSString *userID;
// 是否开启续点上传能力
@property (nonatomic, assign) BOOL enableResume;
// 上传分片大小
@property (nonatomic, assign) long sliceSize;
// 上传并发数量
@property (nonatomic, assign) int concurrentCount;
// upload traffic limit
@property (nonatomic, assign) long trafficLimit;
///续点控制器，可自定义对于续点的控制，默认创建UploadResumeDefaultController
@property (nonatomic, strong) id<IUploadResumeController>  uploadResumController;
@end

#endif /* TVCConfig_h */
