

#import "HQITHomeLoanViewModel.h"
#import "HQITSessionManager.h"
#import "HQITNetworkClient.h"
#import "HQITAppConfigHelper.h"
#import "HQITAppStartupManager.h"
#import "HQITAmountFormatter.h"
#import "HQITHomeSessionState.h"
#import "HQITAdjustManager.h"
#import "HQITStorageKeys.h"

static NSString * const kHQITDefaultKYCPrompt =
    @"Please complete the KYC certifcation beforeusing our loan service.";

@implementation HQITHomeProductItem
@end

@implementation HQITHomeVersionInfo
@end

@interface HQITHomeLoanViewModel ()
@property (nonatomic, assign, readwrite) NSInteger userStatus;
@property (nonatomic, copy, readwrite) NSString *promptCopy;
@property (nonatomic, assign, readwrite) NSInteger progressActiveIndex;
@property (nonatomic, copy, readwrite, nullable) NSString *withdrawalOrderId;
@property (nonatomic, copy, readwrite) NSArray<HQITHomeProductItem *> *products;
@property (nonatomic, strong, readwrite, nullable) HQITHomeVersionInfo *versionInfo;
@property (nonatomic, assign, readwrite) BOOL isAutoOrderEligible;
@property (nonatomic, copy, readwrite) NSString *maxApplyAmountDisplay;
@property (nonatomic, assign) NSInteger hasOrder;
@property (nonatomic, copy) NSString *firstLoanOptionLine;
@property (nonatomic, assign) BOOL pipelineRunning;
@property (nonatomic, assign) NSInteger pipelineGeneration;
@end

@implementation HQITHomeLoanViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _products = @[];
        [self applyGuestState];
    }
    return self;
}

- (BOOL)showsKYCEmptyState {
    return self.userStatus == 10 || ![HQITSessionManager shared].isLoggedIn;
}

- (BOOL)showsProductList {
    return NO;
}

- (void)refreshAutoOrderEligible {
    NSString *raw = self.firstLoanOptionLine.length ? self.firstLoanOptionLine : @"";
    NSString *line = [[[raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString] copy];
    BOOL loggedIn = [HQITSessionManager shared].isLoggedIn;
    self.isAutoOrderEligible = (loggedIn
                                && self.hasOrder == 0
                                && self.userStatus == 20
                                && [line isEqualToString:@"system"]);
    NSLog(@"[HQITHome] autoOrderEligible=%d (login=%d hasOrder=%ld userStatus=%ld line=%@)",
          (int)self.isAutoOrderEligible,
          (int)loggedIn,
          (long)self.hasOrder,
          (long)self.userStatus,
          line.length ? line : @"(empty)");
}

- (void)applyGuestState {
    self.userStatus = 10;
    self.promptCopy = kHQITDefaultKYCPrompt;
    self.progressActiveIndex = 0;
    self.withdrawalOrderId = nil;
    self.products = @[];
    self.versionInfo = nil;
    self.hasOrder = 0;
    self.firstLoanOptionLine = @"";
    self.isAutoOrderEligible = NO;
    self.maxApplyAmountDisplay = [HQITAmountFormatter formatPlainAmount:@0 prefixCurrency:YES];
}

- (void)notifyUpdated {
    if (self.onUpdated) self.onUpdated();
}

- (BOOL)ensureLoggedInOrPrompt {
    if ([HQITSessionManager shared].isLoggedIn) return YES;
    if (self.onNeedLogin) self.onNeedLogin();
    return NO;
}

- (void)route:(NSString *)route info:(NSDictionary *)info {
    if (self.onRoute) self.onRoute(route, info);
}

#pragma mark - Pipeline §2.2

- (void)reloadForCurrentSession {
    if (![HQITSessionManager shared].isLoggedIn) {
        self.pipelineRunning = NO;
        [self applyGuestState];
        [self notifyUpdated];
        return;
    }

    self.pipelineGeneration += 1;
    NSInteger gen = self.pipelineGeneration;
    self.pipelineRunning = YES;

    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/user/suphome"
                                         signedData:@{}
                                       unsignedData:@{@"dcUpFlag": @"1"}
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.pipelineGeneration) return;
        [self applySuphomeData:response.data];
        [self notifyUpdated];
        [self fetchUserInfoThenContinue:gen];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.pipelineGeneration) return;
        if (self.promptCopy.length == 0) {
            [self applyGuestState];
        }
        [self notifyUpdated];
        [self fetchUserInfoThenContinue:gen];
    }];
}

