

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HQITOrderDetailModels.h"
#import "HQITBankAccountViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITOrderDetailViewModel : NSObject

- (instancetype)initWithOrderId:(NSString *)orderId productId:(nullable NSString *)productId;

@property (nonatomic, copy, readonly) NSString *inputOrderId;
@property (nonatomic, copy, readonly, nullable) NSString *inputProductId;

@property (nonatomic, copy, readonly) NSString *productName;
@property (nonatomic, copy, readonly, nullable) NSString *productLogo;
@property (nonatomic, copy, readonly, nullable) NSString *productId;

@property (nonatomic, assign, readonly) NSInteger orderStatus;
@property (nonatomic, copy, readonly) NSString *statusTitle;
@property (nonatomic, strong, readonly) UIColor *statusTextColor;
@property (nonatomic, strong, readonly) UIColor *statusBgColor;

@property (nonatomic, copy, readonly) NSString *loanAmountDisplay;
@property (nonatomic, copy, readonly, nullable) NSString *emisDisplay; // nil → hide EMI summary
@property (nonatomic, copy, readonly, nullable) NSString *maskedBankAccount; // nil → hide bank card

@property (nonatomic, copy, readonly) NSArray<HQITOrderDetailRow *> *detailRows;
@property (nonatomic, copy, readonly) NSString *tipPrimary;
@property (nonatomic, copy, readonly, nullable) NSString *tipSecondary; // 60/61 only

@property (nonatomic, assign, readonly) HQITOrderDetailAction primaryAction;
@property (nonatomic, copy, readonly, nullable) NSString *primaryButtonTitle;
@property (nonatomic, assign, readonly) HQITOrderDetailAction secondaryAction;
@property (nonatomic, copy, readonly, nullable) NSString *secondaryButtonTitle;

/// Prefer orderDetail.orderId, else input (not "1").
@property (nonatomic, copy, readonly, nullable) NSString *resolvedOrderId;

/// Raw numbers for withdrawal apply (no ₹ / commas).
@property (nonatomic, copy, readonly, nullable) NSString *loanAmountRaw;
@property (nonatomic, copy, readonly, nullable) NSString *loanTermRaw;

/// For Change Bank Account (status 36)
@property (nonatomic, strong, readonly, nullable) HQITBankAccountItem *bankAccountItem;

@property (nonatomic, assign, readonly) BOOL isLoading;
@property (nonatomic, assign) BOOL isActionBusy;

@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);

- (void)loadDetail;

/// Repay / Defer → connect URL. onSuccess(url) / onFailure(message).
- (void)requestPaymentLinkForAction:(HQITOrderDetailAction)action
                          onSuccess:(void (^)(NSString *urlString))onSuccess
                          onFailure:(void (^)(NSString *message))onFailure;

/// Status 32 Withdraw → `/app/v3/order/apply/withdrawal`
- (void)requestWithdrawalOnSuccess:(void (^)(void))onSuccess
                         onFailure:(void (^)(NSString *message))onFailure;

@end

NS_ASSUME_NONNULL_END
