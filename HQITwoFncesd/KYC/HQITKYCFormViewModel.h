

#import <Foundation/Foundation.h>
#import "HQITKYCModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITKYCFormViewModel : NSObject

@property (nonatomic, copy, readonly) NSString *kycId;
@property (nonatomic, copy, readonly) NSArray<HQITKYCFormRow *> *rows;
@property (nonatomic, assign, readonly) BOOL isSubmitting;
@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onCommitSuccess)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);

- (instancetype)initWithKycId:(NSString *)kycId;
- (void)loadInit;
- (nullable NSString *)validateFormRows;
- (void)commit;
- (void)applySelectionForRow:(HQITKYCFormRow *)row key:(NSString *)key label:(NSString *)label;
- (void)applyInputForRow:(HQITKYCFormRow *)row text:(NSString *)text;
- (NSInteger)maxLengthForRow:(HQITKYCFormRow *)row;
- (NSString *)filterInput:(NSString *)text forRow:(HQITKYCFormRow *)row;
- (void)loadProvinceOptionsThen:(void (^)(NSArray<HQITKYCButtonOption *> *opts))completion;
- (void)loadCityOptionsForProvinceId:(NSString *)provinceId
                                then:(void (^)(NSArray<HQITKYCButtonOption *> *opts))completion;
- (nullable HQITKYCFormRow *)provinceRow;
- (void)clearCityRows;

@end

NS_ASSUME_NONNULL_END
