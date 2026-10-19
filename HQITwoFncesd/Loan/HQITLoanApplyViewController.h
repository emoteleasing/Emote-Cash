

#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITLoanApplyViewController : HQITBaseViewController

- (instancetype)initWithProductId:(NSString *)productId
                         termData:(NSDictionary *)termData
               prefillProductName:(nullable NSString *)prefillName
            prefillProductLogoURL:(nullable NSString *)prefillLogo;

@end

NS_ASSUME_NONNULL_END
