//
//  TXUGCPublishOptCenter.m
//  TXLiteAVDemo
//
//  Created by carolsuo on 2018/8/24.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "TXUGCPublishOptCenter.h"
#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "AFNetworkReachabilityManager.h"
#import "TVCClientInner.h"
#import "TVCCommon.h"
#import "TVCReport.h"
#import "AppLocalized.h"
#include <arpa/inet.h>
#include <netdb.h>
#import "TVCLog.h"
#import "QCloudQuic/QCloudQuicConfig.h"
#import "QuicClient.h"

#define PATTERN_IP_V4 @"^(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])(\\.(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])){3}$"
#define PATTERN_IP_V6 @"^((([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){1,7}:)|(([0-9A-Fa-f]{1,4}:){6}:[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){5}(:[0-9A-Fa-f]{1,4}){1,2})|(([0-9A-Fa-f]{1,4}:){4}(:[0-9A-Fa-f]{1,4}){1,3})|(([0-9A-Fa-f]{1,4}:){3}(:[0-9A-Fa-f]{1,4}){1,4})|(([0-9A-Fa-f]{1,4}:){2}(:[0-9A-Fa-f]{1,4}){1,5})|([0-9A-Fa-f]{1,4}:(:[0-9A-Fa-f]{1,4}){1,6})|(:(:[0-9A-Fa-f]{1,4}){1,7})|(([0-9A-Fa-f]{1,4}:){6}(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])(\\.(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])){3})|(([0-9A-Fa-f]{1,4}:){5}:(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])(\\.(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])){3})|(([0-9A-Fa-f]{1,4}:){4}(:[0-9A-Fa-f]{1,4}){0,1}:(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])(\\.(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])){3})|(([0-9A-Fa-f]{1,4}:){3}(:[0-9A-Fa-f]{1,4}){0,2}:(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])(\\.(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])){3})|(([0-9A-Fa-f]{1,4}:){2}(:[0-9A-Fa-f]{1,4}){0,3}:(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])(\\.(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])){3})|([0-9A-Fa-f]{1,4}:(:[0-9A-Fa-f]{1,4}){0,4}:(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])(\\.(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])){3})|(:(:[0-9A-Fa-f]{1,4}){0,5}:(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])(\\.(\\d|[1-9]\\d|1\\d{2}|2[0-4]\\d|25[0-5])){3}))$"

#define HTTPDNS_SERVER @"https://119.29.29.99/d?dn="  // httpdns服务器
#define HTTPDNS_TOKEN @"800654663"

typedef void (^TXUGCCompletion)(int result);
typedef void (^TXUGCHttpCompletion)(NSData *_Nullable data, int errCode);

static TXUGCPublishOptCenter *_shareInstance = nil;
static BOOL gEnableQuic = YES;


@implementation TXUGCCosRegionInfo

- (instancetype)init {
    self = [super init];
    if (self) {
        _region = @"";
        _domain = @"";
        _isQuic = NO;
    }
    return self;
}

@end

@interface TXUGCPublishOptCenter()

@property (nonatomic, strong) NSMutableArray *quicClientList;

@end

@implementation TXUGCPublishOptCenter

+ (instancetype)shareInstance {
    static dispatch_once_t predicate;

    dispatch_once(&predicate, ^{
      _shareInstance = [[TXUGCPublishOptCenter alloc] init];
    });
    return _shareInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _cacheMap = [[NSMutableDictionary alloc] init];
        _fixCacheMap = [[NSMutableDictionary alloc] init];
        _publishingList = [[NSMutableDictionary alloc] init];
        _isStarted = NO;
        _signature = @"";
        _quicClientList = [[NSMutableArray alloc] init];
        _cosRegionInfo = [[TXUGCCosRegionInfo alloc] init];
        [self monitorNetwork];
        _regexIpv4 = [NSRegularExpression regularExpressionWithPattern:PATTERN_IP_V4 options:0 error:nil];
        _regexIpv6 = [NSRegularExpression regularExpressionWithPattern:PATTERN_IP_V6 options:0 error:nil];
    }
    return self;
}

