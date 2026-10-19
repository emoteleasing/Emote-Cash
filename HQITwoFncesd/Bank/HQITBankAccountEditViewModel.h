
#import <Foundation/Foundation.h>
#import "HQITKYCModels.h"
#import "HQITBankAccountViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITBankAccountEditViewModel : NSObject

@property (nonatomic, copy, readonly) NSArray<HQITKYCFormRow *> *rows;
@property (nonatomic, assign, readonly) BOOL isSubmitting;
@property (nonatomic, strong, readonly) HQITBankAccountItem *account;

@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onCommitSuccess)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);

- (instancetype)initWithAccount:(HQITBankAccountItem *)account;
- (void)loadInit;
- (void)applyInputForRow:(HQITKYCFormRow *)row text:(NSString *)text;
- (void)applyIFSCCode:(NSString *)code;
- (NSInteger)maxLengthForRow:(HQITKYCFormRow *)row;
- (NSString *)filterInput:(NSString *)text forRow:(HQITKYCFormRow *)row;
- (BOOL)isAccountNameRow:(HQITKYCFormRow *)row;
- (void)commit;

@end

NS_ASSUME_NONNULL_END
