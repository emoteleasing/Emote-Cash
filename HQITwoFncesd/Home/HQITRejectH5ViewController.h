

#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITRejectH5ViewController : HQITBaseViewController

+ (BOOL)isRejectH5Configured;

+ (nullable NSString *)configuredPageURLString;

- (instancetype)initWithPageURLString:(nullable NSString *)urlString;

@end

NS_ASSUME_NONNULL_END
