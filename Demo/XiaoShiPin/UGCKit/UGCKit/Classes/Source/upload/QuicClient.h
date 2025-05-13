//  QuicClient.h
//  TXLiteAVDemo
//
//  Created by tao yue on 2021/12/10.
//  Copyright © 2021 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^TXUGCQuicCompletion)(UInt64 cosTs,NSString* domain,NSString* region,BOOL isQuic);
 /**
  * Used for QUIC detection.
  */
 @interface QuicClient : NSObject
 
 + (QuicClient *) shareQuicClient;
 
 - (void)sendQuicRequest:(NSString *)domain
                      ip:(NSString *)ip
                  region:(NSString *)region
              completion:(TXUGCQuicCompletion)completion;
 
 @end

NS_ASSUME_NONNULL_END