- (void)applySuphomeData:(id)raw {
    NSDictionary *data = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
    NSInteger status = [self integerFrom:data key:@"userStatus" aliases:@[]];
    BOOL hasStatusKey = (data[@"userStatus"] != nil);
    if (status == 0 && !hasStatusKey) {
        status = 10;
    }
    self.userStatus = status;
    [[NSUserDefaults standardUserDefaults] setInteger:status forKey:HQITStorageKeyUserStatus];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSString *prompt = [self stringFrom:data key:@"promptCopy" aliases:@[]];
    self.promptCopy = prompt.length > 0 ? prompt : kHQITDefaultKYCPrompt;
    self.withdrawalOrderId = [self stringFrom:data key:@"withdrawalOrderId" aliases:@[]];
    if (self.withdrawalOrderId.length == 0) self.withdrawalOrderId = nil;
    self.hasOrder = [self integerFrom:data key:@"hasOrder" aliases:@[]];
    // Auto-order line MUST come from /app/v3/user/suphome only — never from /app/v3/app/config
    // (config may also carry firstLoanOptionLine with a different meaning/value).
    self.firstLoanOptionLine = [self stringFrom:data key:@"firstLoanOptionLine" aliases:@[]];
    id maxAmt = data[@"maxApplyAmount"];
    if (maxAmt != nil && maxAmt != [NSNull null]) {
        self.maxApplyAmountDisplay = [HQITAmountFormatter formatPlainAmount:maxAmt prefixCurrency:YES];
    } else {
        self.maxApplyAmountDisplay = [HQITAmountFormatter formatPlainAmount:@0 prefixCurrency:YES];
    }
    self.progressActiveIndex = [self progressIndexForStatus:status];
    if (status == 10) {
        self.products = @[];
    }
    [self refreshAutoOrderEligible];
}

- (BOOL)showsHintArrow {
    return [self shouldShowArrowForStatus:self.userStatus];
}

- (NSDictionary *)userInfoUnsignedParamsWithAdid {
    NSMutableDictionary *unsignedParams = [NSMutableDictionary dictionary];
    NSString *adid = [[HQITAdjustManager shared] currentAdid];
    if (adid.length > 0) unsignedParams[@"adid"] = adid;
    return unsignedParams.count ? [unsignedParams copy] : nil;
}

- (void)applyUserInfoResponseData:(id)raw {
    NSDictionary *data = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
    NSString *name = [self stringFrom:data key:@"name" aliases:@[@"userName"]];
    NSString *mobile = [self stringFrom:data key:@"phone" aliases:@[@"mobile"]];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (name.length) [ud setObject:name forKey:HQITStorageKeyUserName];
    else [ud removeObjectForKey:HQITStorageKeyUserName];
    if (mobile.length) [ud setObject:mobile forKey:HQITStorageKeyUserMobile];
    [ud synchronize];
}

- (void)syncUserInfoOnHomeEnter {
    if (![HQITSessionManager shared].isLoggedIn) return;
    NSDictionary *unsignedParams = [self userInfoUnsignedParamsWithAdid];
    NSLog(@"[HQITHome] enter → POST /app/v3/user/info adid=%@ (unsigned)",
          unsignedParams[@"adid"] ?: @"(none)");
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/user/info"
                                         signedData:@{}
                                       unsignedData:unsignedParams
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self applyUserInfoResponseData:response.data];
    } failure:^(NSError *error, NSString *message) {
        NSLog(@"[HQITHome] user/info fail: %@", message);
    }];
}

