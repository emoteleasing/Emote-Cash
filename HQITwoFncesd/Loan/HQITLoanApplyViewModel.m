

#import "HQITLoanApplyViewModel.h"
#import "HQITAmountFormatter.h"
#import "HQITNetworkClient.h"
#import "HQITSessionManager.h"
#import "HQITHUDHelper.h"
#import "HQITAppStartupManager.h"

@implementation HQITLoanApplyDetailRow
@end

@interface HQITLoanApplyViewModel ()
@property (nonatomic, copy, readwrite) NSString *productId;
@property (nonatomic, copy, readwrite) NSString *productName;
@property (nonatomic, copy, readwrite, nullable) NSString *productLogo;
@property (nonatomic, copy, readwrite) NSArray<NSDictionary *> *amountList;
@property (nonatomic, assign, readwrite) NSInteger selectedAmountIndex;
@property (nonatomic, assign, readwrite) NSInteger selectedTermIndex;
@property (nonatomic, assign, readwrite) BOOL isSubmitting;
@property (nonatomic, copy, readwrite) NSString *maskedBankAccount;
@property (nonatomic, copy, readwrite, nullable) NSString *bankCardBindId;
@property (nonatomic, strong) NSDictionary *rootData;
@property (nonatomic, assign, readwrite) NSInteger userType;
@end

@implementation HQITLoanApplyViewModel

- (instancetype)initWithProductId:(NSString *)productId
                         termData:(NSDictionary *)termData
               prefillProductName:(NSString *)prefillName
            prefillProductLogoURL:(NSString *)prefillLogo {
    self = [super init];
    if (self) {
        _productId = [productId copy] ?: @"";
        _rootData = [termData isKindOfClass:[NSDictionary class]] ? [termData copy] : @{};
        _agreed = YES;
        _selectedAmountIndex = 0;
        _selectedTermIndex = 0;
        _productName = [self stringFrom:_rootData key:@"productName"];
        if (_productName.length == 0) _productName = prefillName.length ? prefillName : @"Product";
        _productLogo = [self stringFrom:_rootData key:@"productLogo"];
        if (_productLogo.length == 0) _productLogo = prefillLogo;
        _amountList = [self parseAmountList:_rootData];
        [self parseBankFrom:_rootData];
        NSString *ut = [self stringFrom:_rootData key:@"userType"];
        _userType = ut.integerValue;
    }
    return self;
}

- (void)notify {
    if (self.onUpdated) self.onUpdated();
}

#pragma mark - Parse

- (NSArray<NSDictionary *> *)parseAmountList:(NSDictionary *)root {
    id raw = root[@"amountDetailList"];
    if (![raw isKindOfClass:[NSArray class]]) return @[];
    NSMutableDictionary *byAmount = [NSMutableDictionary dictionary];
    for (id row in (NSArray *)raw) {
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = (NSDictionary *)row;
        NSString *amt = [self loanAmountRawFrom:d];
        if (amt.length == 0) continue;
        if (!byAmount[amt]) byAmount[amt] = d;
    }
    NSArray *keys = [byAmount.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        double da = a.doubleValue, db = b.doubleValue;
        if (da > db) return NSOrderedAscending;
        if (da < db) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *k in keys) [out addObject:byAmount[k]];
    return out;
}

- (void)parseBankFrom:(NSDictionary *)root {
    NSDictionary *card = [self firstBankCardIn:root];
    if (!card) {
        for (NSDictionary *amt in self.amountList) {
            card = [self firstBankCardIn:amt];
            if (card) break;
        }
    }
    if (!card && [self stringFrom:root key:@"accountNo"].length) {
        card = root;
    }
    if (!card) {
        self.maskedBankAccount = @"—";
        self.bankCardBindId = nil;
        return;
    }
    self.bankCardBindId = [self stringFrom:card key:@"recordId"];
    NSString *acc = [self stringFrom:card key:@"accountNo"];
    self.maskedBankAccount = [self maskAccount:acc];
}

