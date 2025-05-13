#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TVCQuicConfigProxy : NSObject

- (void)setIsCustom:(BOOL)isCustom;

- (void)setTotalTimeoutMillisec:(NSInteger)millisec;

- (void)setConnectTimeoutMillisec:(NSInteger)millisec;

- (void)setRaceType:(NSInteger)raceType;

- (void)setPort:(NSInteger)port;

- (void)setTcpPort:(NSInteger)port;

@end

NS_ASSUME_NONNULL_END
