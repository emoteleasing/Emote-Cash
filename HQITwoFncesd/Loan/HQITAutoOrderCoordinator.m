

#import "HQITAutoOrderCoordinator.h"
#import "HQITAccurateRecommendViewModel.h"
#import "HQITAccurateRecommendationViewController.h"
#import "HQITAccurateRecommendSuccessViewController.h"
#import "HQITHomeLoanViewController.h"
#import "HQITOrderDataCaptureCoordinator.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITHUDHelper.h"
#import "HQITAppStartupManager.h"
#import "HQITPermissionSecondaryPresenter.h"
#import "HQITBuryRecorder.h"
#import "HQITAppShell.h"
#import "HQITDialogs.h"
#import "HQITBaseDialog.h"
#import "HQITSigningHelper.h"
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

static NSString * const HQITAutoOrderLogTag = @"[HQITAutoOrder]";

@interface HQITAutoOrderCoordinator () <CLLocationManagerDelegate>
@property (nonatomic, strong, nullable) HQITAccurateRecommendViewModel *viewModel;
@property (nonatomic, copy, nullable) NSArray<NSString *> *submittedOrderIds;
@property (nonatomic, weak) UIViewController *hostVC;
@property (nonatomic, copy, nullable) HQITAutoOrderFinishedBlock onFinished;
@property (nonatomic, strong, nullable) HQITBaseDialog *matchingDialog;
@property (nonatomic, copy, nullable) void (^recommendCancel)(void);
@property (nonatomic, copy, nullable) dispatch_block_t recommendTimeoutBlock;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy, nullable) void (^locationCompletion)(NSString *lng, NSString *lat, BOOL cancelled);
@property (nonatomic, strong, nullable) NSTimer *locationTimeoutTimer;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL awaitingFirstAuthResult;
@property (nonatomic, assign) BOOL recommendResponseHandled;
@end

@implementation HQITAutoOrderCoordinator

static HQITAutoOrderCoordinator *sActiveAutoOrder;

+ (BOOL)isRunning {
    return sActiveAutoOrder != nil && sActiveAutoOrder.running;
}

+ (void)startWithHostViewController:(UIViewController *)hostVC
                         onFinished:(HQITAutoOrderFinishedBlock)onFinished {
    if (!hostVC) {
        NSLog(@"%@ start aborted: missing host", HQITAutoOrderLogTag);
        if (onFinished) onFinished(NO);
        return;
    }
    if ([self isRunning]) {
        NSLog(@"%@ start aborted: already running", HQITAutoOrderLogTag);
        if (onFinished) onFinished(NO);
        return;
    }

    HQITAutoOrderCoordinator *c = [[HQITAutoOrderCoordinator alloc] init];
    c.hostVC = hostVC;
    c.onFinished = onFinished;
    sActiveAutoOrder = c;
    objc_setAssociatedObject(hostVC, @selector(startWithHostViewController:onFinished:), c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"%@ start (dcRecommend batch)", HQITAutoOrderLogTag);
    [c beginFetchRecommend];
}

#pragma mark - dcRecommend

- (void)beginFetchRecommend {
    self.running = YES;
    self.recommendResponseHandled = NO;
    UIView *host = [self hostView];
    [self.matchingDialog dismissAnimated:NO];
    self.matchingDialog = [HQITDialogs showMatchingProgressInView:host];
    [self cancelRecommendTimeout];

    __weak typeof(self) weakSelf = self;
    self.recommendCancel = [[HQITNetworkClient shared]
                            requestCancellableWithEndpoint:@"/app/v3/product/dcRecommend"
                            signedData:@{}
                            unsignedData:nil
                            showLoading:@NO
                            showErrorToast:@NO
                            success:^(HQITNetworkResponse *response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.running || self.recommendResponseHandled) return;
            [self handleRecommendData:response.data error:nil];
        });
    } failure:^(NSError *error, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.running || self.recommendResponseHandled) return;
            NSError *err = error;
            if (!err) {
                err = [NSError errorWithDomain:@"HQITNetwork"
                                          code:0
                                      userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
            }
            [self handleRecommendData:nil error:err];
        });
    }];

    dispatch_block_t timeout = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.running || self.recommendResponseHandled) return;
        NSError *timeoutErr = [NSError errorWithDomain:@"HQITNetwork"
                                                  code:4102007
                                              userInfo:@{NSLocalizedDescriptionKey: @""}];
        [self handleRecommendData:nil error:timeoutErr];
    });
    self.recommendTimeoutBlock = timeout;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeout);
}

