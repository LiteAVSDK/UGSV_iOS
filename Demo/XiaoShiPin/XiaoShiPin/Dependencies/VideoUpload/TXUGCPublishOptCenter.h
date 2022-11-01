//
//  TXUGCPublishOptCenter.h
//  TXLiteAVDemo
//
//  Created by carolsuo on 2018/8/24.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QuicClient.h"

typedef void (^TXUGCPrepareUploadCompletion)();

@interface TXUGCCosRegionInfo : NSObject
@property(nonatomic, copy) NSString *region;
@property(nonatomic, copy) NSString *domain;
//是否支持quic
@property(nonatomic, assign) BOOL isQuic;
@end

@interface TXUGCPublishOptCenter : NSObject
+ (instancetype)shareInstance;
@property(atomic, assign) BOOL isStarted;
@property(strong, nonatomic) NSString *signature;
@property(strong, nonatomic) NSMutableDictionary *cacheMap;
@property(strong, nonatomic) NSMutableDictionary *fixCacheMap;
@property(strong, nonatomic) NSMutableDictionary *publishingList;
@property(strong, nonatomic) TXUGCCosRegionInfo *cosRegionInfo;
@property(nonatomic, assign) UInt64 minCosRespTime;
@property(nonatomic, strong) QuicClient *quicClient; //quicClient

- (void)prepareUpload:(NSString *)signature
    prepareUploadComplete:(TXUGCPrepareUploadCompletion)prepareUploadComplete;
- (void)updateSignature:(NSString *)signature;
- (NSArray *)query:(NSString *)hostname;
- (NSString *)getCosRegion;
- (BOOL)useProxy;
- (BOOL)useHttpDNS:(NSString *)hostname;
- (void)addPublishing:(NSString *)videoPath;
- (void)delPublishing:(NSString *)videoPath;
- (BOOL)isPublishingPublishing:(NSString *)videoPath;

@end
