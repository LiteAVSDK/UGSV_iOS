#ifndef TXUGCPublishListener_H
#define TXUGCPublishListener_H

#import "TXUGCPublishTypeDef.h"

/**********************************************
 **************  Short video publishing callback definition 短视频发布回调定义  **************
 **********************************************/
@protocol TXVideoPublishListener <NSObject>
/**
 * Short video publishing progress
 * 短视频发布进度
 */
@optional
- (void)onPublishProgress:(NSInteger)uploadBytes totalBytes: (NSInteger)totalBytes;

/**
 * Short video publishing completed
 * 短视频发布完成
 */
@optional
- (void)onPublishComplete:(TXPublishResult*)result;

/**
 * Short video publishing event notification
 * 短视频发布事件通知
 */
@optional
- (void)onPublishEvent:(NSDictionary*)evt;

@end


/**********************************************
 **************  Media publishing callback definition 媒体发布回调定义  **************
 **********************************************/
@protocol TXMediaPublishListener <NSObject>
/**
 * Media publishing progress
 * 媒体发布进度
 */
@optional
- (void)onMediaPublishProgress:(NSInteger)uploadBytes totalBytes: (NSInteger)totalBytes;

/**
 * Media publishing completed
 * 媒体发布完成
 */
@optional
- (void)onMediaPublishComplete:(TXMediaPublishResult*)result;

/**
 * Media publishing event notification
 * 媒体发布事件通知
 */
@optional
- (void)onMediaPublishEvent:(NSDictionary*)evt;

@end

#endif
