

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITAppConfigHelper : NSObject

+ (BOOL)isRejectH5Configured;

+ (nullable NSString *)rejectH5URLString;

+ (nullable NSString *)fixedLocalWebURLForConfigKey:(NSString *)key;

+ (NSString *)fixedCustomerServiceEmail;

+ (NSString *)fixedOfficialWebsiteURL;

/// Read href/string from app config cache (data.* or root).
+ (nullable NSString *)stringForHrefConfigKey:(NSString *)key;

+ (nullable NSString *)normalizeURLString:(NSString *)raw;

/// Integer from app config / dynamicParameter (default if missing).
+ (NSInteger)integerForConfigKey:(NSString *)key defaultValue:(NSInteger)defaultValue;

/// feedbackGuidance / feedback_guidance → 0/1/2
+ (NSInteger)feedbackGuidanceMode;

@end

NS_ASSUME_NONNULL_END
