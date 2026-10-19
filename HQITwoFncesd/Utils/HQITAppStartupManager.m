

#import "HQITAppStartupManager.h"
#import "HQITDomainManager.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkConstants.h"
#import "HQITStorageKeys.h"
#import "HQITCategoryText.h"
#import "HQITIDFAAdjustCoordinator.h"

@interface HQITAppStartupManager ()
@property (nonatomic, assign) BOOL running;
@property (nonatomic, strong) NSMutableArray<HQITStartupCompletion> *waiters;
@property (nonatomic, copy, nullable) NSDictionary *memoryAppConfig;
@end

@implementation HQITAppStartupManager

+ (instancetype)shared {
    static HQITAppStartupManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HQITAppStartupManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _waiters = [NSMutableArray array];
    }
    return self;
}

- (void)performStartupSequence {
    [self performStartupSequenceWithCompletion:nil];
}

- (void)performStartupSequenceWithCompletion:(HQITStartupCompletion)completion {
    if (completion) {
        @synchronized (self) {
            [self.waiters addObject:[completion copy]];
        }
    }
    @synchronized (self) {
        if (self.running) {
            return;
        }
        self.running = YES;
    }

    NSLog(@"%@ startup sequence begin", HQITLogTag);
    [[HQITDomainManager shared] ensureDomainReady:^(BOOL ok, NSString *baseURL, NSError *error) {
        if (!ok) {
            NSLog(@"%@ startup domain fail: %@", HQITLogTag, error);
            [self finishStartup:NO];
            // Still try Adjust with cached token if any
            [[HQITIDFAAdjustCoordinator shared] initializeAdjustIfNeeded];
            return;
        }
        [self fetchAppConfigThenCategory];
    }];
}

- (void)fetchAppConfigThenCategory {
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/app/config"
                                         signedData:nil
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        id payload = response.data;
        if (payload == nil && [response.rawDictionary isKindOfClass:[NSDictionary class]]) {
            payload = response.rawDictionary[@"data"];
        }
        NSLog(@"%@ app/config RESP dataClass=%@ rawKeys=%@ dataKeys=%@",
              HQITLogTag,
              NSStringFromClass([payload class]) ?: @"nil",
              [response.rawDictionary isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)response.rawDictionary allKeys] : @[],
              [payload isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)payload allKeys] : @[]);
        [self saveAppConfig:payload];
        id rmc = [self configValueForKey:@"retrieveMobileContact"];
        NSLog(@"%@ app/config ok retrieveMobileContact=%@ (memory=%@)",
              HQITLogTag, rmc, self.memoryAppConfig[@"retrieveMobileContact"]);
        if (rmc == nil) {
            NSLog(@"%@ WARNING: retrieveMobileContact missing after app/config — force mode will be OFF. payload=%@",
                  HQITLogTag, payload);
        }
        [self fetchCategoryConfig];
    } failure:^(NSError *error, NSString *message) {
        NSLog(@"%@ app/config fail: %@ (cached retrieveMobileContact=%@)",
              HQITLogTag, message, [self configValueForKey:@"retrieveMobileContact"]);
        [self fetchCategoryConfig];
    }];
}

- (void)fetchCategoryConfig {
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/category/gory"
                                         signedData:nil
                                       unsignedData:@{@"categoryStr": @"a888"}
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        [HQITCategoryText saveCategoryConfig:response.data];
        NSLog(@"%@ category/gory ok", HQITLogTag);
        [[HQITIDFAAdjustCoordinator shared] initializeAdjustIfNeeded];
        [self finishStartup:YES];
    } failure:^(NSError *error, NSString *message) {
        NSLog(@"%@ category/gory fail: %@", HQITLogTag, message);
        [[HQITIDFAAdjustCoordinator shared] initializeAdjustIfNeeded];
        [self finishStartup:NO];
    }];
}