- (NSDictionary *)firstBankCardIn:(NSDictionary *)dict {
    id single = dict[@"bankCard"] ?: dict[@"bank_card"] ?: dict[@"bankCard"];
    if ([single isKindOfClass:[NSDictionary class]]) return single;
    for (NSString *k in @[@"bankCardList", @"bankCardList", @"bank_card_list", @"payAccountInfoList", @"pay_account_info_list"]) {
        id list = dict[k];
        if (![list isKindOfClass:[NSArray class]]) continue;
        NSDictionary *def = nil;
        for (id row in (NSArray *)list) {
            if (![row isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *d = (NSDictionary *)row;
            NSString *flag = [self stringFrom:d key:@"defaultFlag"];
            if ([flag isEqualToString:@"1"]) return d;
            if (!def) def = d;
        }
        if (def) return def;
    }
    return nil;
}

- (NSString *)maskAccount:(NSString *)account {
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < account.length; i++) {
        unichar c = [account characterAtIndex:i];
        if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
    }
    if (digits.length < 8) return account.length ? account : @"—";
    NSString *head = [digits substringToIndex:4];
    NSString *tail = [digits substringFromIndex:digits.length - 4];
    return [NSString stringWithFormat:@"%@ **** **** %@", head, tail];
}

#pragma mark - Current selection

- (NSDictionary *)currentAmount {
    if (self.selectedAmountIndex < 0 || self.selectedAmountIndex >= (NSInteger)self.amountList.count) return @{};
    return self.amountList[self.selectedAmountIndex];
}

- (NSArray<NSDictionary *> *)currentTerms {
    NSDictionary *amt = [self currentAmount];
    id list = amt[@"termDetailList"];
    if (![list isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *out = [NSMutableArray array];
    for (id row in (NSArray *)list) {
        if ([row isKindOfClass:[NSDictionary class]]) [out addObject:row];
    }
    return out;
}

- (NSDictionary *)currentTerm {
    NSArray *terms = [self currentTerms];
    if (terms.count == 0) return @{};
    NSInteger idx = MIN(MAX(self.selectedTermIndex, 0), (NSInteger)terms.count - 1);
    return terms[idx];
}

- (BOOL)isMultiAmount {
    return self.amountList.count > 1;
}

- (BOOL)isMultiTerm {
    return [self currentTerms].count > 1;
}

- (BOOL)isEMI {
    NSDictionary *term = [self currentTerm];
    NSInteger emis = [self integerFrom:term key:@"EMIs"];
    if (emis > 0) return YES;
    if ([self stringFrom:term key:@"EMIAmount"].length) return YES;
    if ([self stringFrom:term key:@"EMIRepayDate"].length) return YES;
    return NO;
}

- (NSInteger)emiCount {
    NSDictionary *term = [self currentTerm];
    NSInteger emis = [self integerFrom:term key:@"EMIs"];
    if (emis > 0) return emis;
    NSInteger days = [self integerFrom:term key:@"showTerm"];
    if (days >= 30) return MAX(1, (NSInteger)llround(days / 30.0));
    return 0;
}

#pragma mark - Display

- (NSString *)displayAmountAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.amountList.count) return @"";
    NSString *raw = [self loanAmountRawFrom:self.amountList[index]];
    return [HQITAmountFormatter formatPlainAmount:raw prefixCurrency:YES];
}

- (NSString *)currentLoanAmountRaw {
    return [self loanAmountRawFrom:[self currentAmount]];
}

- (NSString *)currentShowTermRaw {
    NSDictionary *term = [self currentTerm];
    NSString *show = [self stringFrom:term key:@"showTerm"];
    if (show.length) return show;
    NSInteger days = [self integerFrom:term key:@"loanTerm"];
    if (days > 0) return [NSString stringWithFormat:@"%ld", (long)days];
    return @"";
}

- (NSString *)formatTermDisplay:(NSString *)raw {
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return @"—";
    if ([self isEMI]) {
        NSInteger n = [self emiCount];
        if (n > 0) return [NSString stringWithFormat:@"%ld EMIS", (long)n];
    }
    NSString *lower = s.lowercaseString;
    if ([lower containsString:@"day"] || [lower containsString:@"emi"]) return s;
    // pure number
    NSCharacterSet *nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([s rangeOfCharacterFromSet:nonDigit].location == NSNotFound) {
        return [NSString stringWithFormat:@"%@ Days", s];
    }
    return s;
}

- (NSString *)currentTermDisplay {
    if ([self isEMI]) {
        NSInteger n = [self emiCount];
        if (n > 0) return [NSString stringWithFormat:@"%ld EMIS", (long)n];
    }
    return [self formatTermDisplay:[self currentShowTermRaw]];
}

- (NSString *)termSelectTitle {
    return [self isEMI] ? @"Select EMIS" : @"Select the loan term";
}

- (NSArray<NSString *> *)termOptionLabels {
    NSMutableArray *labels = [NSMutableArray array];
    NSArray *terms = [self currentTerms];
    for (NSInteger i = 0; i < (NSInteger)terms.count; i++) {
        NSDictionary *t = terms[i];
        NSString *show = [self stringFrom:t key:@"showTerm"];
        NSInteger emis = [self integerFrom:t key:@"EMIs"];
        if (emis > 0) {
            [labels addObject:[NSString stringWithFormat:@"%ld EMIS", (long)emis]];
        } else {
            [labels addObject:[self formatTermDisplay:show]];
        }
    }
    return labels;
}

- (NSArray<HQITLoanApplyDetailRow *> *)detailRows {
    NSDictionary *term = [self currentTerm];
    NSDictionary *amt = [self currentAmount];
    NSMutableArray *rows = [NSMutableArray array];

    if ([self isEMI]) {
        [rows addObject:[self rowTitle:@"1st EMI Date"
                                 value:[self formatDate:[self valueFromSources:@[term, amt, self.rootData]
                                                                         key:@"EMIRepayDate"]]
                               infoKey:nil
                            emphasized:YES]];
        [rows addObject:[self rowTitle:@"EMI Amount"
                                 value:[self formatMoney:[self emiAmountValue] prefix:YES]
                               infoKey:nil
                            emphasized:YES]];
    }

    NSString *received = [self valueFromSources:@[term, amt, self.rootData]
                                           key:@"arrivalAmount"];
    if (received.length == 0) {
        double loan = [self currentLoanAmountRaw].doubleValue;
        double fee = [self valueFromSources:@[term, amt, self.rootData]
                                       key:@"feeAmount"].doubleValue;
        if (loan > 0) received = [NSString stringWithFormat:@"%.0f", loan - fee];
    }
    [rows addObject:[self rowTitle:@"Amount received" value:[self formatMoney:received prefix:NO] infoKey:@"received" emphasized:NO]];
    [rows addObject:[self rowTitle:@"Service fee"
                             value:[self formatMoney:[self valueFromSources:@[term, amt, self.rootData]
                                                                       key:@"feeAmount"]
                                              prefix:NO]
                           infoKey:@"fee"
                        emphasized:NO]];
    [rows addObject:[self rowTitle:@"Interest"
                             value:[self formatMoney:[self valueFromSources:@[term, amt, self.rootData]
                                                                       key:@"interestAmount"]
                                              prefix:NO]
                           infoKey:@"interest"
                        emphasized:NO]];
    [rows addObject:[self rowTitle:@"GST"
                             value:[self formatMoney:[self valueFromSources:@[term, amt, self.rootData]
                                                                       key:@"taxAmount"]
                                              prefix:NO]
                           infoKey:nil
                        emphasized:NO]];
    [rows addObject:[self rowTitle:@"Date of application"
                             value:[self formatDate:[self valueFromSources:@[term, amt, self.rootData]
                                                                     key:@"borrowingDate"]]
                           infoKey:nil
                        emphasized:NO]];
    if (![self isEMI]) {
        [rows addObject:[self rowTitle:@"Due date"
                                 value:[self formatDate:[self valueFromSources:@[term, amt, self.rootData]
                                                                         key:@"repaymentDate"]]
                               infoKey:nil
                            emphasized:NO]];
    }
    return rows;
}

- (HQITLoanApplyDetailRow *)rowTitle:(NSString *)title
                               value:(NSString *)value
                             infoKey:(NSString *)infoKey
                          emphasized:(BOOL)emphasized {
    HQITLoanApplyDetailRow *r = [[HQITLoanApplyDetailRow alloc] init];
    r.title = title;
    r.value = value.length ? value : @"—";
    r.infoKey = infoKey;
    r.emphasized = emphasized;
    return r;
}

- (NSString *)emiAmountValue {
    NSDictionary *term = [self currentTerm];
    NSString *raw = [self stringFrom:term key:@"EMIAmount"];
    if (raw.length) return raw;
    double loan = [self currentLoanAmountRaw].doubleValue;
    NSInteger n = [self emiCount];
    if (loan <= 0 || n <= 0) return @"";
    NSString *rateStr = [self valueFromSources:@[term, [self currentAmount], self.rootData]
                                          key:@"lowestLoanInterestRate"];
    double dayRate = rateStr.doubleValue;
    NSInteger days = [self integerFrom:term key:@"showTerm"];
    if (days <= 0) days = n * 30;
    double interest = loan * dayRate * days;
    double total = loan + interest;
    return [NSString stringWithFormat:@"%.0f", ceil(total / n)];
}

#pragma mark - Select

- (void)selectAmountAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.amountList.count) return;
    self.selectedAmountIndex = index;
    self.selectedTermIndex = 0;
    [self notify];
}

