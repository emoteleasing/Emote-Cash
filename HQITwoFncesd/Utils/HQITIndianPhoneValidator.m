

#import "HQITIndianPhoneValidator.h"

NSString * const HQITPhoneErrorEmpty = @"Kindly provide your mobile number";
NSString * const HQITPhoneErrorInvalid = @"Kindly provide a valid phone number";

@implementation HQITIndianPhoneValidator

+ (NSString *)digitsOnly:(NSString *)input {
    if (input.length == 0) return @"";
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < input.length; i++) {
        unichar c = [input characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [out appendFormat:@"%C", c];
        }
    }
    return out;
}

+ (NSInteger)maxLengthForDigits:(NSString *)digits {
    if (digits.length == 0) return 11;
    unichar first = [digits characterAtIndex:0];
    if (first == '0') return 11;
    return 10;
}

+ (BOOL)isValidIndianMobile:(NSString *)input {
    return [self normalizedIndianMobileFrom:input].length == 10;
}

+ (NSString *)normalizedIndianMobileFrom:(NSString *)input {
    NSString *digits = [self digitsOnly:input];
    // 13-digit 910[6-9]xxxxxxxxx → drop 910
    if (digits.length == 13 && [digits hasPrefix:@"910"]) {
        unichar c = [digits characterAtIndex:3];
        if (c >= '6' && c <= '9') {
            digits = [digits substringFromIndex:3];
        }
    }
    // 12-digit 91[6-9]xxxxxxxxx → drop 91
    if (digits.length == 12 && [digits hasPrefix:@"91"]) {
        unichar c = [digits characterAtIndex:2];
        if (c >= '6' && c <= '9') {
            digits = [digits substringFromIndex:2];
        }
    }
    // 11-digit 0[6-9]xxxxxxxxx → drop leading 0
    if (digits.length == 11 && [digits hasPrefix:@"0"]) {
        unichar second = [digits characterAtIndex:1];
        if (second >= '6' && second <= '9') {
            digits = [digits substringFromIndex:1];
        } else {
            return nil;
        }
    }
    if (digits.length != 10) return nil;
    unichar first = [digits characterAtIndex:0];
    if (first < '6' || first > '9') return nil;
    return digits;
}

+ (NSString *)validationMessageForInput:(NSString *)input allowEmpty:(BOOL)allowEmpty {
    NSString *digits = [self digitsOnly:input];
    if (digits.length == 0) {
        return allowEmpty ? nil : HQITPhoneErrorEmpty;
    }
    if (![self isValidIndianMobile:digits]) {
        return HQITPhoneErrorInvalid;
    }
    return nil;
}

@end
