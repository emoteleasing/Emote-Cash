
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITAdjustManager : NSObject

+ (instancetype)shared;
@property (nonatomic, assign, readonly) BOOL isInitialized;
@property (nonatomic, copy, readonly, nullable) NSString *adid;

- (void)initializeWithToken:(NSString *)token;
- (nullable NSString *)currentAdid;

@end

NS_ASSUME_NONNULL_END
