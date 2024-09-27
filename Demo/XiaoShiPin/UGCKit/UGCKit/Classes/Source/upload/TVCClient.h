//
//  TVCClient.h
//  VCDemo
//
//  Created by kennethmiao on 16/10/18.
//  Copyright © 2016年 kennethmiao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TVCCommon.h"

@class TVCConfig;

@interface TVCClient : NSObject

/**
 * Get instance
 * 获取实例
 * @param config Configure parameters
 *              配置参数
 */
- (instancetype)initWithConfig:(TVCConfig *)config uploadSesssionKey:(NSString*)uploadSesssionKey;

/**
 * Upload file
 * 文件上传
 * @param param Upload file parameters
 *              上传文件参数
 * @param result Upload result callback
 *              上传结果回调
 * @param progress Upload progress callback
 *              上传进度回调
 */
- (void)uploadVideo:(TVCUploadParam *)param result:(TVCResultBlock)result progress:(TVCProgressBlock)progress;

/**
 * Cancel upload
 * 取消上传
 * @return BOOL Success or failure
 *              成功 or 失败
 */
- (BOOL)cancleUploadVideo;


/**
 * Get version number
 * 获取版本号
 * @return NSString Get report information
 *                版本号
 */
+ (NSString *)getVersion;

/**
 * Get report information
 * 获取上报信息
 */
-(NSDictionary *)getStatusInfo;

/**
 * Set VOD appId
 * The purpose is to facilitate the location of problems during the upload process
 * 设置点播appId
 * 作用是方便定位上传过程中出现的问题
 */
- (void)setAppId:(int)appId;

/**
 * Update configuration
 * 更新配置
 */
- (void)updateConfig:(TVCConfig *)config;
@end