- (void)selectTermAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)[self currentTerms].count) return;
    self.selectedTermIndex = index;
    [self notify];
}

- (BOOL)applyDefaultAmountTermSelection {
    if (self.amountList.count == 0) return NO;
    self.selectedAmountIndex = 0; // amountList is DESC, index 0 = max amount
    NSArray *terms = [self currentTerms];
    if (terms.count == 0) return NO;
    NSInteger bestIdx = 0;
    NSInteger bestVal = -1;
    for (NSInteger i = 0; i < (NSInteger)terms.count; i++) {
        NSInteger v = [self termNumericValue:terms[i]];
        if (v == NSIntegerMax) v = -1;
        if (v > bestVal) {
            bestVal = v;
            bestIdx = i;
        }
    }
    self.selectedTermIndex = bestIdx;
    [self notify];
    return YES;
}

- (NSInteger)termNumericValue:(NSDictionary *)term {
    NSInteger days = [self integerFrom:term key:@"showTerm"];
    if (days > 0) return days;
    NSInteger emis = [self integerFrom:term key:@"EMIs"];
    if (emis > 0) return emis;
    NSString *show = [self stringFrom:term key:@"showTerm"];
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < show.length; i++) {
        unichar c = [show characterAtIndex:i];
        if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
    }
    if (digits.length) return digits.integerValue;
    return NSIntegerMax;
}

