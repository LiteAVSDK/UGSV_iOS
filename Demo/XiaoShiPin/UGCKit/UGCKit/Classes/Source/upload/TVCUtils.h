//
//  TVCUtils.h
//  TXMUploader
//
//  Created by carolsuo on 2017/12/21.
//  Copyright © 2017年 lynxzhang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TVCUtils : NSObject

/**
 * Get accurate device model
 * 获取准确的设备型号
 */
+ (NSString *)tvc_deviceModelName;

/**
 * Get network type
 * 获取网络类型
 */
+ (int) tvc_getNetWorkType;

+ (NSString *) tvc_getAppName;

+ (NSString *) tvc_getPackageName;

+ (NSString *)tvc_getDevUUID;

+ (id)findObj:(NSDictionary*)dic withKey:(NSString*)key withClass:(Class)claz withDet:(id)obj;

+ (id)findObj:(NSDictionary*)dic withKey:(NSString*)key withClass:(Class)claz;

+ (id)findObjForce:(NSDictionary*)dic withKey:(NSString*)key withClass:(Class)claz;

@end
