

#import "HQITAmountFormatter.h"

static NSString * const kHQITCurrency = @"₹";

@implementation HQITAmountFormatter

+ (NSNumberFormatter *)numberFormatter {
    static NSNumberFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSNumberFormatter alloc] init];
        fmt.numberStyle = NSNumberFormatterDecimalStyle;
        fmt.groupingSeparator = @",";
        fmt.usesGroupingSeparator = YES;
        fmt.maximumFractionDigits = 0;
        fmt.minimumFractionDigits = 0;
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_IN"];
    });
    return fmt;
}

+ (NSString *)digitsFrom:(id)amount {
    if (amount == nil || amount == [NSNull null]) return @"";
    NSString *s = [NSString stringWithFormat:@"%@", amount];
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if ((c >= '0' && c <= '9') || c == '.') {
            [digits appendFormat:@"%C", c];
        }
    }
    return digits;
}

+ (NSString *)formatPlainAmount:(id)amount prefixCurrency:(BOOL)prefixCurrency {
    NSString *digits = [self digitsFrom:amount];
    if (digits.length == 0) {
        return prefixCurrency ? [kHQITCurrency stringByAppendingString:@"0"] : @"0";
    }
    NSDecimalNumber *num = [NSDecimalNumber decimalNumberWithString:digits];
    if ([num isEqualToNumber:[NSDecimalNumber notANumber]]) {
        return prefixCurrency ? [kHQITCurrency stringByAppendingString:digits] : digits;
    }
    NSString *formatted = [[self numberFormatter] stringFromNumber:num] ?: digits;
    return prefixCurrency ? [kHQITCurrency stringByAppendingString:formatted] : formatted;
}

+ (NSString *)formatDisplay:(NSString *)raw {
    if (raw.length == 0) return @"";
    // Rate / percent: do not format
    if ([raw containsString:@"%"]) {
        return raw;
    }
    // Range forms
    NSString *sep = nil;
    if ([raw containsString:@"-"]) sep = @"-";
    else if ([raw containsString:@"~"]) sep = @"~";
    if (sep) {
        NSArray *parts = [raw componentsSeparatedByString:sep];
        if (parts.count == 2) {
            return [NSString stringWithFormat:@"%@-%@",
                    [self formatPlainAmount:parts[0] prefixCurrency:YES],
                    [self formatPlainAmount:parts[1] prefixCurrency:YES]];
        }
    }
    if ([raw containsString:kHQITCurrency] || [raw containsString:@"₱"] || [raw containsString:@"Rs"]) {
        NSString *digits = [self digitsFrom:raw];
        return [self formatPlainAmount:digits prefixCurrency:YES];
    }
    return [self formatPlainAmount:raw prefixCurrency:YES];
}

+ (NSString *)formatQuotaRangeLow:(id)low high:(id)high {
    return [NSString stringWithFormat:@"%@-%@",
            [self formatPlainAmount:low prefixCurrency:YES],
            [self formatPlainAmount:high prefixCurrency:YES]];
}

+ (nullable id)firstPositiveAmountAmong:(NSArray *)candidates {
    if (![candidates isKindOfClass:[NSArray class]]) return nil;
    for (id amount in candidates) {
        if (amount == nil || amount == [NSNull null]) continue;
        NSString *digits = [self digitsFrom:amount];
        if (digits.length == 0) continue;
        NSDecimalNumber *num = [NSDecimalNumber decimalNumberWithString:digits];
        if ([num isEqualToNumber:[NSDecimalNumber notANumber]]) continue;
        if ([num compare:[NSDecimalNumber zero]] == NSOrderedDescending) {
            return amount;
        }
    }
    return nil;
}

@end