- (void)prepareUpload:(NSString *)signature
    prepareUploadComplete:(TXUGCPrepareUploadCompletion)prepareUploadComplete {
    _signature = signature;
    Boolean ret = false;
    if (!_isStarted) {
        ret = [self reFresh:prepareUploadComplete];
    }
    if (ret) {
        _isStarted = YES;
    } else {
        VodLogInfo(@"preUpload is already loading/init/failed, callback it");
        if (prepareUploadComplete) {
            prepareUploadComplete();
        }
    }
}

- (void)updateSignature:(NSString *)signature {
    _signature = signature;
}

//刷新httpdns
- (Boolean)reFresh:(TXUGCPrepareUploadCompletion)prepareUploadComplete {
    @synchronized(_cosRegionInfo) {
        _minCosRespTime = 0;
        _cosRegionInfo.domain = @"";
        _cosRegionInfo.region = @"";
        _cosRegionInfo.isQuic = NO;
    }
    
    long preloadStartTime = [[NSDate date] timeIntervalSince1970];

    if (_signature == nil || _signature.length == 0) {
        return false;
    }
    //清掉dns缓存
    [_cacheMap removeAllObjects];
    [_fixCacheMap removeAllObjects];

    //使用了代理，不走httpdns
    if ([self useProxy]) {
        return false;
    }

    uint64_t reqTime = [[NSDate date] timeIntervalSince1970] * 1000;
    __weak __typeof(self) weakSelf = self;
    [self
        freshDomain:UGC_HOST
         completion:^(int result) {
           __strong __typeof(weakSelf) self = weakSelf;
           if (self) {
               [self
                   reportPublishOptResult:TVC_UPLOAD_EVENT_ID_REQUEST_VOD_DNS_RESULT
                                  errCode:result
                                   errMsg:@""
                                  reqTime:reqTime
                              reqTimeCost:([[NSDate date] timeIntervalSince1970] * 1000 - reqTime)];

               [self prepareUploadUGC];
           }
        
           VodLogInfo(@"preUpload result:%d", result);
           VodLogInfo(@"preloadCostTime:%f", ([[NSDate date] timeIntervalSince1970] - preloadStartTime));
           if (prepareUploadComplete) {
               prepareUploadComplete();
           }
         }];
    return true;
}

- (void)freshDomain:(NSString *)domain completion:(TXUGCCompletion)completion {
    NSString *reqUrl  = [HTTPDNS_SERVER stringByAppendingFormat:@"%@%@%@", domain, @"&token=", HTTPDNS_TOKEN];

    __weak __typeof(self) weakSelf = self;

    [self sendHttpRequest:reqUrl
                   method:@"GET"
                     body:nil
                  timeOut:PRE_UPLOAD_ANA_DNS_TIME_OUT
                   header:nil
               completion:^(NSData *_Nullable data, int errCode) {
        __strong __typeof(weakSelf) self = weakSelf;
        if (self == nil) {
            if (completion) {
                completion(-1);
            }
            return;
        }
        
        if (data == nil) {
            if (completion) {
                completion(-1);
            }
            return;
        }
        
        NSString *ips = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        VodLogInfo(@"httpdns domain[%@] ips[%@]", domain, ips);
        
        NSArray *ipLists = [ips componentsSeparatedByString:@";"];
        NSMutableArray *ipMutableLists = [[NSMutableArray alloc] init];
        for(int i = 0; i < ipLists.count; i++) {
            NSString *ipStr = ipLists[i];
            if([self checkIPAddreddIsValid:ipStr]) {
                VodLogInfo(@"httpdns domain[%@] addIps[%@]", domain, ipStr);
                [ipMutableLists addObject:ipStr];
            }
        }
        [self setCacheValue:domain ipLists:ipMutableLists];
        VodLogInfo(@"httpdns domain[%@] setIpS[%@]", domain, ipMutableLists);
        
        if (completion) {
            completion(errCode);
        }
    }];
}

/**
 判断ip地址是否有效
 */
