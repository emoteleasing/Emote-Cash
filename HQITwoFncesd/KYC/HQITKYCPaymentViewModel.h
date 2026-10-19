

#import <Foundation/Foundation.h>
#import "HQITKYCModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITKYCPaymentViewModel : NSObject

@property (nonatomic, copy, readonly) NSString *kycId;
@property (nonatomic, copy, readonly) NSArray<HQITKYCFormRow *> *rows;
@property (nonatomic, assign, readonly) BOOL isSubmitting;

@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onCommitSuccess)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);

- (instancetype)initWithKycId:(NSString *)kycId;
- (void)loadInit;
- (void)applyInputForRow:(HQITKYCFormRow *)row text:(NSString *)text;
- (void)applyIFSCCode:(NSString *)code;
- (NSInteger)maxLengthForRow:(HQITKYCFormRow *)row;
- (NSString *)filterInput:(NSString *)text forRow:(HQITKYCFormRow *)row;
- (nullable HQITKYCFormRow *)rowForCode:(NSString *)code;
- (BOOL)isAccountNameRow:(HQITKYCFormRow *)row;
- (void)commit;

@end

NS_ASSUME_NONNULL_END
