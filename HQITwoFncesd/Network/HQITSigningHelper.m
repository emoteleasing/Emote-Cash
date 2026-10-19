

#import "HQITSigningHelper.h"
#import "HQITNetworkConstants.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation HQITSigningHelper

+ (NSString *)signValueString:(id)value {
    if (value == nil || value == [NSNull null]) {
        return @"";
    }
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *num = (NSNumber *)value;
        // Prefer integer-looking strings without scientific notation.
        if (strcmp(num.objCType, @encode(BOOL)) == 0 ||
            strcmp(num.objCType, @encode(char)) == 0) {
            return num.boolValue ? @"1" : @"0";
        }
        if (CFNumberIsFloatType((CFNumberRef)num)) {
            return [NSString stringWithFormat:@"%@", num];
        }
        return [NSString stringWithFormat:@"%@", num];
    }
    return [NSString stringWithFormat:@"%@", value];
}

+ (NSString *)coordinateSignValue:(double)value {
    return [@(value) stringValue];
}

+ (NSString *)generateNonce {
    static NSString * const chars = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *result = [NSMutableString stringWithCapacity:16];
    for (NSInteger i = 0; i < 16; i++) {
        uint32_t idx = arc4random_uniform((uint32_t)chars.length);
        [result appendFormat:@"%C", [chars characterAtIndex:idx]];
    }
    return result;
}

+ (NSString *)md5Uppercase:(NSString *)input {
    const char *cStr = [input UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
#pragma clang diagnostic pop
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02X", digest[i]];
    }
    return output;
}

+ (NSString *)hmacSHA256Hex:(NSString *)message key:(NSString *)key {
    const char *cKey = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [message cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

+ (NSString *)signWithBusinessValues:(NSArray<NSString *> *)businessValues
                       publicValues:(NSArray<NSString *> *)publicValues {
    NSMutableArray<NSString *> *all = [NSMutableArray array];
    for (NSString *v in businessValues) {
        [all addObject:v ?: @""];
    }
    for (NSString *v in publicValues) {
        [all addObject:v ?: @""];
    }
    NSArray<NSString *> *sorted = [all sortedArrayUsingSelector:@selector(compare:)];
    NSString *s1 = [sorted componentsJoinedByString:@"&"];
    NSString *s2 = [self md5Uppercase:s1];
    NSString *s3 = [s2 stringByAppendingString:HQITSalt];
    NSString *h = [self hmacSHA256Hex:s3 key:HQITSecretKey];
    NSString *prefix = h.length >= 32 ? [h substringToIndex:32] : h;
    return [prefix uppercaseString];
}

@end