- (BOOL)checkIPAddreddIsValid:(NSString*)ipAddress
{
    if (ipAddress.length == 0) {
        return NO;
    }
    return [self.regexIpv4 firstMatchInString:ipAddress options:0 range:NSMakeRange(0, [ipAddress length])] ||
    [self.regexIpv6 firstMatchInString:ipAddress options:0 range:NSMakeRange(0, [ipAddress length])];
}

// 由于NSMutableDictionary不是线程安全的，这里单独起一个加锁方法
- (void)setCacheValue:(NSString *)domain ipLists:(NSArray *)ipLists {
    @synchronized (self) {
        [self.cacheMap setValue:ipLists forKey:domain];
    }
}

//监控网络接入变化
- (void)monitorNetwork {
    //网络切换的时候刷新一下httpdns
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
            case AFNetworkReachabilityStatusUnknown:
                VodLogInfo(@"network changed, StatusUnknown");
//                VodLogInfo(@"%@",UGCLocalize(@"UGCVideoUploadDemo.TXUGCPublishOptCenter.unknow"));
                break;
            case AFNetworkReachabilityStatusNotReachable:
                VodLogInfo(@"network changed, StatusNotReachable");
//                VodLogInfo(@"%@",UGCLocalize(@"UGCVideoUploadDemo.TXUGCPublishOptCenter.notnetwork"));
                break;
            case AFNetworkReachabilityStatusReachableViaWWAN:
                VodLogInfo(@"network changed, 3G|4G");
                [self reFresh:nil];
                break;
            case AFNetworkReachabilityStatusReachableViaWiFi:
                VodLogInfo(@"network changed, WiFi");
                [self reFresh:nil];
                break;
            default:
                break;
        }

    }];
}

// 添加指定域名的ip列表，ip列表是后台返回的
- (void)addDomainDNS:(NSString *)domain ipLists:(NSArray *)ipLists {
    if ([self useProxy]) {
        return;
    }

    if ([ipLists count] == 0) {
        return;
    }

    [_fixCacheMap setValue:ipLists forKey:domain];
}

// 获取指定域名对应的ipLists
- (NSArray *)query:(NSString *)hostname {
    if ([[_cacheMap objectForKey:hostname] count] > 0) {
        return [_cacheMap objectForKey:hostname];
    } else if ([[_fixCacheMap objectForKey:hostname] count] > 0) {
        return [_fixCacheMap objectForKey:hostname];
    } else {
        NSArray *ipArray = [self queryIpWithDomain:hostname];
        if([ipArray count] > 0) {
            [_cacheMap setValue:ipArray forKey:hostname];
            return ipArray;
        }
    }

    return nil;
}

- (NSString *)getCosRegion {
    return _cosRegionInfo.region;
}

//是否使用了代理
- (BOOL)useProxy {
    CFDictionaryRef dicRef = CFNetworkCopySystemProxySettings();
    if (NULL == dicRef) return NO;

    const CFStringRef proxyCFstr =
        (const CFStringRef)CFDictionaryGetValue(dicRef, (const void *)kCFNetworkProxiesHTTPProxy);
    NSString *proxy = (__bridge NSString *)proxyCFstr;
    CFRelease(dicRef);
    if (proxy != nil) {
        //使用了代理
        return YES;
    }
    //没有使用代理
    return NO;
}

//是否使用了httpdns
- (BOOL)useHttpDNS:(NSString *)hostname {
    if ([self query:hostname] != nil) {
        return YES;
    }
    return NO;
}

- (void)addPublishing:(NSString *)videoPath {
    [_publishingList setValue:[NSNumber numberWithBool:YES] forKey:videoPath];
}

- (void)delPublishing:(NSString *)videoPath {
    [_publishingList removeObjectForKey:videoPath];
}

- (BOOL)isPublishingPublishing:(NSString *)videoPath {
    return [[_publishingList objectForKey:videoPath] boolValue];
}

