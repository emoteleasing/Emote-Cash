

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const HQITHomeShouldRefreshNotification;

@interface HQITAppShell : NSObject

+ (instancetype)shared;

@property (nonatomic, weak, nullable) UIWindow *window;

- (void)installRootInWindow:(UIWindow *)window;

- (void)showLogin;

- (void)completeLogin;

- (void)returnToGuestHomeThenShowLogin;

@end

NS_ASSUME_NONNULL_END
