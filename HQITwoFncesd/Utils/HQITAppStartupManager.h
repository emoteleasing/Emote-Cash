
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITStartupCompletion)(BOOL success);

@interface HQITAppStartupManager : NSObject

+ (instancetype)shared;

- (void)performStartupSequence;
- (void)performStartupSequenceWithCompletion:(nullable HQITStartupCompletion)completion;

- (nullable id)configValueForKey:(NSString *)key;

- (NSInteger)retrieveMobileContactMode;
/// YES when retrieveMobileContact == 1 or == 2 (force); 0 = non-force.
- (BOOL)isForceContactMode;

- (void)ensureAppConfigThen:(void (^)(void))completion;
/// Always re-fetch `/app/v3/app/config` and overwrite memory + disk cache, then call completion.
- (void)refreshAppConfigThen:(void (^)(void))completion;

- (nullable NSDictionary *)cachedAppConfig;
- (void)saveAppConfig:(nullable id)config;

@end

NS_ASSUME_NONNULL_END
