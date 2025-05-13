//
 //  QuicClient.m
 //  TXLiteAVDemo
 //
 //  Created by tao yue on 2021/12/10.
 //  Copyright © 2021 Tencent. All rights reserved.
 //
 
#import "QuicClient.h"
#import "TVCCommon.h"
#import "TVCLog.h"
#import <objc/message.h>
#import "TVCClientInner.h"
#import "TVCQuicConfigProxy.h"

@interface QuicClient () <NSURLSessionDataDelegate>

// for strong hold in this object when aysnc callback
@property (atomic, strong) id manager;
@property (atomic, assign) BOOL isCallback;
@property (atomic, strong) TVCQuicConfigProxy *quicConfig;
 
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
        self.quicConfig = [[TVCQuicConfigProxy alloc] init];
    }
    return self;
}
 
 -(void)sendQuicRequest:(NSString *)domain ip:(NSString *)ip region:(NSString *)region completion:(TXUGCQuicCompletion)completion{
     NSString *reqUrl = [NSString stringWithFormat:@"https://%@", domain];
     VodLogInfo(@"start handle quic request:%@", reqUrl);
     Class TquicRequestClass = NSClassFromString(@"TquicRequest");
     SEL allocSelector = sel_registerName("alloc");
     id req = ((id (*)(id, SEL))objc_msgSend)(TquicRequestClass, allocSelector);

     SEL initSelector = sel_registerName("initWithURL:host:httpMethod:ip:body:headerFileds:");
     if ([req respondsToSelector:initSelector]) {
         req = ((id (*)(id, SEL, NSURL *, NSString *, NSString *, NSString *, NSString *, NSDictionary *))objc_msgSend)(req, initSelector, [NSURL URLWithString:reqUrl], domain, @"HEAD", ip, @"", @{@":method":@"HEAD"});
     } else {
         NSLog(@"initWithURL:host:httpMethod:ip:body:headerFileds: method not found");
         return;
     }
     
     if (!req) {
         VodLogError(@"Failed to create TquicRequest instance, may not include quic");
         return;
     }
     
     [self.quicConfig setIsCustom:NO];
     [self.quicConfig setPort:443];
     [self.quicConfig setTcpPort:80];
     [self.quicConfig setRaceType:TXQCloudRaceTypeOnlyQUIC];
     [self.quicConfig setTotalTimeoutMillisec:PRE_UPLOAD_QUIC_DETECT_TIMEOUT];

     self.isCallback = NO;

     Class TquicConnectionClass = NSClassFromString(@"TquicConnection");
     self.manager = [[TquicConnectionClass alloc] init];
     
     VodLogInfo(@"quic connection is create, start connect");
     UInt64 beginTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);

     SEL tquicConnectWithQuicRequestSelector = NSSelectorFromString(@"tquicConnectWithQuicRequest:didConnect:didReceiveResponse:didReceiveData:didSendBodyData:RequestDidCompleteWithError:");
     void (^didConnectBlock)(NSError * _Nonnull) = ^(NSError * _Nonnull error) {};
     void (^didReceiveResponseBlock)(id _Nonnull) = ^(id _Nonnull response) {
         UInt64 endTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
         UInt64 cosTs = (endTs - beginTs);
         VodLogInfo(@"quic test complete, domain:%@, cosTime:%llu", domain, cosTs);
         if (!self.isCallback) {
             self.isCallback = YES;
             if (completion) {
                 completion(cosTs, domain, region, YES);
             }
         }
     };
     void (^didReceiveDataBlock)(NSData * _Nonnull) = ^(NSData * _Nonnull data) {};
     void (^didSendBodyDataBlock)(int64_t, int64_t, int64_t) = ^(int64_t bytesSent, int64_t totalSentBytes, int64_t totalBytesExpectedToSend) {};
     void (^requestDidCompleteWithErrorBlock)(NSError * _Nonnull) = ^(NSError * _Nonnull error) {
         if (!self.isCallback) {
             self.isCallback = YES;
             if (completion) {
                 UInt64 endTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
                 UInt64 cosTs = (endTs - beginTs);
                 completion(cosTs, domain, region, NO);
             }
             VodLogError(@"quic request failed, error:%@", error);
         }
     };

     ((void (*)(id, SEL, id, void (^)(NSError *), void (^)(id), void (^)(NSData *), void (^)(int64_t, int64_t, int64_t), void (^)(NSError *)))objc_msgSend)(self.manager, tquicConnectWithQuicRequestSelector, req, didConnectBlock, didReceiveResponseBlock, didReceiveDataBlock, didSendBodyDataBlock, requestDidCompleteWithErrorBlock);
     
     VodLogInfo(@"start request quic:%@", reqUrl);
     SEL startRequestSelector = NSSelectorFromString(@"startRequest");
     ((void (*)(id, SEL))objc_msgSend)(self.manager, startRequestSelector);
 }
 
 @end
