

#import "HQITIDFAAdjustCoordinator.h"
#import "HQITAdjustManager.h"
#import "HQITAppStartupManager.h"
#import "HQITNetworkConstants.h"
#import "HQITBuryRecorder.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AFNetworking/AFNetworkReachabilityManager.h>
#import <UIKit/UIKit.h>

@interface HQITIDFAAdjustCoordinator ()
@property (nonatomic, assign) BOOL flowStarted;
@property (nonatomic, assign) BOOL attFlowBegun;
@property (nonatomic, assign) BOOL waitingForATT;
@property (nonatomic, assign) BOOL attPromptIssued;
@property (nonatomic, assign) BOOL networkMonitoring;
@property (nonatomic, assign) BOOL observingActive;
@property (nonatomic, strong, nullable) dispatch_block_t fallbackBlock;
@property (nonatomic, strong, nullable) dispatch_block_t attRetryBlock;
@property (nonatomic, assign) NSInteger attRetryCount;
@end

@implementation HQITIDFAAdjustCoordinator

+ (instancetype)shared {
    static HQITIDFAAdjustCoordinator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HQITIDFAAdjustCoordinator alloc] init];
    });
    return instance;
}

- (void)startIDFAAdjustFlow {
    if (self.flowStarted) {
        return;
    }
    self.flowStarted = YES;
    NSLog(@"[HQITIDFA] start flow, wait network");
    [self startObservingBecomeActive];
    [self startNetworkMonitoring];
}

#pragma mark - Active observation

- (void)startObservingBecomeActive {
    if (self.observingActive) return;
    self.observingActive = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDidBecomeActiveNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)onDidBecomeActiveNotification:(NSNotification *)note {
    (void)note;
    [self onApplicationDidBecomeActive];
}

#pragma mark - Network

- (void)startNetworkMonitoring {
    if (self.networkMonitoring) return;
    self.networkMonitoring = YES;

    AFNetworkReachabilityManager *mgr = [AFNetworkReachabilityManager sharedManager];
    __weak typeof(self) weakSelf = self;
    [mgr setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        BOOL reachable = (status == AFNetworkReachabilityStatusReachableViaWWAN
                          || status == AFNetworkReachabilityStatusReachableViaWiFi);
        if (!reachable) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf onNetworkAvailable];
        });
    }];
    [mgr startMonitoring];

    if (mgr.isReachable) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf onNetworkAvailable];
        });
    }
}

- (void)onNetworkAvailable {
    if (self.attFlowBegun) {
        if (@available(iOS 14, *)) {
            if (ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusNotDetermined
                && !self.attPromptIssued) {
                self.waitingForATT = YES;
                [self requestATTIfActive];
            }
        }
        return;
    }
    self.attFlowBegun = YES;
    NSLog(@"[HQITIDFA] network available, begin ATT/Adjust flow");
    [self beginIDFACheckAndAdjustFlow];
}

#pragma mark - ATT / Adjust

- (void)beginIDFACheckAndAdjustFlow {
    [self scheduleFallbackTimer];
    if (@available(iOS 14, *)) {
        ATTrackingManagerAuthorizationStatus status = ATTrackingManager.trackingAuthorizationStatus;
        switch (status) {
            case ATTrackingManagerAuthorizationStatusAuthorized:
                [HQITBuryRecorder recordIDFAPermissionGranted:YES]; // 17
                [self performAdjustInitialization:@"att-ready"];
                break;
            case ATTrackingManagerAuthorizationStatusDenied:
            case ATTrackingManagerAuthorizationStatusRestricted:
                [HQITBuryRecorder recordIDFAPermissionGranted:NO]; // 18
                [self performAdjustInitialization:@"att-ready"];
                break;
            case ATTrackingManagerAuthorizationStatusNotDetermined:
                self.waitingForATT = YES;
                [self requestATTIfActive];
                break;
            default:
                [HQITBuryRecorder recordIDFAPermissionGranted:NO]; // 18
                [self performAdjustInitialization:@"att-unknown"];
                break;
        }
    } else {
        [HQITBuryRecorder recordIDFAPermissionGranted:YES]; // 17
        [self performAdjustInitialization:@"pre-ios14"];
    }
}

