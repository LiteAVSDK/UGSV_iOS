//
//  AppDelegate.m
//  XiaoShiPin
//
//  Created by cui on 2019/11/11.
//  Copyright © 2019 Tencent. All rights reserved.
//

#import "AppDelegate.h"

#import "AFNetworkReachabilityManager.h"
#import "UGCKit.h"
#import "HUDHelper.h"
#import "TCMainViewController.h"
#import "TCLoginViewController.h"
#import "TCUtil.h"
#import <Bugly/Bugly.h>
#import "SDKHeader.h"
#import <XMagic/TELicenseCheck.h>

@interface AppDelegate ()

@end

@implementation AppDelegate
@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BuglyConfig *config = [[BuglyConfig alloc] init];
    config.unexpectedTerminatingDetectionEnable = YES;
#if DEBUG
    config.channel = @"DEBUG";
#else
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleID isEqualToString:@"com.tencent.fx.xiaoshipin.db"]) {
        config.channel = @"CI";
    } else {
        config.channel = @"AppStore";
    }
#endif
//    [Bugly startWithAppId:@"6efe67cbad" config:config];
    [self setLicenceURL];
    [self monitorNetworkReachability];
    [TXLiveBase setLogLevel:LOGLEVEL_VERBOSE];
    [UGCKitReporter registerReporter:[TCUtil class]];
    TCMainViewController *mainController = [[TCMainViewController alloc] init];
    mainController.loginHandler = ^(TCMainViewController *_) {
        [self showLoginUI];
    };
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [HUDHelper sharedInstance].keyWindow = window;
    window.rootViewController = mainController;
    [window makeKeyAndVisible];
    _window = window;

    return YES;
}

- (void)showLoginUI {
    TCLoginViewController *loginViewController = [[TCLoginViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:loginViewController];
    [self.window.rootViewController presentViewController:nav animated:YES completion:nil];
}

- (void)monitorNetworkReachability {
    // 网络状态回调函数
    void (^statusBlock)(AFNetworkReachabilityStatus status) =
        ^(AFNetworkReachabilityStatus status) {
            NSLog(@"网络状态：%@", AFStringFromNetworkReachabilityStatus(status));
            if (status == AFNetworkReachabilityStatusReachableViaWWAN ||
                status == AFNetworkReachabilityStatusReachableViaWiFi) {
                [self setLicenceURL];
                // 停止网络监控
                [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
            }
        };
    // 设置网络状态变化的回调
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:statusBlock];
    // 启动网络监控
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
}

- (void)setLicenceURL {
    // clang-format off
    [TXLiveBase setLicenceURL:@"" key:@""];
    [TXUGCBase setLicenceURL:@"" key:@""];
    [TELicenseCheck setTELicense:@"license_url" key:@"license_key" completion:^(NSInteger authresult, NSString *_Nonnull errorMsg) {
              if (authresult == TELicenseCheckOk) {
                  NSLog(@"鉴权成功");
              } else {
                  NSLog(@"鉴权失败, 错误消息：%@", errorMsg);
              }
          }];
    // clang-format on
}

@end
