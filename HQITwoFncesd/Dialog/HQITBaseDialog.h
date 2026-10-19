
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HQITDialogPlacement) {
    HQITDialogPlacementBottom = 0,
    HQITDialogPlacementCenter = 1,
};

@interface HQITBaseDialog : UIView

@property (nonatomic, assign) BOOL allowBackgroundDismiss; // default NO
@property (nonatomic, copy, nullable) void (^onDismiss)(void);
@property (nonatomic, strong, readonly) UIView *cardView;

- (void)showInView:(UIView *)hostView placement:(HQITDialogPlacement)placement;
- (void)dismissAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
