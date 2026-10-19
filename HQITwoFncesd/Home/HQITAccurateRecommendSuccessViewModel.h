

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITAccurateRecommendSuccessDetailRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy, nullable) NSString *infoKey;
@end

@interface HQITAccurateRecommendSuccessOrderItem : NSObject
@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, copy) NSString *productName;
@property (nonatomic, copy, nullable) NSString *productLogoURL;
@property (nonatomic, copy) NSString *statusTitle;
@property (nonatomic, strong) UIColor *statusTextColor;
@property (nonatomic, strong) UIColor *statusBgColor;
@property (nonatomic, copy) NSArray<HQITAccurateRecommendSuccessDetailRow *> *detailRows;
@end

@interface HQITAccurateRecommendSuccessViewModel : NSObject

@property (nonatomic, copy, readonly) NSArray<NSString *> *orderIds;
@property (nonatomic, copy, readonly) NSArray<HQITAccurateRecommendSuccessOrderItem *> *orders;
@property (nonatomic, assign, readonly) BOOL isLoading;
@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);

- (instancetype)initWithOrderIds:(NSArray<NSString *> *)orderIds;
- (void)loadAllOrderDetails;

@end

NS_ASSUME_NONNULL_END