#pragma mark - Submit

- (void)submitWithLongitude:(NSString *)longitude latitude:(NSString *)latitude {
    if (self.isSubmitting) return;

    NSString *lng = [longitude isKindOfClass:[NSString class]] ? longitude : @"";
    NSString *lat = [latitude isKindOfClass:[NSString class]] ? latitude : @"";
    BOOL force = [[HQITAppStartupManager shared] isForceContactMode];
    BOOL placeholder = [lng isEqualToString:@"-360.000000"] || [lat isEqualToString:@"-360.000000"];
    if (force && (lng.length == 0 || lat.length == 0 || placeholder)) {
        NSLog(@"[HQITLoanApply] block submit: force location missing lng=%@ lat=%@", lng, lat);
        return;
    }
    if (!force) {
        if (lng.length == 0) lng = @"-360.000000";
        if (lat.length == 0) lat = @"-360.000000";
    }

    self.isSubmitting = YES;
    [self notify];

    NSString *loanAmount = [self currentLoanAmountRaw] ?: @"";
    NSString *showTerm = [self currentShowTermRaw] ?: @"";
    NSString *deviceId = [HQITSessionManager shared].deviceId ?: @"";

    NSDictionary *signedData = @{
        @"productId": self.productId ?: @"",
        @"loanAmount": loanAmount,
        @"longitude": lng,
        @"latitude": lat,
        @"imei": @"null",
        @"serialNo": deviceId,
    };
    NSMutableDictionary *unsignedData = [NSMutableDictionary dictionary];
    unsignedData[@"showTerm"] = showTerm;
    if (self.bankCardBindId.length) unsignedData[@"bankCardBindId"] = self.bankCardBindId;

    [HQITHUDHelper showLoadingWithMessage:@"Processing..."];
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/userSubmitV3"
                                         signedData:signedData
                                       unsignedData:unsignedData
                                        showLoading:@NO
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [HQITHUDHelper hideLoading];
        NSString *orderId = @"";
        if ([response.data isKindOfClass:[NSDictionary class]]) {
            orderId = [self stringFrom:(NSDictionary *)response.data key:@"orderId"];
        }
        if (orderId.length == 0) {
            self.isSubmitting = NO;
            [self notify];
            if (self.onErrorMessage) self.onErrorMessage(@"Submit failed");
            return;
        }
        // Keep submitting lock; capture / success page takes over
        if (self.onSubmitSuccess) self.onSubmitSuccess(orderId);
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [HQITHUDHelper hideLoading];
        self.isSubmitting = NO;
        [self notify];
        if (self.onErrorMessage) self.onErrorMessage(message.length ? message : @"Submit failed");
    }];
}

