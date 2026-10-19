

#import "HQITOrderHistoryViewModel.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITAmountFormatter.h"

@interface HQITOrderHistoryViewModel ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSArray<HQITOrderHistoryItem *> *> *itemsByTab;
@property (nonatomic, assign, readwrite) BOOL isLoading;
@property (nonatomic, assign, readwrite) BOOL hasLoadedOnce;
@property (nonatomic, assign) NSInteger loadGeneration;
@end

@implementation HQITOrderHistoryViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _selectedTab = HQITOrderHistoryTabRepaymentDue;
        _itemsByTab = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (NSArray<NSString *> *)tabTitles {
    return @[@"Repayment Due", @"Submit Application", @"Processing", @"Completed"];
}

+ (NSInteger)orderStatusForTab:(HQITOrderHistoryTab)tab {
    switch (tab) {
        case HQITOrderHistoryTabRepaymentDue: return 20;
        case HQITOrderHistoryTabSubmitApplication: return 10;
        case HQITOrderHistoryTabProcessing: return 30;
        case HQITOrderHistoryTabCompleted: return 40;
    }
    return 20;
}

+ (HQITOrderHistoryTab)tabForOrderStatus:(NSInteger)orderStatus {
    if (orderStatus == 10) return HQITOrderHistoryTabSubmitApplication;
    if (orderStatus == 30) return HQITOrderHistoryTabProcessing;
    if (orderStatus == 40) return HQITOrderHistoryTabCompleted;
    return HQITOrderHistoryTabRepaymentDue;
}

- (NSArray<HQITOrderHistoryItem *> *)currentItems {
    return self.itemsByTab[@(self.selectedTab)] ?: @[];
}

- (void)notify {
    if (self.onUpdated) self.onUpdated();
}

- (void)selectTab:(HQITOrderHistoryTab)tab {
    [self selectTab:tab reload:YES];
}

- (void)selectTab:(HQITOrderHistoryTab)tab reload:(BOOL)reload {
    self.selectedTab = tab;
    [self notify];
    if (reload) [self reloadCurrentSection];
}

- (void)selectOrderStatus:(NSInteger)orderStatus {
    [self selectTab:[[self class] tabForOrderStatus:orderStatus] reload:YES];
}

- (void)reloadAllSections {
    [self reloadCurrentSection];
}

- (void)reloadCurrentSection {
    NSInteger gen = ++self.loadGeneration;
    HQITOrderHistoryTab tab = self.selectedTab;
    NSInteger orderStatus = [[self class] orderStatusForTab:tab];
    self.isLoading = YES;
    [self notify];

    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/list"
                                         signedData:@{}
                                       unsignedData:@{@"orderStatus": @(orderStatus)}
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.loadGeneration) return;
        self.itemsByTab[@(tab)] = [self parseList:response.data];
        self.isLoading = NO;
        self.hasLoadedOnce = YES;
        [self notify];
    } failure:^(NSError *error, NSString *message) {
        (void)error; (void)message;
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.loadGeneration) return;
        if (!self.itemsByTab[@(tab)]) {
            self.itemsByTab[@(tab)] = @[];
        }
        self.isLoading = NO;
        self.hasLoadedOnce = YES;
        [self notify];
    }];
}

#pragma mark - Parse

- (NSArray *)arrayFromData:(id)data {
    if ([data isKindOfClass:[NSArray class]]) return data;
    if (![data isKindOfClass:[NSDictionary class]]) return @[];
    NSDictionary *dict = (NSDictionary *)data;
    for (NSString *key in @[@"orderList", @"orderList", @"exact", @"records", @"rows", @"pile", @"exact"]) {
        id v = dict[key];
        if ([v isKindOfClass:[NSArray class]]) return v;
    }
    return @[];
}


- (NSString *)stringFrom:(NSDictionary *)dict key:(NSString *)key {
    return [self stringFrom:dict keys:(key.length ? @[key] : @[])];
}

- (NSInteger)integerFrom:(NSDictionary *)dict key:(NSString *)key {
    return [self stringFrom:dict key:key].integerValue;
}

- (NSString *)stringFrom:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    for (NSString *k in keys) {
        id v = dict[k];
        if (v == nil || v == [NSNull null]) continue;
        NSString *s = [[NSString stringWithFormat:@"%@", v] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length > 0 && ![s isEqualToString:@"(null)"]) return s;
    }
    return @"";
}

- (NSInteger)statusCodeFrom:(NSDictionary *)dict {
    for (NSString *k in @[@"orderStatus", @"lose", @"neglect", @"rail", @"order_status"]) {
        id v = dict[k];
        if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
        if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) {
            return [(NSString *)v integerValue];
        }
    }
    return 0;
}

