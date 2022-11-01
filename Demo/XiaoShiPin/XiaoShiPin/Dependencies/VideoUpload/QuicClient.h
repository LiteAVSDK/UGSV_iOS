//  QuicClient.h
//  TXLiteAVDemo
//
//  Created by tao yue on 2021/12/10.
//  Copyright © 2021 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TquicConnection.h"

NS_ASSUME_NONNULL_BEGIN
typedef void (^TXUGCQuicCompletion)(UInt64 cosTs,NSString* domain,NSString* region,BOOL isQuic);
 /**
  *用来进行quic探测
  */
 @interface QuicClient : NSObject
//保存quic探测后的region
 @property (nonatomic,assign) NSString* region;
//是否支持quic
 @property (nonatomic,assign) BOOL isQuic;
 
 + (QuicClient *) shareQuicClient;
 
 - (void)sendQuicRequest:(NSString *)domain
                      ip:(NSString *)ip
                  region:(NSString *)region
              completion:(TXUGCQuicCompletion)completion;
 
 @end

NS_ASSUME_NONNULL_END
