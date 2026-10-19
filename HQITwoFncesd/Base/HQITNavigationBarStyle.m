
#import "HQITNavigationBarStyle.h"
#import "HQITFontHelper.h"

@implementation HQITNavigationBarStyle

+ (CGFloat)standardNavigationHeightInView:(UIView *)view {
    CGFloat topInset = view.safeAreaInsets.top;
    if (topInset <= 0) {
        topInset = UIApplication.sharedApplication.statusBarFrame.size.height;
    }
    return topInset + 44.0;
}

+ (CGFloat)loanBackgroundHeightForWidth:(CGFloat)width {
    UIImage *img = [UIImage imageNamed:@"loan_bg"];
    if (!img || img.size.width <= 0) {
        return 88.0;
    }
    return ceil(width * img.size.height / img.size.width);
}

+ (UIImage *)loanBackgroundImage {
    return [UIImage imageNamed:@"loan_bg"];
}

+ (UIImage *)loanBackgroundImageFittingSize:(CGSize)size {
    UIImage *img = [UIImage imageNamed:@"loan_bg"];
    if (!img || size.width <= 0 || size.height <= 0) return img;
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGFloat scale = MAX(size.width / img.size.width, size.height / img.size.height);
    CGFloat w = img.size.width * scale;
    CGFloat h = img.size.height * scale;
    CGRect rect = CGRectMake((size.width - w) * 0.5, 0, w, h);
    [img drawInRect:rect];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: img;
}

+ (void)applyLoanBackgroundToNavigationBar:(UINavigationBar *)navigationBar {
    if (!navigationBar) return;
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];

    CGFloat w = MAX(navigationBar.bounds.size.width, UIScreen.mainScreen.bounds.size.width);
    CGFloat h = MAX(navigationBar.bounds.size.height + navigationBar.frame.origin.y,
                    [self standardNavigationHeightInView:navigationBar]);
    UIImage *bg = [self loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    if (bg) {
        appearance.backgroundImage = bg;
        appearance.backgroundColor = [UIColor clearColor];
    } else {
        appearance.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    }
    appearance.shadowColor = [UIColor clearColor];
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [HQITFontHelper regularFontOfSize:14],
    };
    navigationBar.standardAppearance = appearance;
    navigationBar.scrollEdgeAppearance = appearance;
    navigationBar.compactAppearance = appearance;
    navigationBar.tintColor = [UIColor whiteColor];
    navigationBar.translucent = NO;
}

@end