- (void)cancelRecommendTimeout {
    if (self.recommendTimeoutBlock) {
        dispatch_block_cancel(self.recommendTimeoutBlock);
        self.recommendTimeoutBlock = nil;
    }
}

- (void)dismissMatchingDialog {
    [self cancelRecommendTimeout];
    void (^cancel)(void) = self.recommendCancel;
    self.recommendCancel = nil;
    if (cancel) cancel();
    HQITBaseDialog *dialog = self.matchingDialog;
    self.matchingDialog = nil;
    [dialog dismissAnimated:YES];
}

- (void)handleRecommendData:(id)data error:(NSError *)error {
    // Claim once: timeout empty page must not be overwritten by a late non-4102007 failure → View Now.
    if (!self.running || self.recommendResponseHandled) {
        NSLog(@"%@ handleRecommend ignored running=%d handled=%d err=%ld",
              HQITAutoOrderLogTag, (int)self.running, (int)self.recommendResponseHandled, (long)error.code);
        return;
    }
    self.recommendResponseHandled = YES;

    if (error) {
        [self dismissMatchingDialog];
        NSLog(@"%@ dcRecommend failed code=%ld msg=%@ → %@",
              HQITAutoOrderLogTag,
              (long)error.code,
              error.localizedDescription,
              (error.code == 4102007) ? @"empty" : @"viewNow");
        NSString *prompt = @"";
        NSInteger status = 0;
        if ([self.hostVC isKindOfClass:[HQITHomeLoanViewController class]]) {
            HQITHomeLoanViewController *home = (HQITHomeLoanViewController *)self.hostVC;
            prompt = [home hqit_currentPromptCopy] ?: @"";
            status = [home hqit_currentUserStatus];
        }
        [self pushRecommendPage:[[HQITAccurateRecommendationViewController alloc]
                                 initWithResultCode:error.code
                                            message:error.localizedDescription
                                     homePromptCopy:prompt
                                     homeUserStatus:status]
                        success:NO];
        return;
    }

    if (data == nil || ![HQITAccurateRecommendViewModel hasProductsInRecommendData:data]) {
        [self dismissMatchingDialog];
        NSLog(@"%@ dcRecommend empty / no products", HQITAutoOrderLogTag);
        [self pushRecommendPage:[[HQITAccurateRecommendationViewController alloc] initWithEmptyState:YES]
                        success:NO];
        return;
    }

    self.viewModel = [[HQITAccurateRecommendViewModel alloc] initWithRecommendData:data];
    [self.viewModel selectAllProductsWithMaxAmountAndHighestTerm];
    self.viewModel.agreed = YES;
    if ([self.viewModel selectedProductCount] == 0) {
        [self dismissMatchingDialog];
        NSLog(@"%@ products parsed but none selectable for batch submit", HQITAutoOrderLogTag);
        [self pushRecommendPage:[[HQITAccurateRecommendationViewController alloc] initWithEmptyState:YES]
                        success:NO];
        return;
    }

    NSLog(@"%@ dcRecommend ok products=%ld selected=%ld → locate & batch submit",
          HQITAutoOrderLogTag,
          (long)self.viewModel.products.count,
          (long)[self.viewModel selectedProductCount]);
    __weak typeof(self) weakSelf = self;
    [[HQITAppStartupManager shared] ensureAppConfigThen:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.running) return;
        [self resolveLocationThen:^(NSString *lng, NSString *lat, BOOL cancelled) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.running) return;
            [self.locationManager stopUpdatingLocation];
            BOOL force = [self isForceLocation];
            BOOL placeholder = [lng isEqualToString:@"-360.000000"] || [lat isEqualToString:@"-360.000000"];
            if (cancelled || (force && (lng.length == 0 || lat.length == 0 || placeholder))) {
                NSLog(@"%@ location aborted cancelled=%d force=%d lng=%@ lat=%@",
                      HQITAutoOrderLogTag, cancelled, force, lng, lat);
                [self dismissMatchingDialog];
                [self finishWithSuccess:NO];
                return;
            }
            NSLog(@"%@ location ok lng=%@ lat=%@", HQITAutoOrderLogTag, lng, lat);
            [self dismissMatchingDialog];
            [self submitWithLongitude:lng latitude:lat];
        }];
    }];
}