// 预上传（UGC接口）
- (void)prepareUploadUGC {
    NSString *reqUrl =
        [NSString stringWithFormat:@"https://%@/v3/index.php?Action=PrepareUploadUGC", UGC_HOST];
    VodLogInfo(@"prepareUploadUGC reqUrl[%@]", reqUrl);

    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setValue:TVCVersion forKey:@"clientVersion"];
    [dic setValue:_signature forKey:@"signature"];

    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:dic options:0 error:&error];
    if (error) {
        return;
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    uint64_t reqTime = [[NSDate date] timeIntervalSince1970] * 1000;
    __weak __typeof(self) weakSelf = self;
    [self sendHttpRequest:reqUrl
                   method:@"POST"
                     body:body
                  timeOut: PRE_UPLOAD_TIMEOUT
                   header:nil
               completion:^(NSData *_Nullable data, int errCode) {
        __strong __typeof(weakSelf) self = weakSelf;
        if (self) {
            [self reportPublishOptResult:TVC_UPLOAD_EVENT_ID_REQUEST_PREPARE_UPLOAD_RESULT
                                 errCode:errCode
                                  errMsg:@""
                                 reqTime:reqTime
                             reqTimeCost:([[NSDate date] timeIntervalSince1970] * 1000 -
                                          reqTime)];
            [self parsePrepareUploadRsp:data];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)parsePrepareUploadRsp:(NSData *)rspData {
    if (rspData == nil) {
        return;
    }

    NSError *error = nil;
    id ret = [NSJSONSerialization JSONObjectWithData:rspData
                                             options:NSJSONReadingAllowFragments
                                               error:&error];
    if (error || !ret || ![ret isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSDictionary *dic = ret;
    VodLogInfo(@"parsePrepareUploadRsp rspData[%@]", dic);

    int code = -1;
    if ([[dic objectForKey:@"code"] isKindOfClass:[NSNumber class]]) {
        code = [[dic objectForKey:@"code"] intValue];
    }
    if (code != 0) {
        return;
    }

    NSArray *cosArray = nil;
    if ([[dic objectForKey:@"data"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *data = [dic objectForKey:@"data"];
        if (data && [[data objectForKey:@"cosRegionList"] isKindOfClass:[NSArray class]]) {
            cosArray = [data objectForKey:@"cosRegionList"];
        }
    }

    if (cosArray == nil || cosArray.count <= 0) {
        VodLogError(@"parsePrepareUploadRsp cosRegionList is null!");
        return;
    }

    // 最多并发8个请求
    int maxThreadCount = MIN(8, (int)cosArray.count * 2);
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    operationQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    operationQueue.maxConcurrentOperationCount = maxThreadCount;

    uint64_t reqTime = [[NSDate date] timeIntervalSince1970] * 1000;
    __weak __typeof(self) weakSelf = self;
    for (int i = 0; i < cosArray.count; ++i) {
        if ([cosArray[i] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *cosInfo = cosArray[i];
            [operationQueue addOperationWithBlock:^{
              NSString *region = (NSString *)[cosInfo objectForKey:@"region"];
              NSString *domain = (NSString *)[cosInfo objectForKey:@"domain"];
              NSString *ips = (NSString *)[cosInfo objectForKey:@"ip"];
              __strong __typeof(weakSelf) self = weakSelf;
              if (self) {
                  if (region.length > 0 && domain.length > 0) {
                      [self getCosDNS:domain ips:ips];
                      if (gEnableQuic) {
                          [self quicTest:domain region:region];
                      }
                      [self detectBestCosIP:domain region:region];
                  }
              }
            }];
        }
    }

    [operationQueue waitUntilAllOperationsAreFinished];
    Boolean isRegionEmpty = (self.cosRegionInfo.region == nil);
    NSString *errMsg =
        (isRegionEmpty ? @""
                       : [NSString stringWithFormat:@"%@|%@", self.cosRegionInfo.region,
                                                    self.cosRegionInfo.domain]);
    // 请求完成后，将quic超时时间置为默认
    [QCloudQuicConfig shareConfig].total_timeout_millisec_ = UPLOAD_TIME_OUT_SEC * 1000;
    
    VodLogInfo(@"preUploadResult, domain:%@,isQuic:%d,costTime:%f", self.cosRegionInfo.domain, self.cosRegionInfo.isQuic, self.minCosRespTime);
    [self reportPublishOptResult:TVC_UPLOAD_EVENT_ID_DETECT_DOMAIN_RESULT
                         errCode:(isRegionEmpty ? 1 : 0)errMsg:errMsg
                         reqTime:reqTime
                     reqTimeCost:([[NSDate date] timeIntervalSince1970] * 1000 - reqTime)];
}


- (BOOL)isNeedEnableQuic:(NSString *)region {
    @synchronized (self.cosRegionInfo) {
        if (region && [region isEqualToString:self.cosRegionInfo.region]) {
            // check exists ip
            NSArray* ipList = [self query:self.cosRegionInfo.domain];
            if (ipList && ipList.count > 0) {
                BOOL result = self.cosRegionInfo.isQuic;
                return result;
            }
        }
    }
    return NO;
}

- (void)disableQuicIfNeed {
    @synchronized (self.cosRegionInfo) {
        if (self.cosRegionInfo && self.cosRegionInfo.isQuic) {
            self.cosRegionInfo.isQuic = NO;
        }
    }
}


// 发送head请求探测
- (void)detectBestCosIP:(NSString *)domain region:(NSString *)region {
    NSArray* tmp = [self query:domain];
    NSString* ip;
    if (tmp != nil && tmp.count > 0) {
        ip = [tmp objectAtIndex:0];
    }
    NSString *reqUrl;
    if (ip) {
        reqUrl = [NSString stringWithFormat:@"http://%@", ip];
    } else {
        reqUrl = [NSString stringWithFormat:@"http://%@", domain];
    }
    VodLogInfo(@"detectDomain reqUrl[%@]", reqUrl);

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __weak __typeof(self) weakSelf = self;

    UInt64 beginTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
    [self sendHttpRequest:reqUrl
                   method:@"HEAD"
                     body:nil
                  timeOut:PRE_UPLOAD_HTTP_DETECT_COMMON_TIMEOUT
                   header:@{@"host" : domain}
               completion:^(NSData *_Nullable data, int errCode) {
        __strong __typeof(weakSelf) self = weakSelf;
        if (self != nil) {
            if (errCode == 0) {
                UInt64 endTs = (UInt64)([[NSDate date] timeIntervalSince1970] * 1000);
                UInt64 cosTs = (endTs - beginTs);
                VodLogInfo(@"detectHttp domain = %@, result = %d, timeCos = %llu",
                           domain, errCode, cosTs);
                @synchronized(self->_cosRegionInfo) {
                    [self comparisonTime:cosTs region:region domain:domain isQuic:NO];
                }
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, PRE_UPLOAD_HTTP_DETECT_COMMON_TIMEOUT * 2 * NSEC_PER_MSEC));
}

- (void)getCosDNS:(NSString *)domain ips:(NSString *)ips {
    //返回的ip列表为空，首先执行httpdns
    if (ips.length == 0) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [self freshDomain:domain
               completion:^(int result) {
                 dispatch_semaphore_signal(semaphore);
               }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    } else {
        NSArray *ipLists = [ips componentsSeparatedByString:@";"];
        [self addDomainDNS:domain ipLists:ipLists];
    }
}

// 简单包装http请求
- (void)sendHttpRequest:(NSString *)reqUrl
                 method:(NSString *)method
                   body:(NSData *)body
                timeOut:(NSTimeInterval)timeout
                 header:(NSDictionary*)headers
             completion:(TXUGCHttpCompletion)completion {
    // create request
    NSURL *url = [NSURL URLWithString:reqUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = timeout;
    request.HTTPMethod = method;
    if (headers) {
        for (int i = 0; i < headers.count; i++) {
            NSString *key = headers.allKeys[i];
            NSString *value = headers.allValues[i];
            [request setValue:value forHTTPHeaderField:key];
        }
    }
    if (body != nil) {
        [request setValue:[NSString stringWithFormat:@"%ld", (long)[body length]]
            forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:body];
    }

    NSURLSessionConfiguration *initCfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    [initCfg setTimeoutIntervalForRequest:5];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:initCfg
                                                          delegate:nil
                                                     delegateQueue:nil];
    __weak NSURLSession *wis = session;

    NSURLSessionTask *dnsTask =
    [session dataTaskWithRequest:request
               completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                   NSError *_Nullable error) {
        // invalid NSURLSession
        [wis invalidateAndCancel];
        if (error) {
            if (completion) {
                completion(nil, (int)error.code);
            }
            return;
        }
        
        if (completion) {
            completion(data, 0);
        }
    }];
    [dnsTask resume];
}

- (void)reportPublishOptResult:(int)reqType
                       errCode:(int)errCode
                        errMsg:(NSString *)errMsg
                       reqTime:(uint64_t)reqTime
                   reqTimeCost:(uint64_t)reqTimeCost {
    TVCReportInfo *reportInfo = [[TVCReportInfo alloc] init];
    reportInfo.reqType = reqType;
    reportInfo.errCode = errCode;
    reportInfo.errMsg = errMsg;
    reportInfo.reqTime = reqTime;
    reportInfo.reqTimeCost = reqTimeCost;

    [[TVCReport shareInstance] addReportInfo:reportInfo];
}

-(void)comparisonTime:(UInt64)cosTs
               region:(NSString *)region
               domain:(NSString *)domain
               isQuic:(BOOL)isQuic{
    if ([self canUpdateBestCos:cosTs isQuic:isQuic]) {
        self.minCosRespTime = cosTs;
        self.cosRegionInfo.region = region;
        self.cosRegionInfo.domain = domain;
        self.cosRegionInfo.isQuic = isQuic;
        VodLogInfo(@"compareBestCosIP bestCosDomain = %@, bestCosRegion = %@, timeCos = %llu, isQuic = %i", domain, region, cosTs, isQuic);
    }
}

-(BOOL)canUpdateBestCos:(UInt64)cosTs isQuic:(BOOL)isQuic {
    BOOL result = NO;
    if (self.minCosRespTime == 0) {
        result = true;
    } else if (self.cosRegionInfo.isQuic) {
        result = isQuic && cosTs < self.minCosRespTime;
    } else {
        if (isQuic) {
            result = true;
        } else {
            result = cosTs < self.minCosRespTime;
        }
    }
    return result;
}

//quic探测
-(void)quicTest:(NSString *)domain
         region:(NSString *)region{
    NSArray* tmp = [self query:domain];
    NSString* ip;
    if (tmp != nil && tmp.count > 0) {
        ip = [tmp objectAtIndex:0];
    }
    if(ip) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __weak __typeof(self) weakSelf = self;
        QuicClient *quicClient = [QuicClient new];
        // hold quicClient when asycn sendQuicRequest
        [_quicClientList addObject:quicClient];
        [quicClient sendQuicRequest:domain ip:ip region:region
                         completion:^(UInt64 cosTs,NSString* domain,NSString* region,BOOL isQuic){
            __strong __typeof(weakSelf) self = weakSelf;
            if (self) {
                if (isQuic) {
                    @synchronized(self->_cosRegionInfo) {
                        VodLogInfo(@"detectQuic domain = %@, isQuic = %d, timeCos = %llu",
                                   domain, isQuic, cosTs);
                        [self comparisonTime:cosTs region:region domain:domain isQuic:YES];
                    }
                }
                dispatch_semaphore_signal(semaphore);
            }
        }];
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, PRE_UPLOAD_HTTP_DETECT_COMMON_TIMEOUT * 2 * NSEC_PER_MSEC));
        [_quicClientList removeObject:quicClient];
    }
}

- (NSMutableArray*)queryIpWithDomain:(NSString *)domain {
    struct hostent *hs;
    char   **pptr;
    char   str[32];
    NSMutableArray *domainIpArray = [[NSMutableArray alloc] init];
    if ((hs = gethostbyname([domain UTF8String])) != NULL) {
        for(pptr = hs->h_addr_list; *pptr != NULL; pptr++) {
            NSString * ipStr = [NSString stringWithCString:inet_ntop(hs->h_addrtype, *pptr, str, sizeof(str)) encoding:NSUTF8StringEncoding];
            if(ipStr && ipStr.length > 0) {
                [domainIpArray addObject:ipStr];
            }
        }
    }
    return domainIpArray;
}

@end
