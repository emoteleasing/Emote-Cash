

#import <Foundation/Foundation.h>

@class HQITLoanApplyDetailRow;

NS_ASSUME_NONNULL_BEGIN

@interface HQITAccurateRecommendProductItem : NSObject
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *productName;
@property (nonatomic, copy, nullable) NSString *productLogo;
@property (nonatomic, copy) NSArray<NSDictionary *> *amountSteps; // ascending loanAmount
@property (nonatomic, assign) NSInteger selectedAmountIndex;
@property (nonatomic, assign) NSInteger selectedTermIndex;
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, strong, nullable) NSDictionary *bankCard;

- (NSInteger)amountStepCount;
- (double)loanAmountAtIndex:(NSInteger)idx;
- (NSDictionary *)currentAmountDetail;
- (NSDictionary *)currentTermDetail;
- (NSString *)displayLoanAmount;
- (NSString *)displayMaxLoanAmount;
- (NSString *)displayArrivalAmount;
- (NSString *)displayRepaymentTerm;
- (BOOL)isEMI;
- (BOOL)isMultiTerm;
- (NSString *)termSelectTitle;
- (NSString *)termRowTitle;
- (NSString *)currentTermDisplay;
- (NSArray<NSString *> *)termOptionLabels;
- (double)currentFeeAmount;
- (double)currentArrivalAmountValue;
- (double)currentLoanAmountValue;
- (NSString *)currentLoanAmountRaw;
- (NSString *)currentShowTermRaw;
- (void)applyHighestTermForCurrentAmount;
- (void)selectTermAtIndex:(NSInteger)index;
- (NSArray<HQITLoanApplyDetailRow *> *)loanDetailRows;
@end

@interface HQITAccurateRecommendViewModel : NSObject

@property (nonatomic, copy, readonly) NSArray<HQITAccurateRecommendProductItem *> *products;
@property (nonatomic, assign) BOOL agreed;
@property (nonatomic, assign, readonly) BOOL isSubmitting;
@property (nonatomic, copy, readonly) NSString *maskedBankAccount;
@property (nonatomic, assign, readonly) BOOL hasBankCard;
@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);
@property (nonatomic, copy, nullable) void (^onSubmitSuccess)(NSArray<NSString *> *orderIds);

- (instancetype)initWithRecommendData:(id)data;
+ (BOOL)hasProductsInRecommendData:(id)data;

- (void)selectAllProductsWithMaxAmountAndHighestTerm;

- (void)toggleProductSelectedAtIndex:(NSInteger)index;
- (void)setAmountStepIndex:(NSInteger)stepIndex forProductAtIndex:(NSInteger)productIndex;
- (void)selectTermAtIndex:(NSInteger)termIndex forProductAtIndex:(NSInteger)productIndex;

- (NSString *)totalAmountDisplay;
- (NSString *)totalFeeDisplay;
- (NSString *)totalArrivalDisplay;
- (NSInteger)selectedProductCount;
- (BOOL)canApply;
- (HQITAccurateRecommendProductItem * _Nullable)firstSelectedProduct;
- (void)submitWithLongitude:(NSString *)longitude latitude:(NSString *)latitude;
- (void)resetSubmittingState;

@end

NS_ASSUME_NONNULL_END
