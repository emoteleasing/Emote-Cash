

#import <UIKit/UIKit.h>

@class HQITAccurateRecommendSuccessOrderItem;

NS_ASSUME_NONNULL_BEGIN

@interface HQITAccurateRecommendSuccessOrderCell : UITableViewCell

@property (nonatomic, copy, nullable) void (^onInfoTap)(NSString *infoKey);

- (void)configureWithItem:(HQITAccurateRecommendSuccessOrderItem *)item;

@end

NS_ASSUME_NONNULL_END