- (void)pushRecommendPage:(UIViewController *)vc success:(BOOL)success {
    UINavigationController *nav = self.hostVC.navigationController;
    if (nav && vc) {
        [nav pushViewController:vc animated:YES];
    }
    [self finishWithSuccess:success];
}

#pragma mark - Submit / Capture / Success

- (void)submitWithLongitude:(NSString *)lng latitude:(NSString *)lat {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onErrorMessage = ^(NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (message.length) [HQITHUDHelper showToast:message];
        [self finishWithSuccess:NO];
    };
    self.viewModel.onSubmitSuccess = ^(NSArray<NSString *> *orderIds) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSLog(@"%@ submit ok orderIds=%@", HQITAutoOrderLogTag, orderIds);
        [self startCaptureWithOrderIds:orderIds];
    };
    NSLog(@"%@ submit begin (userSubmitDcUpgrade)", HQITAutoOrderLogTag);
    [self.viewModel submitWithLongitude:lng latitude:lat];
}

- (void)startCaptureWithOrderIds:(NSArray<NSString *> *)orderIds {
    UIViewController *host = self.hostVC;
    if (!host) {
        [self finishWithSuccess:NO];
        return;
    }
    NSArray<NSString *> *allIds = [orderIds copy] ?: @[];
    self.submittedOrderIds = allIds;
    NSString *firstOrderId = allIds.firstObject ?: @"";
    if (firstOrderId.length == 0) {
        NSLog(@"%@ capture aborted: empty orderId", HQITAutoOrderLogTag);
        [self.viewModel resetSubmittingState];
        [self finishWithSuccess:NO];
        return;
    }
    [self dismissMatchingDialog];
    [HQITHUDHelper hideLoading];
    [HQITHUDHelper hideLoadingInView:[self hostView]];
    [HQITHUDHelper hideLoadingInView:[self permissionHostView]];
    NSLog(@"%@ startCapture (same as AccurateRecommend) orderId=%@ host=%@",
          HQITAutoOrderLogTag, firstOrderId, NSStringFromClass([host class]));
    __weak typeof(self) weakSelf = self;
    [HQITOrderDataCaptureCoordinator startWithOrderId:firstOrderId
                                   hostViewController:host
                                           completion:^(BOOL success) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSLog(@"%@ capture done success=%d", HQITAutoOrderLogTag, success);
        if (!success) {
            [self.viewModel resetSubmittingState];
            [self finishWithSuccess:NO];
            return;
        }
        [self openSuccessPageWithOrderIds:allIds];
    }];
}

- (void)openSuccessPageWithOrderIds:(NSArray<NSString *> *)orderIds {
    UIViewController *host = self.hostVC;
    UINavigationController *nav = host.navigationController;
    if (!nav) {
        [self finishWithSuccess:YES];
        return;
    }
    HQITAccurateRecommendSuccessViewController *successVC =
        [[HQITAccurateRecommendSuccessViewController alloc] initWithOrderIds:orderIds ?: @[]];
    [nav pushViewController:successVC animated:YES];
    [self finishWithSuccess:YES];
}

