//
//  TVCHttpMessageURLProtocol.m
//  TXLiteAVDemo
//
//  Created by carolsuo on 2018/8/30.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "TVCHttpMessageURLProtocol.h"
#import "TXUGCPublishOptCenter.h"
#import <arpa/inet.h>
#import <objc/runtime.h>
#import "zlib.h"
#import "TVCLog.h"

#define protocolKey @"TVCHttpMessagePropertyKey"
#define kAnchorAlreadyAdded @"AnchorAlreadyAdded"

@interface TVCHttpMessageURLProtocol () <NSStreamDelegate> {
    NSMutableURLRequest *curRequest;
    NSRunLoop *curRunLoop;
    NSInputStream *inputStream;
}

@end

@implementation TVCHttpMessageURLProtocol

/**
 * Whether to intercept and process the specified request
 *  是否拦截处理指定的请求
 *
 *  @param request Specified request
 *                 指定的请求
 *
 *  @return Return YES means to intercept and process, return NO means not to intercept and process
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    
    /* Prevent infinite loops, because a request will also initiate a request during the interception process, which will then come here. If not processed, it will cause an infinite loop
     防止无限循环，因为一个请求在被拦截处理过程中，也会发起一个请求，这样又会走到这里，如果不进行处理，就会造成无限循环 */
    if ([NSURLProtocol propertyForKey:protocolKey inRequest:request]) {
        return NO;
    }
    
    NSString *url = request.URL.absoluteString;
    
    // If the URL starts with HTTPS, intercept and process, otherwise do not process
    // This protocol is only needed if the IP has been replaced, otherwise it is not needed
    // 如果url以https开头，则进行拦截处理，否则不处理
    //只有替换了IP才需要本协议，否则不需要
    if ([url hasPrefix:@"https"] && [self isIPAddress:request.URL.host]) {
        return YES;
    }
    return NO;
}

/**
 * If you need to redirect the request, add specified headers, etc., you can do so in this method
 * 如果需要对请求进行重定向，添加指定头部等操作，可以在该方法中进行
 */
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

/**
 * If you need to redirect the request, add specified headers, etc., you can do so in this method
 * 开始加载，在该方法中，加载一个请求
 */
- (void)startLoading {
    NSMutableURLRequest *request = [self.request mutableCopy];
    // If you need to redirect the request, add specified headers, etc., you can do so in this method
    // 表示该请求已经被处理，防止无限循环
    [NSURLProtocol setProperty:@(YES) forKey:protocolKey inRequest:request];
    curRequest = request;
    [self startRequest];
}

/**
 * Cancel request
 * 取消请求
 */
- (void)stopLoading {
    [self closeLoading];
    [self.client URLProtocol:self didFailWithError:[[NSError alloc] initWithDomain:@"stop loading" code:-1 userInfo:nil]];
}

