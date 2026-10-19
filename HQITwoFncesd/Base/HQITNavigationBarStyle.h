

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITNavigationBarStyle : NSObject

+ (CGFloat)standardNavigationHeightInView:(UIView *)view;

+ (CGFloat)loanBackgroundHeightForWidth:(CGFloat)width;

+ (void)applyLoanBackgroundToNavigationBar:(UINavigationBar *)navigationBar;

+ (nullable UIImage *)loanBackgroundImage;

+ (nullable UIImage *)loanBackgroundImageFittingSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
