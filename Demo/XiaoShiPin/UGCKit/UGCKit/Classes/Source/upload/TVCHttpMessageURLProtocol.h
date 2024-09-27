//
//  TVCHttpMessageURLProtocol.h
//  TXLiteAVDemo
//
//  Created by carolsuo on 2018/8/30.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

/// When the server SNI (Server Name Indication) is started, the client will start this protocol to complete network requests accordingly.
/// 服务器SNI（Server Name Indication）启动时，客户端相应启动此协议完成网络请求
@interface TVCHttpMessageURLProtocol : NSURLProtocol

@end
