

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITCategoryText : NSObject

+ (void)saveCategoryConfig:(nullable id)config;
+ (nullable id)cachedCategoryConfig;

+ (NSString *)textForKey:(NSString *)key defaultText:(NSString *)defaultText;

@end

NS_ASSUME_NONNULL_END
