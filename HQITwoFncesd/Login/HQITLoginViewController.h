

#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITLoginViewController : HQITBaseViewController

@property (nonatomic, copy, nullable) void (^onLoginSuccess)(void);

@end

NS_ASSUME_NONNULL_END
