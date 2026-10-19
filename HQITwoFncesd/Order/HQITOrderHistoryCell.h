

#import <UIKit/UIKit.h>
#import "HQITOrderHistoryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITOrderHistoryCell : UITableViewCell
+ (NSString *)reuseId;
+ (CGFloat)itemHeight;
+ (CGFloat)itemSpacing;
- (void)applyItem:(HQITOrderHistoryItem *)item;
@end

NS_ASSUME_NONNULL_END
