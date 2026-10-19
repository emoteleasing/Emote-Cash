

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITSigningHelper : NSObject

/// Convert any value to sign string. nil / NSNull -> @"".
+ (NSString *)signValueString:(nullable id)value;

/// Format coordinate string without truncating decimal places (for body + signing).
+ (NSString *)coordinateSignValue:(double)value;

/// Generate 16-char random nonce.
+ (NSString *)generateNonce;

/// Method 2 signature.
/// @param businessValues signed business values only (already stringified)
/// @param publicValues values for appId/deviceId/channel/nonce/version/clientTime/os
+ (NSString *)signWithBusinessValues:(NSArray<NSString *> *)businessValues
                       publicValues:(NSArray<NSString *> *)publicValues;

@end

NS_ASSUME_NONNULL_END
