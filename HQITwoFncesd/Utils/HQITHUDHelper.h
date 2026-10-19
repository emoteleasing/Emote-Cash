

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITHUDHelper : NSObject

+ (void)showLoading;
+ (void)showLoadingInView:(nullable UIView *)view;
+ (void)showLoadingWithMessage:(nullable NSString *)message;
+ (void)showLoadingWithMessage:(nullable NSString *)message inView:(nullable UIView *)view;
+ (void)hideLoading;
+ (void)hideLoadingInView:(nullable UIView *)view;

+ (void)showToast:(NSString *)message;
+ (void)showToast:(NSString *)message inView:(nullable UIView *)view;

@end

NS_ASSUME_NONNULL_END
