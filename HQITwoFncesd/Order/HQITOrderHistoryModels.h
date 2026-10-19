

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HQITOrderHistoryTab) {
    HQITOrderHistoryTabRepaymentDue = 0,      // orderStatus 20
    HQITOrderHistoryTabSubmitApplication = 1, // orderStatus 10
    HQITOrderHistoryTabProcessing = 2,        // orderStatus 30
    HQITOrderHistoryTabCompleted = 3,         // orderStatus 40
};

@interface HQITOrderHistoryItem : NSObject
@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, copy, nullable) NSString *productId;
@property (nonatomic, copy) NSString *productName;
@property (nonatomic, copy) NSString *amountText;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, copy) NSString *statusTitle;
@property (nonatomic, strong) UIColor *statusTextColor;
@property (nonatomic, strong) UIColor *statusBgColor;
@property (nonatomic, copy) NSString *leftDateLabel;
@property (nonatomic, copy) NSString *leftDateValue;
@property (nonatomic, copy) NSString *rightDateLabel;
@property (nonatomic, copy) NSString *rightDateValue;
@property (nonatomic, copy, nullable) NSString *orderDetailsLink;
@property (nonatomic, copy, nullable) NSString *rawJSONHint;
@end

@interface HQITOrderStatusStyle : NSObject
+ (void)applyStyleForStatusCode:(NSInteger)code
                          title:(NSString * _Nonnull * _Nonnull)outTitle
                      textColor:(UIColor * _Nonnull * _Nonnull)outText
                        bgColor:(UIColor * _Nonnull * _Nonnull)outBg;
+ (void)dateLabelsForStatusCode:(NSInteger)code
                      leftLabel:(NSString * _Nonnull * _Nonnull)outLeft
                     rightLabel:(NSString * _Nonnull * _Nonnull)outRight;
@end

NS_ASSUME_NONNULL_END