- (void)fetchUserInfoThenContinue:(NSInteger)gen {
    NSDictionary *unsignedParams = [self userInfoUnsignedParamsWithAdid];
    NSLog(@"[HQITHome] pipeline → POST /app/v3/user/info adid=%@ (unsigned)",
          unsignedParams[@"adid"] ?: @"(none)");
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/user/info"
                                         signedData:@{}
                                       unsignedData:unsignedParams
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.pipelineGeneration) return;
        [self applyUserInfoResponseData:response.data];
        [self fetchVersionThenContinue:gen];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.pipelineGeneration) return;
        [self fetchVersionThenContinue:gen];
    }];
}

- (void)fetchVersionThenContinue:(NSInteger)gen {
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/app/versionV2"
                                         signedData:@{}
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.pipelineGeneration) return;
        self.versionInfo = [self parseVersionInfo:response.data];
        self.products = @[];
        [self refreshAutoOrderEligible];
        [self finishPipeline:gen];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.pipelineGeneration) return;
        self.versionInfo = nil;
        self.products = @[];
        [self refreshAutoOrderEligible];
        [self finishPipeline:gen];
    }];
}

- (void)finishPipeline:(NSInteger)gen {
    if (gen != self.pipelineGeneration) return;
    self.pipelineRunning = NO;
    __weak typeof(self) weakSelf = self;
    [[HQITAppStartupManager shared] ensureAppConfigThen:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.pipelineGeneration) return;
        NSLog(@"[HQITHome] hintArrow status=%ld rejectH5=%@ → show=%d",
              (long)self.userStatus,
              [HQITAppConfigHelper rejectH5URLString] ?: @"(nil)",
              (int)self.showsHintArrow);
        [self notifyUpdated];
        if (self.onPipelineFinishedForDialogs) {
            self.onPipelineFinishedForDialogs();
        }
    }];
}

#pragma mark - Arrow / progress

- (BOOL)shouldShowArrowForStatus:(NSInteger)status {
    NSArray<NSNumber *> *list = @[@10, @30, @32, @41, @80, @81];
    if ([list containsObject:@(status)]) return YES;
    if (status == 51) {
        return [HQITAppConfigHelper isRejectH5Configured];
    }
    return NO;
}

- (NSInteger)progressIndexForStatus:(NSInteger)status {
    if (status == 10) return 0;
    if (status == 30 || status == 32) return 1;
    if (status == 41) return 2;
    if (status == 80 || status == 81) return 3;
    if (status == 51) return 1;
    return 1;
}

#pragma mark - Home action button

- (NSString *)homeActionButtonTitle {
    switch (self.userStatus) {
        case 81: return @"Pay Overdue";
        case 41: return @"Change Bank Account";
        case 32: return @"Get loan";
        case 30: return @"Submit Application";
        default: return @"Apply Now"; // 10 / 20 / 80 / 51 / 100 / other
    }
}

- (void)routePreciseRecommendation {
    [self route:@"accurate_recommendation" info:nil];
}

#pragma mark - Actions

- (void)hqit_routeHomeActionExcludingReject {
    NSInteger status = self.userStatus;
    if (status == 10) {
        [self route:@"kyc_start" info:nil];
        return;
    }
    if (status == 81) {
        [self route:@"order_list" info:@{@"orderStatus": @20}];
        return;
    }
    if (status == 41 || status == 32 || status == 30) {
        [self route:@"order_list" info:@{@"orderStatus": @10}];
        return;
    }
    if ([self handleProductApplyAsAutoOrderIfNeeded]) return;
    [self routePreciseRecommendation];
}

