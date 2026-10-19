

#import "HQITAdjustManager.h"
#import <AdjustSdk/Adjust.h>
#import <AdjustSdk/ADJConfig.h>

@interface HQITAdjustManager ()
@property (nonatomic, assign, readwrite) BOOL isInitialized;
@property (nonatomic, copy, readwrite, nullable) NSString *adid;
@end

@implementation HQITAdjustManager

+ (instancetype)shared {
    static HQITAdjustManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HQITAdjustManager alloc] init];
    });
    return instance;
}

- (void)initializeWithToken:(NSString *)token {
    if (token.length == 0) {
        NSLog(@"[HQITAdjust] skip: empty token");
        return;
    }
    if (self.isInitialized) {
        return;
    }
#if DEBUG
    NSString *env = ADJEnvironmentSandbox;
#else
    NSString *env = ADJEnvironmentProduction;
#endif
    ADJConfig *config = [[ADJConfig alloc] initWithAppToken:token environment:env];
    [Adjust initSdk:config];
    self.isInitialized = YES;
    NSLog(@"[HQITAdjust] initialized");

    __weak typeof(self) weakSelf = self;
    [Adjust adidWithCompletionHandler:^(NSString * _Nullable adid) {
        weakSelf.adid = adid;
    }];
}

- (NSString *)currentAdid {
    if (self.adid.length > 0) return self.adid;
    return nil;
}

@end
