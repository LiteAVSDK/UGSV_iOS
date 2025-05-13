
#import "TVCQuicConfigProxy.h"
#import <objc/message.h>
#import "TVCLog.h"

@interface TVCQuicConfigProxy()

@property (nonatomic, strong) id configInstance;
@property (nonatomic, strong) Class configClass;

@end

@implementation TVCQuicConfigProxy

- (instancetype)init
{
    self = [super init];
    if (self) {
        Class QCloudQuicConfigClass = NSClassFromString(@"QCloudQuicConfig");
        SEL shareConfigSelector = NSSelectorFromString(@"shareConfig");
        self.configInstance = ((id (*)(id, SEL))objc_msgSend)(QCloudQuicConfigClass, shareConfigSelector);
    }
    return self;
}

- (void)setIsCustom:(BOOL)isCustom {
    if (self.configInstance) {
        Ivar isCustomIvar = class_getInstanceVariable(self.configClass, "is_custom");
        if (isCustomIvar) {
            object_setIvar(self.configInstance, isCustomIvar, @(isCustom));
        }
    } else {
        VodLogError(@"setIsCustom failed, may not depend quic");
    }
}

- (void)setPort:(NSInteger)port {
    if (self.configInstance) {
        Ivar portIvar = class_getInstanceVariable(self.configClass, "port");
        if (portIvar) {
            object_setIvar(self.configInstance, portIvar, @(port));
        }
    } else {
        VodLogError(@"setPort failed, may not depend quic");
    }
}

- (void)setTcpPort:(NSInteger)port {
    if (self.configInstance) {
        Ivar tcpPortIvar = class_getInstanceVariable(self.configClass, "tcp_port");
        if (tcpPortIvar) {
            object_setIvar(self.configInstance, tcpPortIvar, @(port));
        }
    } else {
        VodLogError(@"setTcpPort failed, may not depend quic");
    }
}

- (void)setRaceType:(NSInteger)raceType {
    if (self.configInstance) {
        Ivar raceTypeIvar = class_getInstanceVariable(self.configClass, "race_type");
        if (raceTypeIvar) {
            object_setIvar(self.configInstance, raceTypeIvar, @(raceType)); // 0 for QCloudRaceTypeOnlyQUIC
        }
    } else {
        VodLogError(@"setRaceType failed, may not depend quic");
    }
}

- (void)setTotalTimeoutMillisec:(NSInteger)millisec {
    if (self.configInstance) {
        Ivar totalTimeoutIvar = class_getInstanceVariable(self.configClass, "total_timeout_millisec");
        if (totalTimeoutIvar) {
            object_setIvar(self.configInstance, totalTimeoutIvar, @(millisec));
        }
    } else {
        VodLogError(@"setTotalTimeoutMillisec failed, may not depend quic");
    }
}

- (void)setConnectTimeoutMillisec:(NSInteger)millisec {
    if (self.configInstance) {
        Ivar connectTimeoutIvar = class_getInstanceVariable(self.configClass, "connect_timeout_millisec");
        if (connectTimeoutIvar) {
            object_setIvar(self.configInstance, connectTimeoutIvar, @(millisec));
        }
    } else {
        VodLogError(@"setConnectTimeoutMillisec failed, may not depend quic");
    }
}

@end
