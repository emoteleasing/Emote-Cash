

#import <Foundation/Foundation.h>
#import "HQITEMIModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITEMICalculator : NSObject

+ (NSInteger)minAmount;
+ (NSInteger)maxAmount;
+ (NSInteger)minDuration;
+ (NSInteger)maxDuration;
+ (NSInteger)minInterestRate;
+ (NSInteger)maxInterestRate;

+ (NSInteger)defaultAmount;
+ (NSInteger)defaultDuration;
+ (NSInteger)defaultInterestRate;

+ (HQITEMIResultModel *)calculateWithInput:(HQITEMIInputModel *)input;

+ (nullable NSString *)validateInput:(HQITEMIInputModel *)input;

+ (NSString *)formatIntegerIndian:(NSInteger)value;

+ (NSString *)formatCurrency:(double)value;

@end

NS_ASSUME_NONNULL_END
