

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HQITLoanApplyViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITWithdrawOrderDetailViewModel : NSObject

- (instancetype)initWithOrderId:(NSString *)orderId productId:(nullable NSString *)productId;

@property (nonatomic, copy, readonly) NSString *inputOrderId;
@property (nonatomic, copy, readonly, nullable) NSString *inputProductId;
@property (nonatomic, copy, readonly, nullable) NSString *resolvedOrderId;
@property (nonatomic, copy, readonly, nullable) NSString *productId;

@property (nonatomic, copy, readonly) NSString *productName;
@property (nonatomic, copy, readonly, nullable) NSString *productLogo;
@property (nonatomic, copy, readonly) NSString *statusTitle;
@property (nonatomic, strong, readonly) UIColor *statusTextColor;
@property (nonatomic, strong, readonly) UIColor *statusBgColor;
@property (nonatomic, copy, readonly) NSString *tipText;
@property (nonatomic, copy, readonly, nullable) NSString *maskedBankAccount;

@property (nonatomic, copy, readonly) NSArray<NSDictionary *> *amountList;
@property (nonatomic, assign, readonly) NSInteger selectedAmountIndex;
@property (nonatomic, assign, readonly) NSInteger selectedTermIndex;
@property (nonatomic, assign, readonly) BOOL isMultiAmount;
@property (nonatomic, assign, readonly) BOOL isMultiTerm;
@property (nonatomic, assign, readonly) BOOL isEMI;

@property (nonatomic, assign, readonly) BOOL isLoading;
@property (nonatomic, assign, readonly) BOOL isSubmitting;

@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);
@property (nonatomic, copy, nullable) void (^onWithdrawSuccess)(void);

- (void)loadDetail;
- (void)selectAmountAtIndex:(NSInteger)index;
- (void)selectTermAtIndex:(NSInteger)index;

- (NSString *)displayAmountAtIndex:(NSInteger)index;
- (NSString *)currentLoanAmountRaw;
- (NSString *)currentLoanTermRaw;
- (NSString *)currentShowTermRaw;
- (NSString *)currentTermDisplay;
- (NSString *)termSelectTitle;
- (NSArray<NSString *> *)termOptionLabels;
- (NSArray<HQITLoanApplyDetailRow *> *)detailRows;

- (void)submitWithdrawal;

@end

NS_ASSUME_NONNULL_END
