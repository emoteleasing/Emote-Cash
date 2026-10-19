

#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITAccurateRecommendationViewController : HQITBaseViewController

- (instancetype)initWithEmptyState:(BOOL)emptyState;

- (instancetype)initWithResultCode:(NSInteger)resultCode
                           message:(nullable NSString *)message
                    homePromptCopy:(nullable NSString *)homePromptCopy
                    homeUserStatus:(NSInteger)homeUserStatus;

- (instancetype)initWithResultCode:(NSInteger)resultCode message:(nullable NSString *)message;

- (instancetype)initWithRecommendData:(id)data;

@end

NS_ASSUME_NONNULL_END
