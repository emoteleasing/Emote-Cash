

#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HQITFeedbackExitStyle) {
    HQITFeedbackExitPopOne = 0,
    HQITFeedbackExitPopToNavRoot = 1,
};

@interface HQITFeedbackViewController : HQITBaseViewController

@property (nonatomic, assign, readonly) HQITFeedbackExitStyle exitStyle;
@property (nonatomic, assign) BOOL presentRatingGuideOnEnter;

- (instancetype)initWithExitStyle:(HQITFeedbackExitStyle)exitStyle;

@end

NS_ASSUME_NONNULL_END
