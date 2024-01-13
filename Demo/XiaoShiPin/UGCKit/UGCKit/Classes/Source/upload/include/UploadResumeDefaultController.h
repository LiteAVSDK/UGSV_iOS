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

#define TVCMultipartResumeSessionKey        @"TVCMultipartResumeSessionKey"         // 点播vodSessionKey
#define TVCMultipartResumeExpireTimeKey     @"TVCMultipartResumeExpireTimeKey"      // vodSessionKey过期时间
#define TVCMultipartFileLastModTime         @"TVCMultipartFileLastModTime"          // 文件最后修改时间，用于在断点续传的时候判断文件是否修改
#define TVCMultipartCoverFileLastModTime    @"TVCMultipartCoverFileLastModTime"     // 封面文件最后修改时间
#define TVCMultipartResumeData              @"TVCMultipartUploadResumeData"         // cos分片上传文件resumeData

/**
 默认续点控制器
 */
@interface UploadResumeDefaultController : NSObject<IUploadResumeController>

@end

#endif /* UploadResumeDefaultController_h */