- (void)handleHintTapped {
    if (![self ensureLoggedInOrPrompt]) return;
    if (self.userStatus == 51) {
        if ([HQITAppConfigHelper isRejectH5Configured]) {
            [self route:@"reject_h5" info:@{@"url": [HQITAppConfigHelper rejectH5URLString] ?: @""}];
        }
        return;
    }
    [self hqit_routeHomeActionExcludingReject];
}

- (void)handleApplyTapped {
    if (![self ensureLoggedInOrPrompt]) return;
    if (self.userStatus == 51) {
        [self routePreciseRecommendation];
        return;
    }
    [self hqit_routeHomeActionExcludingReject];
}

- (void)handleContactUsTapped {
    if (![self ensureLoggedInOrPrompt]) return;
    [self route:@"contact_us" info:nil];
}

- (void)handleBankAccountTapped {
    if (![self ensureLoggedInOrPrompt]) return;
    [self route:@"bank_account" info:nil];
}

- (void)handleWithdrawalConfirm {
    if (![self ensureLoggedInOrPrompt]) return;
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (self.withdrawalOrderId.length > 0) info[@"orderId"] = self.withdrawalOrderId;
    [self route:@"withdrawal_detail" info:info];
}

- (void)handleProductApplyTapped:(HQITHomeProductItem *)product {
    if (![self ensureLoggedInOrPrompt]) return;
    if ([self handleProductApplyAsAutoOrderIfNeeded]) return;
    (void)product;
    [self routePreciseRecommendation];
}

- (BOOL)handleProductApplyAsAutoOrderIfNeeded {
    [self refreshAutoOrderEligible];
    if (!self.isAutoOrderEligible) return NO;
    [self route:@"auto_order" info:nil];
    return YES;
}

#pragma mark - Parsers

- (HQITHomeVersionInfo *)parseVersionInfo:(id)raw {
    NSDictionary *data = [raw isKindOfClass:[NSDictionary class]] ? raw : nil;
    if (!data) return nil;

    NSString *latest = [self stringFrom:data key:@"latestVersion" aliases:@[]];
    if (latest.length == 0) return nil;

    // §12.3: only show when current < latest (semantic compare)
    NSString *current = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
    if ([self compareVersion:current to:latest] != NSOrderedAscending) {
        return nil;
    }

    HQITHomeVersionInfo *info = [[HQITHomeVersionInfo alloc] init];
    info.latestVersion = latest;
    info.updateURL = [self stringFrom:data key:@"latestVersionUrl" aliases:@[]];
    info.title = [self stringFrom:data key:@"title" aliases:@[]];
    info.message = [self stringFrom:data key:@"latestVersionContent" aliases:@[]];
    info.needUpdate = YES;
    info.forceUpdate = NO;
    return info;
}

/// Returns NSOrderedAscending if a < b
- (NSComparisonResult)compareVersion:(NSString *)a to:(NSString *)b {
    NSArray *pa = [[a componentsSeparatedByString:@"."] valueForKey:@"integerValue"];
    NSArray *pb = [[b componentsSeparatedByString:@"."] valueForKey:@"integerValue"];
    NSInteger n = MAX(pa.count, pb.count);
    for (NSInteger i = 0; i < n; i++) {
        NSInteger va = i < (NSInteger)pa.count ? [pa[i] integerValue] : 0;
        NSInteger vb = i < (NSInteger)pb.count ? [pb[i] integerValue] : 0;
        if (va < vb) return NSOrderedAscending;
        if (va > vb) return NSOrderedDescending;
    }
    return NSOrderedSame;
}

