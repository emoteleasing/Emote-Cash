

#import "HQITCategoryText.h"
#import "HQITStorageKeys.h"

@implementation HQITCategoryText

+ (void)saveCategoryConfig:(id)config {
    if (!config) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:0 error:nil];
    if (data) {
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:HQITStorageKeyCategoryConfig];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (id)cachedCategoryConfig {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:HQITStorageKeyCategoryConfig];
    if (![data isKindOfClass:[NSData class]]) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

+ (NSString *)lookup:(id)node key:(NSString *)key {
    if ([node isKindOfClass:[NSDictionary class]]) {
        id direct = ((NSDictionary *)node)[key];
        if ([direct isKindOfClass:[NSString class]] && [direct length] > 0) {
            return direct;
        }
        for (id value in [(NSDictionary *)node allValues]) {
            NSString *found = [self lookup:value key:key];
            if (found.length > 0) return found;
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)node) {
            NSString *found = [self lookup:item key:key];
            if (found.length > 0) return found;
        }
    }
    return nil;
}

+ (NSString *)textForKey:(NSString *)key defaultText:(NSString *)defaultText {
    id cached = [self cachedCategoryConfig];
    NSString *found = [self lookup:cached key:key];
    return found.length > 0 ? found : (defaultText ?: @"");
}

@end