- (void)finishStartup:(BOOL)success {
    NSArray<HQITStartupCompletion> *blocks;
    @synchronized (self) {
        self.running = NO;
        blocks = [self.waiters copy];
        [self.waiters removeAllObjects];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (HQITStartupCompletion block in blocks) {
            block(success);
        }
    });
}

- (NSDictionary *)normalizedAppConfigDict:(id)config {
    if (![config isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *dict = (NSDictionary *)config;
    id nested = dict[@"data"];
    if ([nested isKindOfClass:[NSDictionary class]] &&
        (dict[@"resultCode"] != nil || dict[@"resultMsg"] != nil || dict[@"timestamp"] != nil)) {
        return (NSDictionary *)nested;
    }
    return dict;
}

- (void)saveAppConfig:(id)config {
    if (!config) {
        NSLog(@"%@ saveAppConfig skipped: data is nil", HQITLogTag);
        return;
    }
    NSDictionary *toStore = [self normalizedAppConfigDict:config];
    if (!toStore) {
        if (![NSJSONSerialization isValidJSONObject:config]) {
            NSLog(@"%@ saveAppConfig skipped: invalid JSON object %@", HQITLogTag, config);
            return;
        }
        NSData *raw = [NSJSONSerialization dataWithJSONObject:config options:0 error:nil];
        if (raw) {
            [[NSUserDefaults standardUserDefaults] setObject:raw forKey:HQITStorageKeyAppConfig];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        NSLog(@"%@ saveAppConfig stored non-dict payload class=%@", HQITLogTag, NSStringFromClass([config class]));
        return;
    }
    if (![NSJSONSerialization isValidJSONObject:toStore]) {
        NSLog(@"%@ saveAppConfig skipped: invalid JSON object %@", HQITLogTag, toStore);
        return;
    }
    self.memoryAppConfig = [toStore copy];
    NSData *data = [NSJSONSerialization dataWithJSONObject:toStore options:0 error:nil];
    if (!data) return;
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:HQITStorageKeyAppConfig];
    [[NSUserDefaults standardUserDefaults] synchronize];
    id rmc = [self lookupValue:toStore key:@"retrieveMobileContact"];
    id wire = [self lookupValue:toStore key:@"commission"];
    NSLog(@"%@ saveAppConfig keysCount=%lu retrieveMobileContact=%@ commission(wire)=%@",
          HQITLogTag, (unsigned long)toStore.count, rmc, wire);
}

- (NSDictionary *)cachedAppConfig {
    if (self.memoryAppConfig.count > 0) {
        return self.memoryAppConfig;
    }
    id raw = [[NSUserDefaults standardUserDefaults] objectForKey:HQITStorageKeyAppConfig];
    NSDictionary *dict = nil;
    if ([raw isKindOfClass:[NSData class]]) {
        id obj = [NSJSONSerialization JSONObjectWithData:(NSData *)raw options:0 error:nil];
        dict = [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
    } else if ([raw isKindOfClass:[NSDictionary class]]) {
        dict = (NSDictionary *)raw;
    }
    if (!dict) {
        NSLog(@"%@ cachedAppConfig empty rawClass=%@", HQITLogTag, NSStringFromClass([raw class]) ?: @"nil");
        return nil;
    }
    NSDictionary *normalized = [self normalizedAppConfigDict:dict] ?: dict;
    self.memoryAppConfig = [normalized copy];
    return normalized;
}

- (id)lookupExactKey:(NSString *)key inNode:(id)node {
    if (key.length == 0 || !node) return nil;
    if ([node isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)node) {
            id found = [self lookupExactKey:key inNode:item];
            if (found) return found;
        }
        return nil;
    }
    if (![node isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *dict = (NSDictionary *)node;
    id direct = dict[key];
    if (direct != nil && direct != [NSNull null]) return direct;
    for (id value in dict.allValues) {
        id found = [self lookupExactKey:key inNode:value];
        if (found) return found;
    }
    return nil;
}

- (id)lookupValue:(id)node key:(NSString *)key {
    if (![node isKindOfClass:[NSDictionary class]]) {
        if ([node isKindOfClass:[NSArray class]]) {
            for (id item in (NSArray *)node) {
                id found = [self lookupValue:item key:key];
                if (found) return found;
            }
        }
        return nil;
    }
    NSDictionary *dict = (NSDictionary *)node;
    id direct = dict[key];
    if (direct != nil && direct != [NSNull null]) {
        return direct;
    }
    // Common wire aliases for adjust token
    if ([key isEqualToString:@"adjustToken"]) {
        id alt = dict[@"adjustKey"] ?: dict[@"adjust_token"];
        if (alt != nil && alt != [NSNull null]) return alt;
    }
    for (id value in dict.allValues) {
        id found = [self lookupValue:value key:key];
        if (found) return found;
    }
    return nil;
}

- (id)configValueForKey:(NSString *)key {
    if (key.length == 0) return nil;
    NSDictionary *cfg = [self cachedAppConfig];
    // retrieveMobileContact: prefer exact key anywhere; only then fall back to wire alias `commission`
    // (avoid treating unrelated top-level commission as force=1 when exact key is 0 nested).
    if ([key isEqualToString:@"retrieveMobileContact"]) {
        id exact = [self lookupExactKey:@"retrieveMobileContact" inNode:cfg];
        if (exact != nil) return exact;
        return [self lookupExactKey:@"commission" inNode:cfg];
    }
    return [self lookupValue:cfg key:key];
}

- (NSInteger)retrieveMobileContactMode {
    id v = [self configValueForKey:@"retrieveMobileContact"];
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v integerValue];
    return 0;
}

- (BOOL)isForceContactMode {
    // Force when retrieveMobileContact == 1 or == 2; only 0 (and other) is non-force.
    NSInteger mode = [self retrieveMobileContactMode];
    return mode == 1 || mode == 2;
}

- (void)ensureAppConfigThen:(void (^)(void))completion {
    if (!completion) return;
    void (^finish)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    };
    if ([self cachedAppConfig].count > 0) {
        NSLog(@"%@ ensureAppConfig hit cache retrieveMobileContact=%@",
              HQITLogTag, [self configValueForKey:@"retrieveMobileContact"]);
        finish();
        return;
    }
    @synchronized (self) {
        if (self.running) {
            NSLog(@"%@ ensureAppConfig wait startup", HQITLogTag);
            [self.waiters addObject:[^(BOOL success) {
                (void)success;
                finish();
            } copy]];
            return;
        }
    }
    NSLog(@"%@ ensureAppConfig fetch /app/v3/app/config", HQITLogTag);
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/app/config"
                                         signedData:nil
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        id payload = response.data;
        if (payload == nil && [response.rawDictionary isKindOfClass:[NSDictionary class]]) {
            payload = response.rawDictionary[@"data"];
        }
        [self saveAppConfig:payload];
        NSLog(@"%@ ensureAppConfig ok retrieveMobileContact=%@",
              HQITLogTag, [self configValueForKey:@"retrieveMobileContact"]);
        finish();
    } failure:^(NSError *error, NSString *message) {
        NSLog(@"%@ ensureAppConfig fail: %@", HQITLogTag, message);
        finish();
    }];
}

- (void)refreshAppConfigThen:(void (^)(void))completion {
    void (^finish)(void) = ^{
        if (!completion) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    };
    NSLog(@"%@ refreshAppConfig fetch /app/v3/app/config", HQITLogTag);
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/app/config"
                                         signedData:nil
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        id payload = response.data;
        if (payload == nil && [response.rawDictionary isKindOfClass:[NSDictionary class]]) {
            payload = response.rawDictionary[@"data"];
        }
        [self saveAppConfig:payload];
        NSLog(@"%@ refreshAppConfig ok retrieveMobileContact=%@",
              HQITLogTag, [self configValueForKey:@"retrieveMobileContact"]);
        finish();
    } failure:^(NSError *error, NSString *message) {
        NSLog(@"%@ refreshAppConfig fail: %@ (keep previous cache)", HQITLogTag, message);
        finish();
    }];
}

@end
