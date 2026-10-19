

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITAmountFormatter : NSObject

+ (NSString *)formatPlainAmount:(id)amount prefixCurrency:(BOOL)prefixCurrency;

+ (NSString *)formatDisplay:(NSString *)raw;

+ (NSString *)formatQuotaRangeLow:(id)low high:(id)high;

+ (nullable id)firstPositiveAmountAmong:(NSArray *)candidates;

@end

NS_ASSUME_NONNULL_END
