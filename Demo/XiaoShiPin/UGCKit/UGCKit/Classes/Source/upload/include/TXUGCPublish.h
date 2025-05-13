#import <Foundation/Foundation.h>
#import "TXUGCPublishTypeDef.h"
#import "TXUGCPublishListener.h"

@interface  TXUGCPublish: NSObject

@property (nonatomic, weak) id<TXVideoPublishListener> delegate;
@property (nonatomic, weak) id<TXMediaPublishListener> mediaDelegate;

- (id)initWithUserID:(NSString *)userID;

- (id)initWithUploadKey:(NSString *)uploadKey;

- (id)initWithUserID:(NSString *)userID withUploadKey:(NSString *)uploadKey;

/**
 * Publish short video
 * 发布短视频
 * @param param     See TXPublishParam definition
 *              参见TXPublishParam定义
 * @return：See TVCResult definition
 *          参见 TVCResult 定义
 */
- (int)publishVideo:(TXPublishParam*)param;

/**
 * Publish media resources
 * 发布媒体
 * @param param    See TXMediaPublishParam definition
 *              参见TXMediaPublishParam定义
 * @return：See TVCResult definition
 *          参见 TVCResult 定义
 */
- (int)publishMedia:(TXMediaPublishParam*)param;

/**
 * Cancel publishing short video or media
 * Note: The canceled are the unstarted chunks. If the uploaded source file is too small and there are no chunks that have not been triggered for upload when canceled, the final file will still be uploaded
 * 取消发布短视频或者媒体
 * 注意：取消的是未开始的分片。如果上传源文件太小，取消的时候已经没有分片还未触发上传，最终文件还是会上传完成
 */
- (BOOL)canclePublish;

/**
 * Set VOD appId
 * The purpose is to facilitate the location of problems during the upload process
 * 设置点播appId
 * 作用是方便定位上传过程中出现的问题
 */
- (void)setAppId:(int)appId;

/**
 Whether to print/store logs
 是否打印/存储日志
 */
- (void)setIsDebug:(bool)isDebug;

/**
 set host env type
 @param envType TXUploadEnv
 */
+ (void)setEnvConfig:(TXUploadEnv)envType;

@end
