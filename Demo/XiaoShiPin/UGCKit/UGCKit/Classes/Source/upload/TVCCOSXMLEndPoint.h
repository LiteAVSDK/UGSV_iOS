#import <Foundation/Foundation.h>
#import "QCloudCOSXMLEndPoint.h"

NS_ASSUME_NONNULL_BEGIN

#define TVC_FORMAT_BUCKET @"{bucket}"
#define TVC_FORMAT_REGION @"{region}"

@interface TVCCOSXMLEndPoint : QCloudCOSXMLEndPoint

@property (nonatomic, strong) NSString *mCosFormat;

@end

NS_ASSUME_NONNULL_END