- (void)finishWithSuccess:(BOOL)success {
    NSLog(@"%@ finish success=%d", HQITAutoOrderLogTag, success);
    [self clearLocationTimeout];
    [self dismissMatchingDialog];
    self.running = NO;
    self.awaitingFirstAuthResult = NO;
    self.locationCompletion = nil;
    HQITAutoOrderFinishedBlock finished = self.onFinished;
    UIViewController *host = self.hostVC;
    if (host) {
        objc_setAssociatedObject(host, @selector(startWithHostViewController:onFinished:), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (sActiveAutoOrder == self) sActiveAutoOrder = nil;
    if (finished) finished(success);
    [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification
                                                        object:nil];
}

#pragma mark - Location

- (UIView *)hostView {
    return self.hostVC.view.window ?: self.hostVC.view ?: [HQITAppShell shared].window;
}

- (UIView *)permissionHostView {
    return [HQITAppShell shared].window ?: [self hostView];
}

- (BOOL)isForceLocation {
    HQITAppStartupManager *mgr = [HQITAppStartupManager shared];
    BOOL force = [mgr isForceContactMode];
    NSLog(@"%@ retrieveMobileContact=%@ → force=%d",
          HQITAutoOrderLogTag, [mgr configValueForKey:@"retrieveMobileContact"], force);
    return force;
}

- (void)resolveLocationThen:(void (^)(NSString *lng, NSString *lat, BOOL cancelled))completion {
    NSAssert([NSThread isMainThread], @"location resolve must run on main");
    self.locationCompletion = [completion copy];
    self.awaitingFirstAuthResult = NO;
    BOOL force = [self isForceLocation];
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        self.locationManager.distanceFilter = kCLDistanceFilterNone;
    }
    status = self.locationManager.authorizationStatus;
    NSLog(@"%@ resolveLocation force=%d status=%d", HQITAutoOrderLogTag, force, (int)status);
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        [HQITBuryRecorder recordLocationPermissionGranted:YES]; // 15
        [self startLocationUpdates];
        return;
    }
    if (status == kCLAuthorizationStatusNotDetermined) {
        self.awaitingFirstAuthResult = YES;
        [self startLocationTimeoutWithSeconds:20.0];
        [self.locationManager requestWhenInUseAuthorization];
        return;
    }
    [HQITBuryRecorder recordLocationPermissionGranted:NO]; // 16
    if (force) {
        NSLog(@"%@ force already denied → secondary location dialog", HQITAutoOrderLogTag);
        [self presentForceLocationGuideThenCancel];
    } else {
        if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
        self.locationCompletion = nil;
    }
}

- (void)startLocationUpdates {
    [self startLocationTimeoutWithSeconds:20.0];
    CLLocation *cached = self.locationManager.location;
    if (cached && cached.horizontalAccuracy > 0 && cached.horizontalAccuracy < 5000) {
        NSTimeInterval age = -[cached.timestamp timeIntervalSinceNow];
        if (age >= 0 && age < 600) {
            NSString *lng = [HQITSigningHelper coordinateSignValue:cached.coordinate.longitude];
            NSString *lat = [HQITSigningHelper coordinateSignValue:cached.coordinate.latitude];
            NSLog(@"%@ use cached location lng=%@ lat=%@ acc=%.0f age=%.0fs",
                  HQITAutoOrderLogTag, lng, lat, cached.horizontalAccuracy, age);
            [self clearLocationTimeout];
            if (self.locationCompletion) self.locationCompletion(lng, lat, NO);
            self.locationCompletion = nil;
            return;
        }
    }
    NSLog(@"%@ startUpdatingLocation (no usable cache)", HQITAutoOrderLogTag);
    [self.locationManager stopUpdatingLocation];
    [self.locationManager startUpdatingLocation];
}