- (void)requestATTIfActive {
    if (@available(iOS 14, *)) {
        if (self.attPromptIssued) return;
        ATTrackingManagerAuthorizationStatus cur = ATTrackingManager.trackingAuthorizationStatus;
        if (cur != ATTrackingManagerAuthorizationStatusNotDetermined) {
            self.waitingForATT = NO;
            [self cancelATTRetry];
            [HQITBuryRecorder recordIDFAPermissionGranted:(cur == ATTrackingManagerAuthorizationStatusAuthorized)];
            [self performAdjustInitialization:@"att-already-decided"];
            return;
        }
        UIApplicationState state = UIApplication.sharedApplication.applicationState;
        if (state != UIApplicationStateActive) {
            NSLog(@"[HQITIDFA] defer ATT until active (state=%ld)", (long)state);
            self.waitingForATT = YES;
            [self scheduleATTRetry];
            return;
        }
        self.attPromptIssued = YES;
        self.waitingForATT = YES;
        [self cancelATTRetry];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
                self.attPromptIssued = NO;
                NSLog(@"[HQITIDFA] active lost before ATT, will retry");
                [self scheduleATTRetry];
                return;
            }
            NSLog(@"[HQITIDFA] request ATT now");
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.waitingForATT = NO;
                    NSLog(@"[HQITIDFA] ATT result=%ld", (long)status);
                    BOOL ok = (status == ATTrackingManagerAuthorizationStatusAuthorized);
                    [HQITBuryRecorder recordIDFAPermissionGranted:ok]; // 17 / 18
                    [weakSelf performAdjustInitialization:@"att-callback"];
                });
            }];
        });
    }
}

- (void)scheduleATTRetry {
    if (self.attPromptIssued) return;
    if (@available(iOS 14, *)) {
        if (ATTrackingManager.trackingAuthorizationStatus != ATTrackingManagerAuthorizationStatusNotDetermined) {
            return;
        }
    } else {
        return;
    }
    [self cancelATTRetry];
    if (self.attRetryCount >= 20) {
        NSLog(@"[HQITIDFA] ATT retry exhausted");
        return;
    }
    self.attRetryCount += 1;
    NSTimeInterval delay = (self.attRetryCount <= 5) ? 0.2 : 0.5;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.attRetryBlock = nil;
        if (self.attPromptIssued) return;
        if (![AFNetworkReachabilityManager sharedManager].isReachable) {
            [self scheduleATTRetry];
            return;
        }
        NSLog(@"[HQITIDFA] ATT retry #%ld state=%ld", (long)self.attRetryCount,
              (long)UIApplication.sharedApplication.applicationState);
        [self requestATTIfActive];
    });
    self.attRetryBlock = block;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   block);
}

- (void)cancelATTRetry {
    if (self.attRetryBlock) {
        dispatch_block_cancel(self.attRetryBlock);
        self.attRetryBlock = nil;
    }
}

- (void)onApplicationDidBecomeActive {
    AFNetworkReachabilityManager *mgr = [AFNetworkReachabilityManager sharedManager];
    if (!mgr.isReachable) {
        return;
    }
    if (!self.attFlowBegun) {
        [self onNetworkAvailable];
        return;
    }
    if (@available(iOS 14, *)) {
        if (ATTrackingManager.trackingAuthorizationStatus != ATTrackingManagerAuthorizationStatusNotDetermined) {
            return;
        }
        self.waitingForATT = YES;
        self.attPromptIssued = NO;
        self.attRetryCount = 0;
        [self requestATTIfActive];
    }
}

- (void)scheduleFallbackTimer {
    [self cancelFallbackTimer];
    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = dispatch_block_create(0, ^{
        if (![HQITAdjustManager shared].isInitialized) {
            NSLog(@"[HQITIDFA] 10s fallback init");
            [weakSelf performAdjustInitialization:@"fallback10s"];
        }
    });
    self.fallbackBlock = block;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (void)cancelFallbackTimer {
    if (self.fallbackBlock) {
        dispatch_block_cancel(self.fallbackBlock);
        self.fallbackBlock = nil;
    }
}

- (nullable NSString *)resolveAdjustToken {
    id value = [[HQITAppStartupManager shared] configValueForKey:@"adjustToken"];
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return (NSString *)value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *s = [value stringValue];
        if (s.length > 0) return s;
    }
    if (HQITAdjustAppToken.length > 0) {
        return HQITAdjustAppToken;
    }
    return nil;
}

- (void)initializeAdjustIfNeeded {
    if ([HQITAdjustManager shared].isInitialized) {
        return;
    }
    if (@available(iOS 14, *)) {
        ATTrackingManagerAuthorizationStatus status = ATTrackingManager.trackingAuthorizationStatus;
        if (status == ATTrackingManagerAuthorizationStatusNotDetermined) {
            NSLog(@"[HQITIDFA] skip init until ATT decided");
            if (!self.attFlowBegun && [AFNetworkReachabilityManager sharedManager].isReachable) {
                [self onNetworkAvailable];
            } else if (self.waitingForATT || self.attFlowBegun) {
                [self requestATTIfActive];
            }
            return;
        }
    }
    [self performAdjustInitialization:@"config-ready"];
}

- (void)performAdjustInitialization:(NSString *)reason {
    NSString *token = [self resolveAdjustToken];
    if (token.length == 0) {
        NSLog(@"[HQITIDFA] no adjustToken (%@)", reason);
        return;
    }
    [[HQITAdjustManager shared] initializeWithToken:token];
    if ([HQITAdjustManager shared].isInitialized) {
        [self cancelFallbackTimer];
        NSLog(@"[HQITIDFA] Adjust ready via %@", reason);
    }
}

@end
