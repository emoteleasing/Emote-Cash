

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITBaseViewController : UIViewController

@property (nonatomic, assign) BOOL hqit_hidesTabBarWhenPushed;

- (BOOL)hqit_shouldPopBack;

- (void)hqit_setupBackButtonIfNeeded;

@end

NS_ASSUME_NONNULL_END
