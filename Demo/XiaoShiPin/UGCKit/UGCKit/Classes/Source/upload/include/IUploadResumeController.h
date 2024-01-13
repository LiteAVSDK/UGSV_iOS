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
 保存续点
 */
- (void)saveSession:(NSString*)filePath withSessionKey:(NSString*)vodSessionKey withResumeData:(NSData*)resumeData
     withUploadInfo:(TVCUploadContext*)uploadContext;

/**
 获得续点，enableResume开启的时候才会调用
 */
- (ResumeCacheData*)getResumeData:(NSString*)filePath;

/**
 清除过期续点，续点有效期为一天
 */
- (void)clearLocalCache;

/**
 判断当前上传是否为续点上传
 */
- (BOOL)isResumeUploadVideo:(TVCUploadContext*)uploadContext withSessionKey:(NSString*)vodSessionKey
            withFileModTime:(uint64_t)videoLastModTime withCoverModTime:(uint64_t)coverLastModTime;

@end

#endif /* IUploadResumeController_h */


