

#import "HQITBaseDialog.h"

@class HQITLoanApplyDetailRow;

NS_ASSUME_NONNULL_BEGIN

@interface HQITLoanDetailsDialog : HQITBaseDialog
- (void)configureWithRows:(NSArray<HQITLoanApplyDetailRow *> *)rows
                 onCancel:(nullable void (^)(void))onCancel;
@end

NS_ASSUME_NONNULL_END
