//
//  UploadResumeDefaultController.h
//  TXLiteAVDemo
//
//  Created by Kongdywang on 2022/12/26.
//  Copyright © 2022 Tencent. All rights reserved.
//

#import "IUploadResumeController.h"

#ifndef UploadResumeDefaultController_h
#define UploadResumeDefaultController_h

/// VOD session key
/// 点播vodSessionKey
#define TVCMultipartResumeSessionKey        @"TVCMultipartResumeSessionKey"
/// Expiration time of VOD session key
/// vodSessionKey过期时间
#define TVCMultipartResumeExpireTimeKey     @"TVCMultipartResumeExpireTimeKey"
/// File last modified time, used to determine if the file has been modified during breakpoint resume
/// 文件最后修改时间，用于在断点续传的时候判断文件是否修改
#define TVCMultipartFileLastModTime         @"TVCMultipartFileLastModTime"
/// Last modified time of the cover file
/// 封面文件最后修改时间
#define TVCMultipartCoverFileLastModTime    @"TVCMultipartCoverFileLastModTime"
/// Resume data for COS chunked upload file
/// cos分片上传文件resumeData
#define TVCMultipartResumeData              @"TVCMultipartUploadResumeData"

/**
 Default breakpoint controller
 默认续点控制器
 */
@interface UploadResumeDefaultController : NSObject<IUploadResumeController>

@end

#endif /* UploadResumeDefaultController_h */
