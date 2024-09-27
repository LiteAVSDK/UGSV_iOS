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
#import "QCloudQuic/QCloudQuicConfig.h"
#import "TVCCommon.h"
#import "TVCLog.h"
@interface QuicClient () <NSURLSessionDataDelegate>

// for strong hold in this object when aysnc callback
@property (atomic, strong) TquicConnection *manager;
@property (atomic, assign) BOOL isCallback;
 
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

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.isCallback = NO;
    }
    return self;
}
 
 -(void)sendQuicRequest:(NSString *)domain ip:(NSString *)ip region:(NSString *)region completion:(TXUGCQuicCompletion)completion{
     NSString *reqUrl = [NSString stringWithFormat:@"https://%@", domain];
     TquicRequest *req = [[TquicRequest alloc] initWithURL:[NSURL URLWithString:reqUrl]
                                                          host:domain
                                                    httpMethod:@"HEAD"
                                                            ip:ip
                                                          body:@""
                                                  headerFileds:@{@":method":@"HEAD"}];
     [QCloudQuicConfig shareConfig].is_custom = NO;
     [QCloudQuicConfig shareConfig].port = 443;
     [QCloudQuicConfig shareConfig].tcp_port = 80;
     [QCloudQuicConfig shareConfig].race_type = QCloudRaceTypeOnlyQUIC;
     [QCloudQuicConfig shareConfig].total_timeout_millisec_ = PRE_UPLOAD_QUIC_DETECT_TIMEOUT;
     self.isCallback = NO;
     _manager = [[TquicConnection alloc] init];
     UInt64 beginTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
     [_manager tquicConnectWithQuicRequest:req
        didConnect:^(NSError * _Nonnull error) {
         }
         didReceiveResponse:^(TquicResponse *_Nonnull response) {
             UInt64 endTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
             UInt64 cosTs = (endTs - beginTs);
             VodLogInfo(@"quic test complete, domain:%@, cosTime:%d", domain, cosTs);
             if(!self.isCallback){
                 self.isCallback = YES;
                 if (completion) {
                     completion(cosTs,domain,region,YES);
                 }
             }
        }
         didReceiveData:^(NSData *_Nonnull data) {
        }
         didSendBodyData:^(int64_t bytesSent, int64_t totolSentBytes, int64_t totalBytesExpectedToSend) {
        }
         RequestDidCompleteWithError:^(NSError *_Nonnull error) {
         if (!self.isCallback) {
             self.isCallback = YES;
             if(completion){
                 UInt64 endTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
                 UInt64 cosTs = (endTs - beginTs);
                 completion(cosTs,domain,region,NO);
             }
             VodLogError(@"quic request failed,error:%@",error);
         }
        }];
     [_manager startRequest];
     
 }
 
 @end
