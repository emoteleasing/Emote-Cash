

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HQITKYCItemType) {
    HQITKYCItemTypeInput = 1,
    HQITKYCItemTypeLocalSelect = 3,
    HQITKYCItemTypeAPISelect = 4,
};

@interface HQITKYCButtonOption : NSObject
@property (nonatomic, copy) NSString *buttonKey;
@property (nonatomic, copy) NSString *buttonLabel;
@property (nonatomic, assign) NSInteger buttonSort;
@end

@interface HQITKYCFormRow : NSObject
@property (nonatomic, copy) NSString *itemCode;
@property (nonatomic, copy) NSString *itemName;
@property (nonatomic, assign) HQITKYCItemType itemType;
@property (nonatomic, assign) BOOL isRequired;
@property (nonatomic, assign) NSInteger itemSort;
@property (nonatomic, copy, nullable) NSString *regularExpression;
@property (nonatomic, assign) NSInteger maxLength;
@property (nonatomic, copy) NSArray<HQITKYCButtonOption *> *buttonList;
@property (nonatomic, copy, nullable) NSString *displayValue;
@property (nonatomic, copy, nullable) NSString *valueKey;
@property (nonatomic, copy, nullable) NSString *provinceId; // for city linkage
- (NSString *)commitValue;
- (NSString *)submitValue;
- (BOOL)isIndianMobileField;
- (BOOL)isEmailField;
- (BOOL)isWhatsAppField;
- (BOOL)isProvinceField;
- (BOOL)isCityField;
@end

@interface HQITKYCStepInfo : NSObject
@property (nonatomic, copy) NSString *kycId;
@property (nonatomic, assign) NSInteger kycSort;
@property (nonatomic, assign) NSInteger kycStatus; // 1 = done
@property (nonatomic, copy, nullable) NSString *kycType;
@end

@interface HQITKYCCommitItem : NSObject
@property (nonatomic, copy) NSString *itemCode;
@property (nonatomic, copy) NSString *itemValueType; // "1" text
@property (nonatomic, copy) NSString *itemValue;
- (NSDictionary *)toDictionary;
@end

NS_ASSUME_NONNULL_END
