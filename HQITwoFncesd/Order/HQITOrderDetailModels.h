
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITOrderDetailRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy, nullable) NSString *infoKey; // received / fee / interest
@end

typedef NS_ENUM(NSInteger, HQITOrderDetailAction) {
    HQITOrderDetailActionNone = 0,
    HQITOrderDetailActionContinueSubmitting,
    HQITOrderDetailActionWithdraw,
    HQITOrderDetailActionChangeBank,
    HQITOrderDetailActionDefer,
    HQITOrderDetailActionRepay,
};

NS_ASSUME_NONNULL_END
