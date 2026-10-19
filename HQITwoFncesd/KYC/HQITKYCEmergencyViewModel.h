

#import <Foundation/Foundation.h>
#import "HQITKYCModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITKYCEmergencyGroup : NSObject
@property (nonatomic, assign) NSInteger groupNo; // 1-based
@property (nonatomic, strong, nullable) HQITKYCFormRow *relationRow;
@property (nonatomic, strong, nullable) HQITKYCFormRow *nameRow;
@property (nonatomic, strong, nullable) HQITKYCFormRow *phoneRow;
- (NSString *)sectionTitle;
- (BOOL)isCompletelyEmpty;
@end

@interface HQITKYCEmergencyViewModel : NSObject

@property (nonatomic, copy, readonly) NSString *kycId;
@property (nonatomic, copy, readonly) NSArray<HQITKYCEmergencyGroup *> *groups;
@property (nonatomic, strong, readonly, nullable) HQITKYCFormRow *emailRow;
@property (nonatomic, copy, readonly) NSArray<HQITKYCFormRow *> *rows;
@property (nonatomic, assign, readonly) BOOL isSubmitting;

@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onCommitSuccess)(void);
@property (nonatomic, copy, nullable) void (^onErrorMessage)(NSString *message);

- (instancetype)initWithKycId:(NSString *)kycId;
- (void)loadInit;
- (void)applyRelation:(HQITKYCFormRow *)row key:(NSString *)key label:(NSString *)label;
- (void)applyEmail:(NSString *)text;
- (void)clearNamePhoneForGroup:(HQITKYCEmergencyGroup *)group;
- (nullable NSString *)validateAndApplyContactName:(NSString *)name
                                            phone:(NSString *)phone
                                          forGroup:(HQITKYCEmergencyGroup *)group;
- (NSString *)displayPhoneForRow:(HQITKYCFormRow *)phoneRow;
- (void)commit;

@end

NS_ASSUME_NONNULL_END