- (void)resetSubmittingState {
    self.isSubmitting = NO;
    [self notify];
}

- (NSString *)formattedLoanAmountDisplay {
    NSString *raw = [self currentLoanAmountRaw];
    return raw.length ? [HQITAmountFormatter formatPlainAmount:raw prefixCurrency:YES] : @"—";
}

#pragma mark - Helpers

- (NSString *)loanAmountRawFrom:(NSDictionary *)d {
    return [self stringFrom:d key:@"loanAmount"];
}

- (NSString *)formatMoney:(NSString *)raw prefix:(BOOL)prefix {
    if (raw.length == 0) return @"—";
    return [HQITAmountFormatter formatPlainAmount:raw prefixCurrency:prefix];
}

- (NSString *)formatDate:(NSString *)raw {
    if (raw.length == 0) return @"—";
    // timestamp ms/s
    NSCharacterSet *nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([raw rangeOfCharacterFromSet:nonDigit].location == NSNotFound && raw.length >= 10) {
        long long v = raw.longLongValue;
        if (v > 1000000000000LL) v /= 1000; // ms → s
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)v];
        return [[self dateFormatter] stringFromDate:date] ?: raw;
    }
    // try parse yyyy-MM-dd
    NSDateFormatter *inFmt = [[NSDateFormatter alloc] init];
    inFmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    for (NSString *fmt in @[@"yyyy-MM-dd", @"MMM dd, yyyy", @"yyyy/MM/dd", @"dd-MM-yyyy"]) {
        inFmt.dateFormat = fmt;
        NSDate *d = [inFmt dateFromString:raw];
        if (d) return [[self dateFormatter] stringFromDate:d] ?: raw;
    }
    return raw;
}

- (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.dateFormat = @"MMM dd, yyyy";
    });
    return fmt;
}

- (NSString *)valueFromSources:(NSArray<NSDictionary *> *)sources key:(NSString *)key {
    return [self valueFromSources:sources keys:(key.length ? @[key] : @[])];
}

- (NSString *)valueFromSources:(NSArray<NSDictionary *> *)sources keys:(NSArray<NSString *> *)keys {
    for (NSDictionary *d in sources) {
        NSString *v = [self stringFrom:d keys:keys];
        if (v.length) return v;
    }
    return @"";
}


- (NSString *)stringFrom:(NSDictionary *)dict key:(NSString *)key {
    return [self stringFrom:dict keys:(key.length ? @[key] : @[])];
}

- (NSInteger)integerFrom:(NSDictionary *)dict key:(NSString *)key {
    return [self stringFrom:dict key:key].integerValue;
}

- (NSString *)stringFrom:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    if (![dict isKindOfClass:[NSDictionary class]]) return @"";
    for (NSString *k in keys) {
        id v = dict[k];
        if (v == nil || v == [NSNull null]) continue;
        NSString *s = [NSString stringWithFormat:@"%@", v];
        if (s.length && ![s isEqualToString:@"(null)"]) return s;
    }
    return @"";
}

- (NSInteger)integerFrom:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    NSString *s = [self stringFrom:dict keys:keys];
    return s.integerValue;
}

@end
