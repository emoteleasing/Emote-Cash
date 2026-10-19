

#import <UIKit/UIKit.h>

@class HQITAccurateRecommendProductItem;

NS_ASSUME_NONNULL_BEGIN

@interface HQITAccurateRecommendProductCell : UITableViewCell

@property (nonatomic, copy, nullable) void (^onToggleSelect)(void);
@property (nonatomic, copy, nullable) void (^onAmountStepChanged)(NSInteger stepIndex);
@property (nonatomic, copy, nullable) void (^onTermSelect)(void);
@property (nonatomic, copy, nullable) void (^onLoanDetails)(void);

- (void)configureWithItem:(HQITAccurateRecommendProductItem *)item;

@end

NS_ASSUME_NONNULL_END
