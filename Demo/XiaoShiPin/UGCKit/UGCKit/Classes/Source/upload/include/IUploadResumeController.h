//
//  IUploadResumeController.h
//  TXLiteAVDemo
//
//  Created by Kongdywang on 2022/12/26.
//  Copyright © 2022 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TVCClientInner.h"

#ifndef IUploadResumeController_h
#define IUploadResumeController_h

@protocol IUploadResumeController <NSObject>

/**
 Save breakpoint
 保存续点
 */
- (void)saveSession:(NSString*)filePath withSessionKey:(NSString*)vodSessionKey withResumeData:(NSData*)resumeData
     withUploadInfo:(TVCUploadContext*)uploadContext uploadSesssionKey:(NSString*)uploadSesssionKey;

/**
 Get breakpoint, called only when enableResume is turned on
 获得续点，enableResume开启的时候才会调用
 */
- (ResumeCacheData*)getResumeData:(NSString*)filePath uploadSesssionKey:(NSString*)uploadSesssionKey;

/**
 Get breakpoint, called only when enableResume is turned on
 清除过期续点，续点有效期为一天
 */
- (void)clearLocalCache;

/**
 Determine whether the current upload is a breakpoint upload
 判断当前上传是否为续点上传
 */
- (BOOL)isResumeUploadVideo:(TVCUploadContext*)uploadContext withSessionKey:(NSString*)vodSessionKey
            withFileModTime:(uint64_t)videoLastModTime withCoverModTime:(uint64_t)coverLastModTime
          uploadSesssionKey:(NSString*)uploadSesssionKey;

@end

#endif /* IUploadResumeController_h */


