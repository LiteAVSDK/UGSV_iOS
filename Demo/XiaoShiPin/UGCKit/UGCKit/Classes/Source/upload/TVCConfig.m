//
//  TVCConfig.m
//  TXLiteAVDemo
//
//  Created by Kongdywang on 2022/12/26.
//  Copyright © 2022 Tencent. All rights reserved.
//

#import "TVCConfig.h"

@implementation TVCConfig

- (instancetype)init
{
    self = [super init];
    if (self) {
        _signature = @"";
        _userID = @"";
        _uploadResumController = nil;
        _trafficLimit = -1;
    }
    return self;
}

@end
