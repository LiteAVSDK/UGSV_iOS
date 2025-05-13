#import "TVCCOSXMLEndPoint.h"

@implementation TVCCOSXMLEndPoint

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.mCosFormat = @"";
    }
    return self;
}

- (NSURL *)serverURLWithBucket:(NSString *)bucket appID:(NSString *)appID regionName:(NSString *)regionName {
    if (self.mCosFormat && self.mCosFormat.length > 0) {
        NSString *scheme = @"https";
        if (!self.useHTTPS) {
            scheme = @"http";
        }
        NSString *tmpCosDomain = self.mCosFormat;
        tmpCosDomain = [tmpCosDomain stringByReplacingOccurrencesOfString:TVC_FORMAT_BUCKET withString:bucket];
        tmpCosDomain = [tmpCosDomain stringByReplacingOccurrencesOfString:TVC_FORMAT_REGION withString:regionName];
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", scheme, tmpCosDomain]];
    } else {
        return [super serverURLWithBucket:bucket appID:appID regionName:regionName];
    }
}

- (void)setMCosFormat:(NSString *)mCosFormat {
    if (mCosFormat && mCosFormat.length > 0) {
        self.serviceName = @"";
    } else {
        self.serviceName = @"myqcloud.com";
    }
    self->_mCosFormat = mCosFormat;
}

- (id)copyWithZone:(NSZone *)zone {
    TVCCOSXMLEndPoint *endpoint = [super copyWithZone:nil];
    endpoint.mCosFormat = self.mCosFormat;
    return endpoint;
}

@end
