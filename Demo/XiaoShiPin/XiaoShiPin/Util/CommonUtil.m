//
//  CommonUtil.m
//  XiaoShiPinApp
//
//  Created by tao yue on 2023/8/18.
//  Copyright © 2023 Tencent. All rights reserved.
//

#import "CommonUtil.h"

@implementation CommonUtil

/**
 判断当前语言是否是简体中文
 */
+(BOOL)isCurrentLanguageHans
{
    NSArray *languages = [NSLocale preferredLanguages];
    NSString *currentLanguage = [languages firstObject];
    if ([currentLanguage hasPrefix:@"zh"])
    {
        return YES;
    }
    return NO;
}

@end