- (void)closeLoading {
    @synchronized (self) {
        if (inputStream && inputStream.streamStatus == NSStreamStatusOpen) {
            [inputStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
            [inputStream setDelegate:nil];
            [inputStream close];
        }
    }
}

/**
 * Forward request using CFHTTPMessage
 * 使用CFHTTPMessage转发请求
 */
- (void)startRequest {
    // Header information of the original request
    // 原请求的header信息
    NSDictionary *headFields = curRequest.allHTTPHeaderFields;
    // Add data carried by the HTTP POST request
    // 添加http post请求所附带的数据
    CFStringRef requestBody = CFSTR("");
    CFDataRef bodyData = CFStringCreateExternalRepresentation(kCFAllocatorDefault, requestBody, kCFStringEncodingUTF8, 0);
    if (!curRequest.HTTPMethod) {
        return;
    }
    if (curRequest.HTTPBody) {
        if (bodyData) CFRelease(bodyData);
        bodyData = (__bridge_retained CFDataRef) curRequest.HTTPBody;
    } else if (headFields[@"originalBody"]) {
        // When using NSURLSession to send a POST request, take out the original HTTPBody from the header
        // 使用NSURLSession发POST请求时，将原始HTTPBody从header中取出
        if (bodyData) CFRelease(bodyData);
        bodyData = (__bridge_retained CFDataRef) [headFields[@"originalBody"] dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    CFURLRef requestURL = CFURLCreateWithString(kCFAllocatorDefault, (__bridge CFStringRef)(curRequest.URL.absoluteString), NULL);
    
    // The method used by the original request, GET or POST
    // 原请求所使用的方法，GET或POST
    CFStringRef requestMethod = (__bridge_retained CFStringRef) curRequest.HTTPMethod;
    
    // Create a CFHTTPMessageRef object based on the request URL, method, and version
    // 根据请求的url、方法、版本创建CFHTTPMessageRef对象
    CFHTTPMessageRef cfrequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault, requestMethod, requestURL, kCFHTTPVersion1_1);
    CFHTTPMessageSetBody(cfrequest, bodyData);
    
    // Copy the header information of the original request
    // copy原请求的header信息
    for (NSString *header in headFields) {
        if (header && ![@"originalBody" isEqualToString:header]) {
            // Excluding the body information stored in the header when POST request
            // 不包含POST请求时存放在header的body信息
            CFStringRef requestHeader = (__bridge CFStringRef) header;
            CFStringRef requestHeaderValue = (__bridge CFStringRef) [headFields valueForKey:header];
            CFHTTPMessageSetHeaderFieldValue(cfrequest, requestHeader, requestHeaderValue);
            CFRelease(requestHeader);
            CFRelease(requestHeaderValue);
        }
    }
    
    // Create an input stream for the CFHTTPMessage object
    // 创建CFHTTPMessage对象的输入流
    CFReadStreamRef readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, cfrequest);
    inputStream = (__bridge_transfer NSInputStream *) readStream;
    
    // Set SNI host information, a crucial step
    // 设置SNI host信息，关键步骤
    NSString *host = [curRequest.allHTTPHeaderFields objectForKey:@"host"];
    if (!host) {
        host = curRequest.URL.host;
    }
    [inputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
    NSDictionary *sslProperties = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   host, (__bridge id) kCFStreamSSLPeerName,
                                   nil];
    [inputStream setProperty:sslProperties forKey:(__bridge_transfer NSString *) kCFStreamPropertySSLSettings];
    [inputStream setDelegate:self];
    
    if (!curRunLoop)
        // Save the current thread's runloop, which is critical for redirected requests
        // 保存当前线程的runloop，这对于重定向的请求很关键
        curRunLoop = [NSRunLoop currentRunLoop];
    // Put the request in the event queue of the current runloop
    // 将请求放入当前runloop的事件队列
    [inputStream scheduleInRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
    [inputStream open];
    
    CFRelease(cfrequest);
    CFRelease(requestURL);
    cfrequest = NULL;
    CFRelease(bodyData);
    CFRelease(requestBody);
    CFRelease(requestMethod);
}

/**
 * Handle differently according to the response content returned by the server
 * 根据服务器返回的响应内容进行不同的处理
 */
- (void)handleResponse {
    // Get response header information
    // 获取响应头部信息
    CFReadStreamRef readStream = (__bridge_retained CFReadStreamRef) inputStream;
    CFHTTPMessageRef message = (CFHTTPMessageRef) CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    if (CFHTTPMessageIsHeaderComplete(message)) {
        // Ensure response header information is complete
        // 确保response头部信息完整
        CFDictionaryRef cfHeadDict = CFHTTPMessageCopyAllHeaderFields(message);
        NSDictionary *headDict = (__bridge_transfer NSDictionary *) (cfHeadDict);
        
        // Get the status code of the response header
        // 获取响应头部的状态码
        CFIndex myErrCode = CFHTTPMessageGetResponseStatusCode(message);
        CFRelease(message);
        message = nil;
        [self closeLoading];
        
        if (myErrCode >= 200 && myErrCode < 300) {
            // If the return code is 2xx, notify the client directly
            // 返回码为2xx，直接通知client
            [self.client URLProtocolDidFinishLoading:self];
            
        } else if (myErrCode >= 300 && myErrCode < 400) {
            // if the return code is 3xx, the request needs to be redirected and the redirected page accessed
            // 返回码为3xx，需要重定向请求，继续访问重定向页面
            NSString *location = headDict[@"Location"];
            if (!location)
                location = headDict[@"location"];
            NSURL *url = [[NSURL alloc] initWithString:location];
            curRequest.URL = url;
            if ([[curRequest.HTTPMethod lowercaseString] isEqualToString:@"post"]) {
                // According to the RFC document, when the redirected request is a POST request,
                // it should be converted to a GET request
                // 根据RFC文档，当重定向请求为POST请求时，要将其转换为GET请求
                curRequest.HTTPMethod = @"GET";
                curRequest.HTTPBody = nil;
            }
            
            /** Redirect notification client processing or internal processing 重定向通知client处理或内部处理  **/
            // NSURLResponse* response = [[NSURLResponse alloc] initWithURL:curRequest.URL MIMEType:headDict[@"Content-Type"] expectedContentLength:[headDict[@"Content-Length"] integerValue] textEncodingName:@"UTF8"];
            // [self.client URLProtocol:self wasRedirectedToRequest:curRequest redirectResponse:response];
            
            // Internal processing, convert the host in the URL to IP through HTTPDNS,
            // cannot perform synchronous network requests in the startLoading thread, it will be blocked
            // 内部处理，将url中的host通过HTTPDNS转换为IP，不能在startLoading线程中进行同步网络请求，会被阻塞
            NSArray *ipLists = [[TXUGCPublishOptCenter shareInstance] query:url.host];
            NSString *ip = ([ipLists count] > 0 ? ipLists[0] : nil);
            if (ip) {
                VodLogInfo(@"Get IP from HTTPDNS Successfully!");
                NSRange hostFirstRange = [location rangeOfString:url.host];
                if (NSNotFound != hostFirstRange.location) {
                    NSString *newUrl = [location stringByReplacingCharactersInRange:hostFirstRange withString:ip];
                    curRequest.URL = [NSURL URLWithString:newUrl];
                    [curRequest setValue:url.host forHTTPHeaderField:@"host"];
                }
            }
            [self startRequest];
        } else {
            // In other cases, return response information directly to the client
            // 其他情况，直接返回响应信息给client
            [self.client URLProtocolDidFinishLoading:self];
        }
    } else {
        // If the header information is incomplete, close the input stream and notify the client
        // 头部信息不完整，关闭inputstream，通知client
        [self closeLoading];
        [self.client URLProtocolDidFinishLoading:self];
    }
    if (readStream) {
        CFRelease(readStream);
    }
    if (NULL != message) CFRelease(message);
}

#pragma mark - NSStreamDelegate
/**
 * If the header information is incomplete, close the input stream and notify the client
 * input stream 收到header complete后的回调函数
 */
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if (eventCode == NSStreamEventHasBytesAvailable) {
        CFReadStreamRef readStream = (__bridge_retained CFReadStreamRef) aStream;
        CFHTTPMessageRef message = (CFHTTPMessageRef) CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
        if (CFHTTPMessageIsHeaderComplete(message)) {
            // In case the response header information is incomplete
            // 以防response的header信息不完整
            UInt8 buffer[16 * 1024];
            UInt8 *buf = NULL;
            unsigned long length = 0;
            NSInputStream *inputstream = (NSInputStream *) aStream;
            NSNumber *alreadyAdded = objc_getAssociatedObject(aStream, kAnchorAlreadyAdded);
            NSDictionary *headDict = (__bridge_transfer NSDictionary *) (CFHTTPMessageCopyAllHeaderFields(message));
            if (!alreadyAdded || ![alreadyAdded boolValue]) {
                objc_setAssociatedObject(aStream, kAnchorAlreadyAdded, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_COPY);
                // Notify the client that the response has been received, only notify once
                // 通知client已收到response，只通知一次
                CFStringRef httpVersion = CFHTTPMessageCopyVersion(message);
                // Get the status code of the response header
                // 获取响应头部的状态码
                CFIndex myErrCode = CFHTTPMessageGetResponseStatusCode(message);
                NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:curRequest.URL statusCode:myErrCode HTTPVersion:(__bridge_transfer NSString *) httpVersion headerFields:headDict];
                
                [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                
                // Certificate verification
                // 验证证书
                SecTrustRef trust = (__bridge SecTrustRef) [aStream propertyForKey:(__bridge NSString *) kCFStreamPropertySSLPeerTrust];
                SecTrustResultType res = kSecTrustResultInvalid;
                NSMutableArray *policies = [NSMutableArray array];
                NSString *domain = [[curRequest allHTTPHeaderFields] valueForKey:@"host"];
                if (domain) {
                    [policies addObject:(__bridge_transfer id) SecPolicyCreateSSL(true, (__bridge CFStringRef) domain)];
                } else {
                    [policies addObject:(__bridge_transfer id) SecPolicyCreateBasicX509()];
                }
                /*
                 * Bind the verification policy to the server's certificate
                 * 绑定校验策略到服务端的证书上
                 */
                SecTrustSetPolicies(trust, (__bridge CFArrayRef) policies);
                if (SecTrustEvaluate(trust, &res) != errSecSuccess) {
                    [aStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
                    [aStream setDelegate:nil];
                    [aStream close];
                    [self.client URLProtocol:self didFailWithError:[[NSError alloc] initWithDomain:@"can not evaluate the server trust" code:-1 userInfo:nil]];
                }
                if (res != kSecTrustResultProceed && res != kSecTrustResultUnspecified) {
                    /* If the certificate verification fails, close the input stream
                     证书验证不通过，关闭input stream */
                    [aStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
                    [aStream setDelegate:nil];
                    [aStream close];
                    [self.client URLProtocol:self didFailWithError:[[NSError alloc] initWithDomain:@"fail to evaluate the server trust" code:-1 userInfo:nil]];
                    
                } else {
                    // If the certificate passes, return the data
                    // 证书通过，返回数据
                    if (![inputstream getBuffer:&buf length:&length]) {
                        NSInteger amount = [inputstream read:buffer maxLength:sizeof(buffer)];
                        buf = buffer;
                        length = amount;
                    }
                    NSData *data = [[NSData alloc] initWithBytes:buf length:length];
                    
                    if ([headDict[@"Content-Encoding"] isEqualToString:@"gzip"]) {
                        [self.client URLProtocol:self didLoadData:[self ungzipData:data]];
                    } else {
                        [self.client URLProtocol:self didLoadData:data];
                    }
                    
                }
            } else {
                // Certificate has been verified, return data
                // 证书已验证过，返回数据
                if (![inputstream getBuffer:&buf length:&length]) {
                    NSInteger amount = [inputstream read:buffer maxLength:sizeof(buffer)];
                    buf = buffer;
                    length = amount;
                }
                NSData *data = [[NSData alloc] initWithBytes:buf length:length];
                
                if ([headDict[@"Content-Encoding"] isEqualToString:@"gzip"]) {
                    [self.client URLProtocol:self didLoadData:[self ungzipData:data]];
                } else {
                    [self.client URLProtocol:self didLoadData:data];
                }
            }
        }
        if (NULL != message) CFRelease(message);
    } else if (eventCode == NSStreamEventErrorOccurred) {
        [aStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
        [aStream setDelegate:nil];
        [aStream close];
        // Notify the client that an error has occurred
        // 通知client发生错误了
        [self.client URLProtocol:self didFailWithError:[aStream streamError]];
    } else if (eventCode == NSStreamEventEndEncountered) {
        [self handleResponse];
    }
}

- (NSData *)ungzipData:(NSData *)compressedData
{
    if ([compressedData length] == 0)
        return compressedData;
    
    unsigned full_length = [compressedData length];
    unsigned half_length = [compressedData length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[compressedData bytes];
    strm.avail_in = [compressedData length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    if (inflateInit2(&strm, (15+32)) != Z_OK)
        return nil;
    
    while (!done) {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy: half_length];
        }
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = [decompressed length] - strm.total_out;
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) {
            done = YES;
        } else if (status != Z_OK) {
            break;
        }
    }
    
    if (inflateEnd (&strm) != Z_OK)
        return nil;
    // Set real length.
    if (done) {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    return nil;
}

/**
 * Determine if the input is an IP address
 * 判断输入是否为IP地址
 */
+ (BOOL)isIPAddress:(NSString *)str {
    if (!str) {
        return NO;
    }
    int success;
    struct in_addr dst;
    struct in6_addr dst6;
    const char *utf8 = [str UTF8String];
    // check IPv4 address
    success = inet_pton(AF_INET, utf8, &(dst.s_addr));
    if (!success) {
        // check IPv6 address
        success = inet_pton(AF_INET6, utf8, &dst6);
    }
    return success;
}



@end
