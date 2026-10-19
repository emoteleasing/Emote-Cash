

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const HQITPhoneErrorEmpty;
FOUNDATION_EXPORT NSString * const HQITPhoneErrorInvalid;

@interface HQITIndianPhoneValidator : NSObject

+ (NSString *)digitsOnly:(NSString *)input;

+ (NSInteger)maxLengthForDigits:(NSString *)digits;

+ (BOOL)isValidIndianMobile:(NSString *)input;

+ (nullable NSString *)normalizedIndianMobileFrom:(NSString *)input;

+ (nullable NSString *)validationMessageForInput:(NSString *)input allowEmpty:(BOOL)allowEmpty;

@end

NS_ASSUME_NONNULL_END
