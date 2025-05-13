//
//  TVCReport.h
//  TXMUploader
//
//  Created by carolsuo on 2018/3/28.
//  Copyright © 2018年 lynxzhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "TVCClientInner.h"

static NSString* TXUPLOAD_REPORT_URL = VOD_REPORT_DOMESTIC_HOST;
static NSString* TXUPLOAD_REPORT_URL_BAK = VOD_REPORT_DOMESTIC_HOST_BAK;

@interface TVCReport : NSObject

+ (instancetype)shareInstance;

- (void) addReportInfo:(TVCReportInfo *)info;

@property (strong, nonatomic) NSMutableArray *reportCaches;
@property (nonatomic, weak) NSTimer* timer;

@end
