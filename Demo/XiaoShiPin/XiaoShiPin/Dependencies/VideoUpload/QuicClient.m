//
 //  QuicClient.m
 //  TXLiteAVDemo
 //
 //  Created by tao yue on 2021/12/10.
 //  Copyright © 2021 Tencent. All rights reserved.
 //
 
 #import "QuicClient.h"
 #import "QCloudQuicSession.h"
 #import "QCloudQuicDataTask.h"
 #import "TquicRequest.h"
 #import "TquicConnection.h"
 #import "TquicResponse.h"
 #import "QCloudQuicConfig.h"
 @interface QuicClient () <NSURLSessionDataDelegate>
 
//发起quic的TquicConnection
 @property (nonatomic, strong) TquicConnection *manager;
 
 @end
 
 
 @implementation QuicClient
 static QuicClient* gQuicClient;
 +(QuicClient *)shareQuicClient{
     static dispatch_once_t onceToken;
     dispatch_once(&onceToken, ^{
         gQuicClient = [QuicClient new];
     });
     return gQuicClient;
 }
 
 -(void)sendQuicRequest:(NSString *)domain ip:(NSString *)ip region:(NSString *)region completion:(TXUGCQuicCompletion)completion{
     NSString *reqUrl = [NSString stringWithFormat:@"http://%@", domain];
     TquicRequest *req = [[TquicRequest alloc] initWithURL:[NSURL URLWithString:reqUrl]
                                                          host:domain
                                                    httpMethod:@"head"
                                                            ip:ip
                                                          body:nil
                                                  headerFileds:@{@":method":@"HEAD"}];
     [req.quicAllHeaderFields setValue:@"head" forKey:@"method"];
     [QCloudQuicConfig shareConfig].is_custom = NO;
     [QCloudQuicConfig shareConfig].port = 443;
     [QCloudQuicConfig shareConfig].connect_timeout_millisec_ = 2000;
     _manager = [TquicConnection new];
     UInt64 beginTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
     [_manager tquicConnectWithQuicRequest:req didConnect:^(NSError * _Nonnull error) {
         
         }
         didReceiveResponse:^(TquicResponse *_Nonnull response) {
         if (response.statusCode == 200) {
             UInt64 endTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
             UInt64 cosTs = (endTs - beginTs);
             if(completion){
                 completion(cosTs,domain,region,YES);
             }
         }else{
             completion(0,domain,region,NO);
         }
         }
         didReceiveData:^(NSData *_Nonnull data) {
         
         }
         didSendBodyData:^(int64_t bytesSent, int64_t totolSentBytes, int64_t totalBytesExpectedToSend) {
             
         
         }
         RequestDidCompleteWithError:^(NSError *_Nonnull error) {
         }];
     [_manager startRequest];
     
 }
 
 
 @end