- (NSArray<HQITHomeProductItem *> *)parseProducts:(id)raw {
    NSArray *list = nil;
    if ([raw isKindOfClass:[NSArray class]]) {
        list = raw;
    } else if ([raw isKindOfClass:[NSDictionary class]]) {
        NSDictionary *d = (NSDictionary *)raw;
        id candidate = d[@"productInfoList"];
        if ([candidate isKindOfClass:[NSArray class]]) list = candidate;
    }
    if (![list isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray<HQITHomeProductItem *> *items = [NSMutableArray array];
    for (id row in list) {
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *dict = (NSDictionary *)row;
        HQITHomeProductItem *item = [[HQITHomeProductItem alloc] init];
        item.raw = dict;
        item.productId = [self stringFrom:dict key:@"productId" aliases:@[]];
        item.productName = [self stringFrom:dict key:@"productName" aliases:@[]];
        item.productLogo = [self stringFrom:dict key:@"productLogo" aliases:@[]];
        item.lowAmount = dict[@"lowAmount"];
        item.highAmount = dict[@"highAmount"];
        if (item.lowAmount || item.highAmount) {
            item.quotaDisplay = [NSString stringWithFormat:@"%@ ~ %@",
                                 [HQITAmountFormatter formatPlainAmount:item.lowAmount ?: @0 prefixCurrency:YES],
                                 [HQITAmountFormatter formatPlainAmount:item.highAmount ?: item.lowAmount ?: @0 prefixCurrency:YES]];
        } else {
            NSString *rawQuota = [self stringFrom:dict key:@"quotaRange" aliases:@[]];
            item.quotaDisplay = rawQuota.length ? [HQITAmountFormatter formatDisplay:rawQuota] : @"";
        }
        item.interestRateDisplay = [self formatInterestRate:dict[@"lowestLoanInterestRate"]];
        item.labels = [self parseLabels:dict[@"productLabel"]];
        if (item.productId.length == 0) continue;
        [items addObject:item];
    }
    return items;
}

- (NSString *)formatInterestRate:(id)raw {
    if (raw == nil || raw == [NSNull null]) return @"";
    NSString *s = [[NSString stringWithFormat:@"%@", raw] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0 || [s isEqualToString:@"(null)"]) return @"";
    if ([s containsString:@"%"]) return s;
    double v = s.doubleValue;
    if (v == 0 && ![s hasPrefix:@"0"]) return @"";
    return [NSString stringWithFormat:@"%.2f%%", v * 100.0];
}

- (NSArray<NSString *> *)parseLabels:(id)raw {
    if ([raw isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for (id o in (NSArray *)raw) {
            NSString *s = [[NSString stringWithFormat:@"%@", o] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (s.length && ![s isEqualToString:@"(null)"]) [out addObject:s];
        }
        return out;
    }
    if (![raw isKindOfClass:[NSString class]]) return @[];
    NSString *text = [(NSString *)raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return @[];
    NSArray *parts = [text componentsSeparatedByString:@","];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *p in parts) {
        NSString *s = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length) [out addObject:s];
    }
    return out;
}

#pragma mark - Helpers

- (BOOL)boolFrom:(NSDictionary *)dict key:(NSString *)key aliases:(NSArray<NSString *> *)aliases {
    id v = dict[key];
    if (!v) {
        for (NSString *a in aliases) {
            v = dict[a];
            if (v) break;
        }
    }
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v boolValue];
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)v lowercaseString];
        return [s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"] || [s isEqualToString:@"on"];
    }
    return NO;
}

- (NSInteger)integerFrom:(NSDictionary *)dict key:(NSString *)key aliases:(NSArray<NSString *> *)aliases {
    id v = dict[key];
    if (!v) {
        for (NSString *a in aliases) {
            v = dict[a];
            if (v) break;
        }
    }
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v integerValue];
    return 0;
}

- (NSString *)stringFrom:(NSDictionary *)dict key:(NSString *)key aliases:(NSArray<NSString *> *)aliases {
    id v = dict[key];
    if (!v) {
        for (NSString *a in aliases) {
            v = dict[a];
            if (v) break;
        }
    }
    if ([v isKindOfClass:[NSString class]]) return (NSString *)v;
    if ([v respondsToSelector:@selector(stringValue)]) return [v stringValue];
    return @"";
}

@end
