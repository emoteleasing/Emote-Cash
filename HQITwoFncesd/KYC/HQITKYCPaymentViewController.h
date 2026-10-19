

#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITKYCPaymentViewController : HQITBaseViewController

- (instancetype)initWithKycId:(NSString *)kycId
                    pageTitle:(NSString *)pageTitle
             isLastUnfinished:(BOOL)isLastUnfinished;

@end

NS_ASSUME_NONNULL_END
