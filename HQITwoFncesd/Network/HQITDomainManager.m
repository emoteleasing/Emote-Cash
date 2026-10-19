

#import "HQITDomainManager.h"
#import "HQITNetworkConstants.h"
#import "HQITStorageKeys.h"

@implementation HQITDomainManager

+ (instancetype)shared {
    static HQITDomainManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HQITDomainManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSUserDefaults standardUserDefaults] setObject:HQITFixedBaseURL forKey:HQITStorageKeyCachedDomain];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"%@ domain fixed: %@", HQITLogTag, HQITFixedBaseURL);
    }
    return self;
}

- (NSString *)currentBaseURL {
    return HQITFixedBaseURL;
}

- (void)ensureDomainReady:(HQITDomainReadyBlock)completion {
    NSString *base = self.currentBaseURL;
    if (!completion) return;
    if ([NSThread isMainThread]) {
        completion(YES, base, nil);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, base, nil);
        });
    }
}

- (void)invalidateCurrentDomain {
}

@end
