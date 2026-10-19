
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITHomeVoidBlock)(void);
typedef void (^HQITHomeDialogChainBlock)(void);
typedef void (^HQITHomeRouteBlock)(NSString *route, NSDictionary * _Nullable info);

@interface HQITHomeProductItem : NSObject
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *productName;
@property (nonatomic, copy, nullable) NSString *productLogo;
@property (nonatomic, strong, nullable) id lowAmount;
@property (nonatomic, strong, nullable) id highAmount;
@property (nonatomic, copy, nullable) NSString *quotaDisplay; // formatted
@property (nonatomic, copy, nullable) NSString *interestRateDisplay; // e.g. 0.08%
@property (nonatomic, copy) NSArray<NSString *> *labels;
@property (nonatomic, strong) NSDictionary *raw;
@end

@interface HQITHomeVersionInfo : NSObject
@property (nonatomic, assign) BOOL needUpdate;
@property (nonatomic, assign) BOOL forceUpdate;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSString *latestVersion;
@property (nonatomic, copy, nullable) NSString *updateURL;
@end

@interface HQITHomeLoanViewModel : NSObject

@property (nonatomic, assign, readonly) NSInteger userStatus;
@property (nonatomic, copy, readonly) NSString *promptCopy;
@property (nonatomic, assign, readonly) BOOL showsHintArrow;
@property (nonatomic, assign, readonly) NSInteger progressActiveIndex; // 0..3
@property (nonatomic, copy, readonly, nullable) NSString *withdrawalOrderId;
@property (nonatomic, copy, readonly) NSArray<HQITHomeProductItem *> *products;
@property (nonatomic, strong, readonly, nullable) HQITHomeVersionInfo *versionInfo;
@property (nonatomic, assign, readonly) BOOL showsKYCEmptyState; // status==10 / guest
@property (nonatomic, assign, readonly) BOOL showsProductList;
/// hasOrder==0 && userStatus==20 && firstLoanOptionLine==system
@property (nonatomic, assign, readonly) BOOL isAutoOrderEligible;
@property (nonatomic, copy, readonly) NSString *homeActionButtonTitle;
@property (nonatomic, copy, readonly) NSString *maxApplyAmountDisplay;

@property (nonatomic, copy, nullable) HQITHomeVoidBlock onUpdated;
@property (nonatomic, copy, nullable) HQITHomeVoidBlock onNeedLogin;
@property (nonatomic, copy, nullable) HQITHomeDialogChainBlock onPipelineFinishedForDialogs;
@property (nonatomic, copy, nullable) HQITHomeRouteBlock onRoute;

- (void)reloadForCurrentSession;
- (void)syncUserInfoOnHomeEnter;
- (BOOL)ensureLoggedInOrPrompt;
- (void)handleHintTapped;
- (void)handleApplyTapped;
- (void)handleContactUsTapped;
- (void)handleBankAccountTapped;
- (void)handleProductApplyTapped:(HQITHomeProductItem *)product;
- (void)handleWithdrawalConfirm;
- (BOOL)handleProductApplyAsAutoOrderIfNeeded;

@end

NS_ASSUME_NONNULL_END
