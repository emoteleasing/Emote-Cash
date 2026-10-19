

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITVersionContinueBlock)(void);

@interface HQITVersionUpdatePresenter : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL isForceUpdateShowing;

- (void)showWithVersion:(nullable NSString *)version
            forceUpdate:(BOOL)forceUpdate
              updateURL:(nullable NSString *)updateURL
                 inView:(UIView *)hostView
             onContinue:(nullable HQITVersionContinueBlock)onContinue;

- (void)handleForceUpdateBusinessError;

@end

NS_ASSUME_NONNULL_END
