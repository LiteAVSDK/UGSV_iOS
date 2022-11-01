// Copyright (c) 2019 Tencent. All rights reserved.

#import "TCPituMotionManager.h"

#import <UIKit/UIKit.h>

#define L(x) [self localizedString:x]

@implementation TCPituMotionManager {
    NSMutableDictionary<NSString *, TCPituMotion *> *_map;
    NSBundle *                                       _resourceBundle;
}

+ (instancetype)sharedInstance {
    static TCPituMotionManager *sharedInstance = nil;
    static dispatch_once_t      onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TCPituMotionManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupBundle];
        NSArray *initList = @[
            @[ @"video_boom", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_boom.zip", L(@"Boom") ],
            // - Remove From Demo
            @[ @"video_nihongshu", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_nihongshu.zip", L(@"TC.BeautySettingPanel.Rainbow Mouse") ],
            @[ @"video_fengkuangdacall", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_fengkuangdacall.zip", L(@"TC.BeautySettingPanel.Glow stick") ],
            @[ @"video_Qxingzuo_iOS", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_Qxingzuo_iOS.zip", L(@"TC.BeautySettingPanel.Q constellation") ],
            @[ @"video_caidai_iOS", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_caidai_iOS.zip", L(@"TC.BeautySettingPanel.Color Ribbon") ],
            @[ @"video_liuhaifadai", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_liuhaifadai.zip", L(@"TC.BeautySettingPanel.Bang Ribbon") ],
            @[ @"video_purplecat", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_purplecat.zip", L(@"TC.BeautySettingPanel.Violet Cat") ],
            @[ @"video_huaxianzi", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_huaxianzi.zip", L(@"TC.BeautySettingPanel.Floral Fairy") ],
            @[ @"video_baby_agetest", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_baby_agetest.zip", L(@"TC.BeautySettingPanel.Little princess") ],
            // 星耳，变脸
            @[ @"video_3DFace_dogglasses2", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_3DFace_dogglasses2.zip", L(@"TC.BeautySettingPanel.glasses dog") ],
            @[ @"video_rainbow", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_rainbow.zip", L(@"TC.BeautySettingPanel.rainbow cloud") ],
            // - /Remove From Demo
        ];
        NSArray *gestureMotionArray = @[
            @[ @"video_pikachu", @"http://dldir1.qq.com/hudongzhibo/AISpecial/Android/181/video_pikachu.zip", L(@"TC.BeautySettingPanel.PikaQiu") ],
            // - Remove From Demo
            @[ @"video_liuxingyu", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_liuxingyu.zip", L(@"TC.BeautySettingPanel.Meteor Shower") ],
            @[ @"video_kongxue2", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_kongxue2.zip", L(@"TC.BeautySettingPanel.Snow Control") ],
            @[ @"video_dianshizhixing", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_dianshizhixing.zip", L(@"TC.BeautySettingPanel.TV Star") ],
            @[ @"video_bottle1", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_bottle1.zip", L(@"TC.BeautySettingPanel.Bottle") ],
            // - /Remove From Demo
        ];
        NSArray *cosmeticMotionArray = @[
            // - Remove From Demo
            @[ @"video_cherries", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_cherries.zip", L(@"TC.BeautySettingPanel.Cherries") ],
            @[ @"video_haiyang2", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_haiyang2.zip", L(@"TC.BeautySettingPanel.Ocean") ],
            @[ @"video_fenfenxia_square_iOS", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_fenfenxia_square_iOS.zip", L(@"TC.BeautySettingPanel.FenFenXia") ],
            @[ @"video_guajiezhuang", @"https://liteav.sdk.qcloud.com/app/res/pitu/video_guajiezhuang.zip", L(@"TC.BeautySettingPanel.Widow Makeup") ],
            @[ @"video_qixichun", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_qixichun.zip", L(@"TC.BeautySettingPanel.Qixichun") ],
            @[ @"video_gufengzhuang", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_gufengzhuang.zip", L(@"TC.BeautySettingPanel.Gufeng") ],
            @[ @"video_dxxiaochounv", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_dxxiaochounv.zip", L(@"TC.BeautySettingPanel.Ugly Girl") ],
            @[ @"video_remix1", @"https://liteav.sdk.qcloud.com/app/res/pitu//video_remix1.zip", L(@"TC.BeautySettingPanel.Mixed Makeup") ],
            // - /Remove From Demo
            @[ @"video_qingchunzannan_iOS", @"http://res.tu.qq.com/materials/video_qingchunzannan_iOS.zip", L(@"TC.BeautySettingPanel.Fu Gu") ],
        ];
        NSArray *backgroundRemovalArray = @[
            @[ @"video_xiaofu", @"http://dldir1.qq.com/hudongzhibo/AISpecial/ios/160/video_xiaofu.zip", L(@"TC.BeautyPanel.Menu.BlendPic") ],
        ];
        NSArray * (^generate)(NSArray *) = ^(NSArray *inputArray) {
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:inputArray.count];
            self->_map            = [[NSMutableDictionary alloc] initWithCapacity:inputArray.count];
            for (NSArray *item in inputArray) {
                TCPituMotion *address = [[TCPituMotion alloc] initWithId:item[0] name:item[2] url:item[1]];
                [array addObject:address];
                self->_map[item[0]] = address;
            }
            return array;
        };
        _motionPasters            = generate(initList);
        _cosmeticPasters          = generate(cosmeticMotionArray);
        _gesturePasters           = generate(gestureMotionArray);
        _backgroundRemovalPasters = generate(backgroundRemovalArray);
    }
    return self;
}

- (TCPituMotion *)motionWithIdentifier:(NSString *)identifier {
    return _map[identifier];
}

- (void)setupBundle {
    NSString *resourcePath = [[NSBundle mainBundle] pathForResource:@"UGCKit" ofType:@"bundle"];
    NSBundle *bundle       = [NSBundle bundleWithPath:resourcePath];
    if (nil == bundle) {
        bundle = [NSBundle mainBundle];
    }
    NSString *path = [[NSBundle mainBundle] pathForResource:@"TCBeautyPanelResources" ofType:@"bundle"];
    if (!path) {
        path = [bundle pathForResource:@"TCBeautyPanelResources" ofType:@"bundle"];
    }
    NSBundle *panelResBundle = [NSBundle bundleWithPath:path];
    if (panelResBundle) {
        bundle = panelResBundle;
    }
    _resourceBundle = bundle ?: [NSBundle mainBundle];
}

- (NSString *)localizedString:(nonnull NSString *)key {
    NSString *string = [_resourceBundle localizedStringForKey:key value:@"" table:nil];
    return string ?: @"";
}

@end

@implementation TCPituMotion
- (instancetype)initWithId:(NSString *)identifier name:(NSString *)name url:(NSString *)address {
    if (self = [super init]) {
        _identifier = identifier;
        _name       = name;
        _url        = [NSURL URLWithString:address];
    }
    return self;
}
@end
