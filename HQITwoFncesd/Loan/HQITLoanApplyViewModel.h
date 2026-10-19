

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITLoanApplyDetailRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy, nullable) NSString *infoKey; // received / fee / interest
@property (nonatomic, assign) BOOL emphasized;
@end

@interface HQITLoanApplyViewModel : NSObject

@property (nonatomic, copy, readonly) NSString *productId;
@property (nonatomic, copy, readonly) NSString *productName;
@property (nonatomic, copy, nullable, readonly) NSString *productLogo;
@property (nonatomic, copy, readonly) NSArray<NSDictionary *> *amountList; // sorted desc
@property (nonatomic, assign, readonly) NSInteger selectedAmountIndex;
@property (nonatomic, assign, readonly) NSInteger selectedTermIndex;
@property (nonatomic, assign, readonly) BOOL isMultiAmount;
@property (nonatomic, assign, readonly) BOOL isMultiTerm;
@property (nonatomic, assign, readonly) BOOL isEMI;
@property (nonatomic, assign) BOOL agreed;
@property (nonatomic, assign, readonly) BOOL isSubmitting;
@property (nonatomic, copy, readonly) NSString *maskedBankAccount;
@property (nonatomic, copy, nullable, readonly) NSString *bankCardBindId;
@property (nonatomic, assign, readonly) NSInteger userType; // 2 = non-first

@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);
@property (nonatomic, copy, nullable) void (^onSubmitSuccess)(NSString *orderId);

- (instancetype)initWithProductId:(NSString *)productId
                         termData:(NSDictionary *)termData
               prefillProductName:(nullable NSString *)prefillName
            prefillProductLogoURL:(nullable NSString *)prefillLogo;

- (NSString *)displayAmountAtIndex:(NSInteger)index;
- (NSString *)currentLoanAmountRaw;
- (NSString *)currentShowTermRaw;
- (NSString *)currentTermDisplay;      // "120 Days" / "3 EMIS"
- (NSString *)termSelectTitle;         // "Select the loan term" / "Select EMIS"
- (NSArray<NSString *> *)termOptionLabels;
- (NSArray<HQITLoanApplyDetailRow *> *)detailRows;
- (NSString *)formattedLoanAmountDisplay;

- (void)selectAmountAtIndex:(NSInteger)index;
- (void)selectTermAtIndex:(NSInteger)index;
- (BOOL)applyDefaultAmountTermSelection;
- (void)submitWithLongitude:(NSString *)longitude latitude:(NSString *)latitude;
- (void)resetSubmittingState;

@end

NS_ASSUME_NONNULL_END