- (NSString *)formatDisplayDate:(id)raw {
    if (raw == nil || raw == [NSNull null]) return @"";
    if ([raw isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length == 0) return @"";
        // Already human readable
        if ([s rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].location != NSNotFound &&
            [s containsString:@","]) {
            return s;
        }
        // yyyy-MM-dd / yyyy/MM/dd
        NSDateFormatter *inFmt = [[NSDateFormatter alloc] init];
        inFmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        for (NSString *fmt in @[@"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd", @"yyyy/MM/dd", @"dd-MM-yyyy"]) {
            inFmt.dateFormat = fmt;
            NSDate *d = [inFmt dateFromString:s];
            if (d) return [self displayStringFromDate:d];
        }
        // numeric string timestamp
        if ([s rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
            return [self formatDisplayDate:@([s longLongValue])];
        }
        return s;
    }
    if ([raw isKindOfClass:[NSNumber class]]) {
        long long n = [(NSNumber *)raw longLongValue];
        if (n <= 0) return @"";
        // ms vs sec
        if (n > 1000000000000LL) n = n / 1000LL;
        NSDate *d = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)n];
        return [self displayStringFromDate:d];
    }
    return @"";
}

- (NSString *)displayStringFromDate:(NSDate *)date {
    if (!date) return @"";
    NSDateFormatter *outFmt = [[NSDateFormatter alloc] init];
    outFmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    outFmt.dateFormat = @"MMM dd, yyyy";
    return [outFmt stringFromDate:date] ?: @"";
}

- (NSString *)pickDate:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    for (NSString *k in keys) {
        NSString *formatted = [self formatDisplayDate:dict[k]];
        if (formatted.length > 0) return formatted;
    }
    return @"";
}

- (NSArray<HQITOrderHistoryItem *> *)parseList:(id)data {
    NSArray *arr = [self arrayFromData:data];
    NSMutableArray<HQITOrderHistoryItem *> *out = [NSMutableArray array];
    for (id obj in arr) {
        if (![obj isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *dict = (NSDictionary *)obj;
        HQITOrderHistoryItem *item = [[HQITOrderHistoryItem alloc] init];
        item.orderId = [self stringFrom:dict key:@"orderId"];
        item.productId = [self stringFrom:dict key:@"productId"];
        item.productName = [self stringFrom:dict key:@"productName"];
        if (item.productName.length == 0) item.productName = @"Appname";

        NSString *amountRaw = [self stringFrom:dict key:@"loanAmount"];
        item.amountText = [HQITAmountFormatter formatPlainAmount:amountRaw.length ? amountRaw : @"0" prefixCurrency:YES];

        NSInteger code = [self statusCodeFrom:dict];
        item.statusCode = code;
        NSString *title = nil;
        UIColor *textC = nil;
        UIColor *bgC = nil;
        [HQITOrderStatusStyle applyStyleForStatusCode:code title:&title textColor:&textC bgColor:&bgC];
        NSString *apiTitle = [self stringFrom:dict key:@"statusName"];
        if (apiTitle.length > 0 && [apiTitle rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].location != NSNotFound) {
            title = apiTitle;
        }
        item.statusTitle = title ?: @"";
        item.statusTextColor = textC;
        item.statusBgColor = bgC;

        NSString *leftLab = nil;
        NSString *rightLab = nil;
        [HQITOrderStatusStyle dateLabelsForStatusCode:code leftLabel:&leftLab rightLabel:&rightLab];
        item.leftDateLabel = leftLab;
        item.rightDateLabel = rightLab;

        // Date wire aliases: applyDate→resolution, loanDate→refusal, repayDate→learn,
        // repaymentDate→wicked, dueDate→plenty, payoutDate→fruitful, borrowingDate→stage
        if (code == 60 || code == 61) {
            item.leftDateValue = [self pickDate:dict keys:@[@"paymentDate", @"payoutDate", @"disbursementDate", @"loanTime", @"loanDate", @"applyTime", @"applyDate", @"borrowingDate", @"gmtCreate"]];
            item.rightDateValue = [self pickDate:dict keys:@[@"dueDate", @"dueTime", @"repaymentDate", @"repayDate"]];
        } else if (code == 70) {
            item.leftDateValue = [self pickDate:dict keys:@[@"paymentDate", @"payoutDate", @"disbursementDate", @"loanTime", @"loanDate", @"applyTime", @"applyDate"]];
            item.rightDateValue = [self pickDate:dict keys:@[@"repaymentDate", @"repayDate", @"settleDate", @"payOffDate", @"dueDate", @"dueTime"]];
        } else {
            item.leftDateValue = [self pickDate:dict keys:@[@"applyTime", @"applyDate", @"loanTime", @"loanDate", @"borrowingDate", @"gmtCreate", @"createTime"]];
            item.rightDateValue = [self pickDate:dict keys:@[@"dueDate", @"dueTime", @"repaymentDate", @"repayDate"]];
        }
        if (item.rightDateValue.length == 0) item.rightDateValue = @"-";

        item.orderDetailsLink = [self stringFrom:dict key:@"orderDetailsLink"];
        [out addObject:item];
    }
    return out;
}

@end