- (void)presentForceLocationGuideThenCancel {
    [self dismissMatchingDialog];
    [HQITHUDHelper hideLoading];
    UIView *host = [self permissionHostView];
    __weak typeof(self) weakSelf = self;
    [HQITPermissionSecondaryPresenter showLocationSettingsGuideInView:host
                                                            onConfirm:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        self.locationCompletion = nil;
    } onCancel:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        self.locationCompletion = nil;
    }];
    UIView *top = host.subviews.lastObject;
    if (top) [host bringSubviewToFront:top];
}

- (void)startLocationTimeoutWithSeconds:(NSTimeInterval)seconds {
    [self clearLocationTimeout];
    __weak typeof(self) weakSelf = self;
    self.locationTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:seconds repeats:NO block:^(NSTimer *timer) {
        NSLog(@"%@ location timeout %.0fs", HQITAutoOrderLogTag, seconds);
        [weakSelf locationFailedForceAware];
    }];
}

- (void)clearLocationTimeout {
    [self.locationTimeoutTimer invalidate];
    self.locationTimeoutTimer = nil;
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    CLAuthorizationStatus status = manager.authorizationStatus;
    if (status == kCLAuthorizationStatusNotDetermined) return;
    if (!self.locationCompletion) return;
    if (!self.awaitingFirstAuthResult) return;
    BOOL force = [self isForceLocation];
    NSLog(@"%@ auth changed status=%d force=%d", HQITAutoOrderLogTag, (int)status, force);
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        self.awaitingFirstAuthResult = NO;
        [HQITBuryRecorder recordLocationPermissionGranted:YES]; // 15
        [self startLocationUpdates];
        return;
    }
    [self clearLocationTimeout];
    self.awaitingFirstAuthResult = NO;
    [HQITBuryRecorder recordLocationPermissionGranted:NO]; // 16
    if (force) {
        NSLog(@"%@ force first system deny → end (no submit, no secondary dialog)", HQITAutoOrderLogTag);
        [self dismissMatchingDialog];
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        self.locationCompletion = nil;
        return;
    }
    NSLog(@"%@ non-force first system deny → -360 continue", HQITAutoOrderLogTag);
    if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
    self.locationCompletion = nil;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    [self clearLocationTimeout];
    CLLocation *loc = locations.lastObject;
    if (!loc) {
        [self locationFailedForceAware];
        return;
    }
    [manager stopUpdatingLocation];
    NSString *lng = [HQITSigningHelper coordinateSignValue:loc.coordinate.longitude];
    NSString *lat = [HQITSigningHelper coordinateSignValue:loc.coordinate.latitude];
    NSLog(@"%@ didUpdateLocations lng=%@ lat=%@", HQITAutoOrderLogTag, lng, lat);
    if (self.locationCompletion) self.locationCompletion(lng, lat, NO);
    self.locationCompletion = nil;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"%@ location fail code=%ld %@", HQITAutoOrderLogTag, (long)error.code, error.localizedDescription);
    if (error.code == kCLErrorLocationUnknown) return;
    [self clearLocationTimeout];
    [self locationFailedForceAware];
}

- (void)locationFailedForceAware {
    if (!self.locationCompletion) return;
    [self clearLocationTimeout];
    [self.locationManager stopUpdatingLocation];
    self.awaitingFirstAuthResult = NO;
    if (![self isForceLocation]) {
        NSLog(@"%@ non-force location failed → -360", HQITAutoOrderLogTag);
        if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
        self.locationCompletion = nil;
        return;
    }
    CLAuthorizationStatus status = self.locationManager.authorizationStatus;
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        NSLog(@"%@ force location permission denied mid-flow → end (no secondary dialog)", HQITAutoOrderLogTag);
        [self dismissMatchingDialog];
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        self.locationCompletion = nil;
        return;
    }
    NSLog(@"%@ force location GPS failed → cancel", HQITAutoOrderLogTag);
    [self dismissMatchingDialog];
    if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
    self.locationCompletion = nil;
}

@end
