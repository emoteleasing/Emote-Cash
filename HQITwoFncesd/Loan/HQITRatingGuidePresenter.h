
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITRatingGuidePresenter : NSObject

+ (void)presentIfNeededForced:(BOOL)forced
                     userType:(NSInteger)userType
                       inView:(UIView *)hostView
                   completion:(void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
