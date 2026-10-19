
#import "HQITAccurateRecommendViewModel.h"
#import "HQITLoanApplyViewModel.h"
#import "HQITAmountFormatter.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITSessionManager.h"
#import "HQITAppStartupManager.h"
#import "HQITHUDHelper.h"

@implementation HQITAccurateRecommendProductItem

- (NSInteger)amountStepCount {
    return (NSInteger)self.amountSteps.count;
}

- (double)loanAmountAtIndex:(NSInteger)idx {
    if (idx < 0 || idx >= (NSInteger)self.amountSteps.count) return 0;
    return [[self class] numberFrom:self.amountSteps[idx] key:@"loanAmount"];
}

- (NSDictionary *)currentAmountDetail {
    if (self.selectedAmountIndex < 0 || self.selectedAmountIndex >= (NSInteger)self.amountSteps.count) return @{};
    return self.amountSteps[self.selectedAmountIndex] ?: @{};
}

- (NSArray<NSDictionary *> *)currentTerms {
    NSDictionary *amt = [self currentAmountDetail];
    id list = amt[@"termDetailList"];
    if ([list isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for (id row in (NSArray *)list) {
            if ([row isKindOfClass:[NSDictionary class]]) [out addObject:row];
        }
        if (out.count > 0) return out;
    }
    if ([amt isKindOfClass:[NSDictionary class]] && amt.count > 0) return @[amt];
    return @[];
}

- (NSDictionary *)currentTermDetail {
    NSArray *terms = [self currentTerms];
    if (terms.count == 0) return @{};
    NSInteger idx = MIN(MAX(self.selectedTermIndex, 0), (NSInteger)terms.count - 1);
    return terms[idx];
}

- (NSInteger)termNumericValue:(NSDictionary *)term {
    NSInteger loanTerm = [[self class] integerFrom:term key:@"loanTerm"];
    if (loanTerm > 0) return loanTerm;
    NSInteger days = [[self class] integerFrom:term key:@"showTerm"];
    if (days > 0) return days;
    NSInteger emis = [[self class] integerFrom:term key:@"EMIs"];
    if (emis <= 0) emis = [[self class] integerFrom:term key:@"EMITenure"];
    if (emis > 0) return emis;
    NSString *show = [[self class] stringFrom:term key:@"showTerm"];
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < show.length; i++) {
        unichar c = [show characterAtIndex:i];
        if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
    }
    if (digits.length) return digits.integerValue;
    return 0;
}

- (NSString *)showTermStringFromTerm:(NSDictionary *)term {
    if (![term isKindOfClass:[NSDictionary class]] || term.count == 0) return @"";
    NSString *show = [[self class] stringFrom:term key:@"showTerm"];
    if (show.length) return show;
    NSInteger days = [[self class] integerFrom:term key:@"loanTerm"];
    if (days > 0) return [NSString stringWithFormat:@"%ld", (long)days];
    NSInteger emis = [[self class] integerFrom:term key:@"EMIs"];
    if (emis <= 0) emis = [[self class] integerFrom:term key:@"EMITenure"];
    if (emis > 0) return [NSString stringWithFormat:@"%ld", (long)emis];
    return @"";
}

- (NSString *)loanTermStringFromTerm:(NSDictionary *)term {
    if (![term isKindOfClass:[NSDictionary class]] || term.count == 0) return @"";
    NSString *loanTerm = [[self class] stringFrom:term key:@"loanTerm"];
    if (loanTerm.length) return loanTerm;
    NSString *show = [[self class] stringFrom:term key:@"showTerm"];
    if (show.length) return show;
    NSInteger emis = [[self class] integerFrom:term key:@"EMIs"];
    if (emis <= 0) emis = [[self class] integerFrom:term key:@"EMITenure"];
    if (emis > 0) return [NSString stringWithFormat:@"%ld", (long)emis];
    return @"";
}

- (NSInteger)highestTermIndexForCurrentAmount {
    NSArray *terms = [self currentTerms];
    if (terms.count == 0) return 0;
    NSInteger bestIdx = 0;
    NSInteger bestVal = -1;
    for (NSInteger i = 0; i < (NSInteger)terms.count; i++) {
        NSInteger v = [self termNumericValue:terms[i]];
        if (v > bestVal) {
            bestVal = v;
            bestIdx = i;
        }
    }
    return bestIdx;
}

- (void)applyHighestTermForCurrentAmount {
    NSArray *terms = [self currentTerms];
    if (terms.count == 0) {
        self.selectedTermIndex = 0;
        return;
    }
    self.selectedTermIndex = [self highestTermIndexForCurrentAmount];
}

- (NSString *)currentLoanAmountRaw {
    NSString *raw = [[self class] stringFrom:[self currentTermDetail] key:@"loanAmount"];
    if (raw.length == 0) raw = [[self class] stringFrom:[self currentAmountDetail] key:@"loanAmount"];
    return raw ?: @"";
}

- (NSString *)currentShowTermRaw {
    NSString *show = [self showTermStringFromTerm:[self currentTermDetail]];
    if (show.length) return show;
    return [self showTermStringFromTerm:[self currentAmountDetail]];
}

- (NSString *)loanTermRawForSubmit {
    NSArray *terms = [self currentTerms];
    if (terms.count == 0) return @"";
    NSInteger bestIdx = [self highestTermIndexForCurrentAmount];
    self.selectedTermIndex = bestIdx;
    return [self loanTermStringFromTerm:terms[bestIdx]] ?: @"";
}

- (NSString *)displayLoanAmount {
    return [HQITAmountFormatter formatPlainAmount:@([self currentLoanAmountValue]) prefixCurrency:YES];
}

- (NSString *)displayMaxLoanAmount {
    if (self.amountSteps.count == 0) return @"₹0";
    double max = [self loanAmountAtIndex:(NSInteger)self.amountSteps.count - 1];
    return [HQITAmountFormatter formatPlainAmount:@(max) prefixCurrency:YES];
}

- (NSString *)displayArrivalAmount {
    return [HQITAmountFormatter formatPlainAmount:@([self currentArrivalAmountValue]) prefixCurrency:YES];
}

- (BOOL)isMultiTerm {
    return [self currentTerms].count > 1;
}

- (BOOL)isEMI {
    NSDictionary *term = [self currentTermDetail];
    if ([[self class] integerFrom:term key:@"EMIs"] > 0) return YES;
    if ([[self class] integerFrom:term key:@"EMITenure"] > 0) return YES;
    NSString *emiAmt = [[self class] stringFrom:term key:@"EMIAmount"];
    if (emiAmt.length) return YES;
    NSString *emiDate = [[self class] stringFrom:term key:@"EMIRepayDate"];
    return emiDate.length > 0;
}

- (NSInteger)emiCount {
    NSDictionary *term = [self currentTermDetail];
    NSInteger emis = [[self class] integerFrom:term key:@"EMIs"];
    if (emis <= 0) emis = [[self class] integerFrom:term key:@"EMITenure"];
    if (emis > 0) return emis;
    NSInteger days = [[self class] integerFrom:term key:@"showTerm"];
    if (days >= 30) return MAX(1, (NSInteger)llround(days / 30.0));
    return 0;
}

- (NSString *)formatDaysDisplayFromRaw:(NSString *)raw {
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return @"—";
    NSString *lower = s.lowercaseString;
    if ([lower containsString:@"day"]) {
        NSCharacterSet *nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        NSString *digits = [[s componentsSeparatedByCharactersInSet:nonDigit] componentsJoinedByString:@""];
        if (digits.length) return [NSString stringWithFormat:@"%@ (Days)", digits];
        return s;
    }
    if ([lower containsString:@"emi"]) return s;
    NSCharacterSet *nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([s rangeOfCharacterFromSet:nonDigit].location == NSNotFound) {
        return [NSString stringWithFormat:@"%@ (Days)", s];
    }
    return s;
}

- (NSString *)formatTermDisplay:(NSString *)raw {
    if ([self isEMI]) {
        NSInteger n = [self emiCount];
        if (n > 0) return [NSString stringWithFormat:@"%ld EMIS", (long)n];
    }
    return [self formatDaysDisplayFromRaw:raw];
}

- (NSString *)currentTermDisplay {
    if ([self isEMI]) {
        NSInteger n = [self emiCount];
        if (n > 0) return [NSString stringWithFormat:@"%ld EMIS", (long)n];
    }
    return [self formatTermDisplay:[self currentShowTermRaw]];
}

- (NSString *)displayRepaymentTerm {
    return [self currentTermDisplay];
}

- (NSString *)termSelectTitle {
    return [self isEMI] ? @"Select EMIs" : @"Select the loan term";
}

- (NSString *)termRowTitle {
    if ([self isMultiTerm]) return [self termSelectTitle];
    return @"Loan term";
}

- (NSArray<NSString *> *)termOptionLabels {
    NSMutableArray *labels = [NSMutableArray array];
    NSArray *terms = [self currentTerms];
    for (NSInteger i = 0; i < (NSInteger)terms.count; i++) {
        NSDictionary *t = terms[i];
        NSString *show = [[self class] stringFrom:t key:@"showTerm"];
        NSInteger emis = [[self class] integerFrom:t key:@"EMIs"];
        if (emis <= 0) emis = [[self class] integerFrom:t key:@"EMITenure"];
        if (emis > 0) {
            [labels addObject:[NSString stringWithFormat:@"%ld EMIS", (long)emis]];
        } else {
            NSString *formatted = show;
            if (formatted.length == 0) {
                NSInteger days = [[self class] integerFrom:t key:@"loanTerm"];
                formatted = days > 0 ? [NSString stringWithFormat:@"%ld", (long)days] : @"";
            }
            [labels addObject:[self formatDaysDisplayFromRaw:formatted]];
        }
    }
    return labels;
}

- (void)selectTermAtIndex:(NSInteger)index {
    NSArray *terms = [self currentTerms];
    if (index < 0 || index >= (NSInteger)terms.count) return;
    self.selectedTermIndex = index;
}

- (double)currentFeeAmount {
    return [[self class] numberFrom:[self currentTermDetail] key:@"feeAmount"];
}

- (double)currentArrivalAmountValue {
    return [[self class] numberFrom:[self currentTermDetail] key:@"arrivalAmount"];
}

- (double)currentLoanAmountValue {
    double v = [[self class] numberFrom:[self currentTermDetail] key:@"loanAmount"];
    if (v <= 0) v = [[self class] numberFrom:[self currentAmountDetail] key:@"loanAmount"];
    return v;
}

- (NSArray<HQITLoanApplyDetailRow *> *)loanDetailRows {
    NSDictionary *term = [self currentTermDetail];
    NSDictionary *amt = [self currentAmountDetail];
    NSMutableArray *rows = [NSMutableArray array];

    if ([self isEMI]) {
        [rows addObject:[self detailTitle:@"1st EMI Date"
                                    value:[self formatDate:[[self class] stringFrom:term key:@"EMIRepayDate"]]
                                  infoKey:nil
                               emphasized:YES]];
        NSString *emiRaw = [[self class] stringFrom:term key:@"EMIAmount"];
        [rows addObject:[self detailTitle:@"EMI Amount"
                                    value:[HQITAmountFormatter formatPlainAmount:emiRaw.length ? emiRaw : @"0" prefixCurrency:YES]
                                  infoKey:nil
                               emphasized:YES]];
    }

    NSString *received = [[self class] stringFrom:term key:@"arrivalAmount"];
    if (received.length == 0) {
        double loan = [self currentLoanAmountValue];
        double fee = [[self class] numberFrom:term key:@"feeAmount"];
        if (loan > 0) received = [NSString stringWithFormat:@"%.0f", loan - fee];
    }
    [rows addObject:[self detailTitle:@"Amount received"
                                value:[HQITAmountFormatter formatPlainAmount:received.length ? received : @"0" prefixCurrency:NO]
                              infoKey:@"received"
                           emphasized:NO]];
    [rows addObject:[self detailTitle:@"Service fee"
                                value:[HQITAmountFormatter formatPlainAmount:[[self class] stringFrom:term key:@"feeAmount"] ?: @"0" prefixCurrency:NO]
                              infoKey:@"fee"
                           emphasized:NO]];
    [rows addObject:[self detailTitle:@"Interest"
                                value:[HQITAmountFormatter formatPlainAmount:[[self class] stringFrom:term key:@"interestAmount"] ?: @"0" prefixCurrency:NO]
                              infoKey:@"interest"
                           emphasized:NO]];
    [rows addObject:[self detailTitle:@"GST"
                                value:[HQITAmountFormatter formatPlainAmount:[[self class] stringFrom:term key:@"taxAmount"] ?: @"0" prefixCurrency:NO]
                              infoKey:nil
                           emphasized:NO]];
    NSString *borrow = [[self class] stringFrom:term key:@"borrowingDate"];
    if (borrow.length == 0) borrow = [[self class] stringFrom:amt key:@"borrowingDate"];
    [rows addObject:[self detailTitle:@"Date of application"
                                value:[self formatDate:borrow]
                              infoKey:nil
                           emphasized:NO]];
    NSString *due = [[self class] stringFrom:term key:@"repaymentDate"];
    [rows addObject:[self detailTitle:@"Due date"
                                value:[self formatDate:due]
                              infoKey:nil
                           emphasized:NO]];
    return rows;
}

- (HQITLoanApplyDetailRow *)detailTitle:(NSString *)title
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

- (NSString *)formatDate:(NSString *)raw {
    if (raw.length == 0) return @"—";
    NSCharacterSet *nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([raw rangeOfCharacterFromSet:nonDigit].location == NSNotFound && raw.length >= 10) {
        long long v = raw.longLongValue;
        if (v > 1000000000000LL) v /= 1000;
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)v];
        return [self.dateFormatter stringFromDate:date] ?: raw;
    }
    NSDateFormatter *inFmt = [[NSDateFormatter alloc] init];
    inFmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    for (NSString *fmt in @[@"yyyy-MM-dd", @"MMM dd, yyyy", @"yyyy/MM/dd", @"dd-MM-yyyy"]) {
        inFmt.dateFormat = fmt;
        NSDate *d = [inFmt dateFromString:raw];
        if (d) return [self.dateFormatter stringFromDate:d] ?: raw;
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

+ (NSString *)stringFrom:(NSDictionary *)dict key:(NSString *)key {
    if (![dict isKindOfClass:[NSDictionary class]]) return @"";
    id v = dict[key];
    if (v == nil || v == [NSNull null]) return @"";
    NSString *s = [NSString stringWithFormat:@"%@", v];
    if ([s isEqualToString:@"(null)"]) return @"";
    return s;
}

+ (double)numberFrom:(NSDictionary *)dict key:(NSString *)key {
    if (![dict isKindOfClass:[NSDictionary class]]) return 0;
    id v = dict[key];
    if (v == nil || v == [NSNull null]) return 0;
    return [[NSString stringWithFormat:@"%@", v] doubleValue];
}

+ (NSInteger)integerFrom:(NSDictionary *)dict key:(NSString *)key {
    return (NSInteger)llround([self numberFrom:dict key:key]);
}

@end

@interface HQITAccurateRecommendViewModel ()
@property (nonatomic, copy, readwrite) NSArray<HQITAccurateRecommendProductItem *> *products;
@property (nonatomic, copy, readwrite) NSString *maskedBankAccount;
@property (nonatomic, assign, readwrite) BOOL hasBankCard;
@property (nonatomic, assign, readwrite) BOOL isSubmitting;
@property (nonatomic, copy, nullable) NSString *bankCardBindId;
@end

@implementation HQITAccurateRecommendViewModel

- (instancetype)initWithRecommendData:(id)data {
    self = [super init];
    if (self) {
        _agreed = YES;
        _products = [self parseProducts:data];
        _bankCardBindId = [self bindIdFromRecommendData:data];
        [self resolveBankCard];
    }
    return self;
}

+ (BOOL)hasProductsInRecommendData:(id)data {
    NSArray *list = [self productInfoListFrom:data];
    return list.count > 0;
}

+ (NSArray *)productInfoListFrom:(id)data {
    if (![data isKindOfClass:[NSDictionary class]]) {
        if ([data isKindOfClass:[NSArray class]]) return (NSArray *)data;
        return @[];
    }
    NSDictionary *d = (NSDictionary *)data;
    id list = d[@"productInfoList"] ?: d[@"productList"];
    return [list isKindOfClass:[NSArray class]] ? list : @[];
}

- (void)notify {
    if (self.onUpdated) self.onUpdated();
}

- (NSString *)resolveProductIdFrom:(NSDictionary *)d termV3:(NSDictionary *)termV3 {
    for (NSDictionary *src in @[d ?: @{}, termV3 ?: @{}]) {
        for (NSString *key in @[@"productId", @"outward", @"beyond"]) {
            NSString *pid = [self stringFrom:src key:key];
            if (pid.length) return pid;
        }
    }
    return @"";
}

- (NSArray<HQITAccurateRecommendProductItem *> *)parseProducts:(id)data {
    NSArray *list = [[self class] productInfoListFrom:data];
    NSMutableArray *out = [NSMutableArray array];
    for (id obj in list) {
        if (![obj isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = (NSDictionary *)obj;
        NSDictionary *termV3 = d[@"productTermV3Response"];
        if (![termV3 isKindOfClass:[NSDictionary class]]) {
            if ([d[@"amountDetailList"] isKindOfClass:[NSArray class]]) {
                termV3 = d;
            } else {
                termV3 = @{};
            }
        }
        HQITAccurateRecommendProductItem *item = [[HQITAccurateRecommendProductItem alloc] init];
        item.productId = [self resolveProductIdFrom:d termV3:termV3];
        item.productName = [self stringFrom:d key:@"productName"];
        if (item.productName.length == 0) item.productName = [self stringFrom:termV3 key:@"productName"];
        if (item.productName.length == 0) item.productName = item.productId.length ? item.productId : @"Product";
        item.productLogo = [self stringFrom:d key:@"productLogo"];
        if (item.productLogo.length == 0) item.productLogo = [self stringFrom:termV3 key:@"productLogo"];
        item.amountSteps = [self parseAmountSteps:termV3];
        if (item.amountSteps.count == 0) continue;
        if (item.productId.length == 0) continue;
        item.selectedAmountIndex = (NSInteger)item.amountSteps.count - 1;
        [item applyHighestTermForCurrentAmount];
        item.selected = YES;
        item.bankCard = [self firstBankCardIn:termV3] ?: [self firstBankCardIn:d];
        [out addObject:item];
    }
    return out;
}

- (NSArray<NSDictionary *> *)parseAmountSteps:(NSDictionary *)termV3 {
    id raw = termV3[@"amountDetailList"];
    if (![raw isKindOfClass:[NSArray class]]) return @[];
    NSMutableDictionary<NSString *, NSMutableDictionary *> *byAmount = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSMutableArray *> *flatTerms = [NSMutableDictionary dictionary];
    for (id row in (NSArray *)raw) {
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = (NSDictionary *)row;
        NSString *amt = [self stringFrom:d key:@"loanAmount"];
        if (amt.length == 0) continue;
        id nested = d[@"termDetailList"];
        BOOL hasNested = [nested isKindOfClass:[NSArray class]] && [(NSArray *)nested count] > 0;
        if (!byAmount[amt]) {
            byAmount[amt] = [d mutableCopy];
        }
        if (hasNested) {
            continue;
        }
        if (!flatTerms[amt]) flatTerms[amt] = [NSMutableArray array];
        [flatTerms[amt] addObject:d];
    }
    for (NSString *amt in flatTerms) {
        NSMutableDictionary *node = byAmount[amt];
        id existing = node[@"termDetailList"];
        if ([existing isKindOfClass:[NSArray class]] && [(NSArray *)existing count] > 0) continue;
        node[@"termDetailList"] = [flatTerms[amt] copy];
    }
    NSArray *keys = [byAmount.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        double da = a.doubleValue, db = b.doubleValue;
        if (da < db) return NSOrderedAscending;
        if (da > db) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *k in keys) [out addObject:[byAmount[k] copy]];
    return out;
}

- (NSDictionary *)firstBankCardIn:(NSDictionary *)dict {
    id list = dict[@"bankCardList"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id row in (NSArray *)list) {
            if ([row isKindOfClass:[NSDictionary class]]) return row;
        }
    }
    return nil;
}

- (NSString *)bindIdFromRecommendData:(id)data {
    NSDictionary *card = nil;
    if ([data isKindOfClass:[NSDictionary class]]) {
        card = [self firstBankCardIn:(NSDictionary *)data];
        NSString *bindId = [self stringFrom:card key:@"bindId"];
        if (bindId.length) return bindId;
        for (id obj in [[self class] productInfoListFrom:data]) {
            if (![obj isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *d = (NSDictionary *)obj;
            NSDictionary *termV3 = d[@"productTermV3Response"];
            if (![termV3 isKindOfClass:[NSDictionary class]]) termV3 = nil;
            card = [self firstBankCardIn:termV3] ?: [self firstBankCardIn:d];
            bindId = [self stringFrom:card key:@"bindId"];
            if (bindId.length) return bindId;
        }
    }
    for (HQITAccurateRecommendProductItem *p in self.products) {
        if (!p.bankCard) continue;
        NSString *bindId = [self stringFrom:p.bankCard key:@"bindId"];
        if (bindId.length) return bindId;
    }
    return nil;
}

- (NSString *)maskedBankAccountFrom:(NSString *)raw {
    NSString *digits = [[raw componentsSeparatedByCharactersInSet:
                         [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                        componentsJoinedByString:@""];
    if (digits.length == 0) return @"—";
    if (digits.length <= 8) return digits;
    NSString *head = [digits substringToIndex:4];
    NSString *tail = [digits substringFromIndex:digits.length - 4];
    return [NSString stringWithFormat:@"%@ **** **** %@", head, tail];
}

- (void)resolveBankCard {
    NSDictionary *card = nil;
    for (HQITAccurateRecommendProductItem *p in self.products) {
        if (p.bankCard) { card = p.bankCard; break; }
    }
    if (!card) {
        self.hasBankCard = NO;
        self.maskedBankAccount = @"";
        return;
    }
    self.hasBankCard = YES;
    NSString *acc = [self stringFrom:card key:@"accountNo"];
    if (acc.length == 0) acc = [self stringFrom:card key:@"cardNo"];
    self.maskedBankAccount = [self maskedBankAccountFrom:acc];
}

- (void)selectAllProductsWithMaxAmountAndHighestTerm {
    for (HQITAccurateRecommendProductItem *p in self.products) {
        if (p.amountSteps.count == 0) {
            p.selected = NO;
            continue;
        }
        p.selectedAmountIndex = (NSInteger)p.amountSteps.count - 1;
        [p applyHighestTermForCurrentAmount];
        p.selected = YES;
        NSLog(@"[HQITAccurateRecommend] auto-select productId=%@ amount=%@ loanTerm=%@",
              p.productId, [p currentLoanAmountRaw], [p loanTermRawForSubmit]);
    }
    [self notify];
}

- (void)toggleProductSelectedAtIndex:(NSInteger)index {
    if (self.isSubmitting) return;
    if (index < 0 || index >= (NSInteger)self.products.count) return;
    HQITAccurateRecommendProductItem *p = self.products[index];
    p.selected = !p.selected;
    [self notify];
}

- (void)setAmountStepIndex:(NSInteger)stepIndex forProductAtIndex:(NSInteger)productIndex {
    if (self.isSubmitting) return;
    if (productIndex < 0 || productIndex >= (NSInteger)self.products.count) return;
    HQITAccurateRecommendProductItem *p = self.products[productIndex];
    if (stepIndex < 0 || stepIndex >= p.amountStepCount) return;
    p.selectedAmountIndex = stepIndex;
    [p applyHighestTermForCurrentAmount];
    [self notify];
}

- (void)selectTermAtIndex:(NSInteger)termIndex forProductAtIndex:(NSInteger)productIndex {
    if (self.isSubmitting) return;
    if (productIndex < 0 || productIndex >= (NSInteger)self.products.count) return;
    HQITAccurateRecommendProductItem *p = self.products[productIndex];
    [p selectTermAtIndex:termIndex];
    [self notify];
}

- (double)sumSelected:(double (^)(HQITAccurateRecommendProductItem *p))block {
    double sum = 0;
    for (HQITAccurateRecommendProductItem *p in self.products) {
        if (!p.selected) continue;
        sum += block(p);
    }
    return sum;
}

- (NSString *)totalAmountDisplay {
    return [HQITAmountFormatter formatPlainAmount:@([self sumSelected:^double(HQITAccurateRecommendProductItem *p) {
        return [p currentLoanAmountValue];
    }]) prefixCurrency:YES];
}

- (NSString *)totalFeeDisplay {
    double amount = [self sumSelected:^double(HQITAccurateRecommendProductItem *p) {
        return [p currentLoanAmountValue];
    }];
    double arrival = [self sumSelected:^double(HQITAccurateRecommendProductItem *p) {
        return [p currentArrivalAmountValue];
    }];
    double fee = amount - arrival;
    if (fee < 0) fee = 0;
    return [HQITAmountFormatter formatPlainAmount:@(fee) prefixCurrency:YES];
}

- (NSString *)totalArrivalDisplay {
    return [HQITAmountFormatter formatPlainAmount:@([self sumSelected:^double(HQITAccurateRecommendProductItem *p) {
        return [p currentArrivalAmountValue];
    }]) prefixCurrency:YES];
}

- (NSInteger)selectedProductCount {
    NSInteger n = 0;
    for (HQITAccurateRecommendProductItem *p in self.products) {
        if (p.selected) n++;
    }
    return n;
}

- (BOOL)canApply {
    return self.agreed && !self.isSubmitting;
}

- (HQITAccurateRecommendProductItem *)firstSelectedProduct {
    for (HQITAccurateRecommendProductItem *p in self.products) {
        if (p.selected) return p;
    }
    return nil;
}

#pragma mark - Submit

- (void)appendOrderId:(NSString *)raw into:(NSMutableArray *)out seen:(NSMutableSet *)seen {
    if (![raw isKindOfClass:[NSString class]]) return;
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0 || [s isEqualToString:@"(null)"]) return;
    NSArray *parts = [s componentsSeparatedByString:@","];
    for (NSString *part in parts) {
        NSString *t = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length == 0 || [seen containsObject:t]) continue;
        [seen addObject:t];
        [out addObject:t];
    }
}

- (void)collectOrderIdsFrom:(id)data into:(NSMutableArray *)out seen:(NSMutableSet *)seen {
    if ([data isKindOfClass:[NSString class]]) {
        [self appendOrderId:(NSString *)data into:out seen:seen];
        return;
    }
    if ([data isKindOfClass:[NSNumber class]]) {
        [self appendOrderId:[(NSNumber *)data stringValue] into:out seen:seen];
        return;
    }
    if ([data isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)data) {
            [self collectOrderIdsFrom:item into:out seen:seen];
        }
        return;
    }
    if (![data isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *d = (NSDictionary *)data;
    NSUInteger before = out.count;
    for (NSString *key in @[@"orderId", @"currentOrderId", @"orderIdList", @"orderList", @"records", @"list", @"objection"]) {
        if (d[key] != nil) {
            [self collectOrderIdsFrom:d[key] into:out seen:seen];
        }
    }
    if (out.count == before) {
        for (id value in d.allValues) {
            [self collectOrderIdsFrom:value into:out seen:seen];
        }
    }
}

- (NSArray<NSString *> *)allOrderIdsFrom:(id)data {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    [self collectOrderIdsFrom:data into:out seen:seen];
    return [out copy];
}

- (NSString *)anyOrderIdFrom:(id)data {
    NSArray *all = [self allOrderIdsFrom:data];
    return all.firstObject ?: @"";
}

- (BOOL)collectSubmitArraysIds:(NSMutableArray *)ids
                       amounts:(NSMutableArray *)amounts
                         terms:(NSMutableArray *)terms {
    [ids removeAllObjects];
    [amounts removeAllObjects];
    [terms removeAllObjects];
    for (HQITAccurateRecommendProductItem *p in self.products) {
        if (!p.selected) continue;
        NSString *pid = [p.productId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
        NSString *amt = [p currentLoanAmountRaw] ?: @"";
        NSString *term = [p loanTermRawForSubmit] ?: @"";
        if (pid.length == 0 || amt.length == 0 || term.length == 0) continue;
        [ids addObject:pid];
        [amounts addObject:amt];
        [terms addObject:term];
        NSLog(@"[HQITAccurateRecommend] submit item productId=%@ amount=%@ loanTerms(loanTerm)=%@ amountTermCount=%ld",
              pid, amt, term, (long)[p currentTerms].count);
    }
    return ids.count > 0;
}

- (BOOL)isForceCaptureMode {
    return [[HQITAppStartupManager shared] isForceContactMode];
}

- (void)submitWithLongitude:(NSString *)longitude latitude:(NSString *)latitude {
    if (self.isSubmitting) return;
    if ([self selectedProductCount] == 0) {
        if (self.onErrorMessage) self.onErrorMessage(@"Please select at least one product");
        return;
    }
    NSMutableArray *ids = [NSMutableArray array];
    NSMutableArray *amounts = [NSMutableArray array];
    NSMutableArray *terms = [NSMutableArray array];
    if (![self collectSubmitArraysIds:ids amounts:amounts terms:terms]) {
        if (self.onErrorMessage) self.onErrorMessage(@"Submit failed");
        return;
    }

    NSString *lng = [longitude isKindOfClass:[NSString class]] ? longitude : @"";
    NSString *lat = [latitude isKindOfClass:[NSString class]] ? latitude : @"";
    BOOL force = [self isForceCaptureMode];
    BOOL placeholder = [lng isEqualToString:@"-360.000000"] || [lat isEqualToString:@"-360.000000"];
    if (force && (lng.length == 0 || lat.length == 0 || placeholder)) {
        NSLog(@"[HQITAccurateRecommend] block submit: force=%d lng=%@ lat=%@", force, lng, lat);
        return;
    }
    if (!force) {
        if (lng.length == 0) lng = @"-360.000000";
        if (lat.length == 0) lat = @"-360.000000";
    }

    self.isSubmitting = YES;
    [self notify];

    NSString *deviceId = [HQITSessionManager shared].deviceId ?: @"";
    NSDictionary *signedData = @{
        @"productIds": [ids componentsJoinedByString:@","],
        @"loanAmounts": [amounts componentsJoinedByString:@","],
        @"loanTerms": [terms componentsJoinedByString:@","],
        @"longitude": lng,
        @"latitude": lat,
        @"imei": @"null",
        @"serialNo": deviceId,
    };
    NSDictionary *unsignedData = nil;
    if (self.bankCardBindId.length) {
        unsignedData = @{@"bankCardBindId": self.bankCardBindId};
    }
    NSLog(@"[HQITAccurateRecommend] submit productIds=%@ loanAmounts=%@ loanTerms=%@ longitude=%@ latitude=%@ serialNo=%@ bankCardBindId=%@",
          signedData[@"productIds"], signedData[@"loanAmounts"], signedData[@"loanTerms"], lng, lat, deviceId,
          self.bankCardBindId ?: @"");

    [HQITHUDHelper showLoadingWithMessage:@"Processing..."];
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/userSubmitDcUpgrade"
                                         signedData:signedData
                                       unsignedData:unsignedData
                                        showLoading:@NO
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [HQITHUDHelper hideLoading];
        NSArray<NSString *> *orderIds = [self allOrderIdsFrom:response.data];
        if (orderIds.count == 0 && [response.data isKindOfClass:[NSDictionary class]]) {
            orderIds = [self allOrderIdsFrom:((NSDictionary *)response.data)[@"objection"]];
        }
        if (orderIds.count == 0) {
            NSLog(@"[HQITAccurateRecommend] userSubmitDcUpgrade 200 with empty order list → no error toast");
            self.isSubmitting = NO;
            [self notify];
            return;
        }
        if (self.onSubmitSuccess) self.onSubmitSuccess(orderIds);
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

- (NSString *)stringFrom:(NSDictionary *)dict key:(NSString *)key {
    if (![dict isKindOfClass:[NSDictionary class]]) return @"";
    id v = dict[key];
    if (v == nil || v == [NSNull null]) return @"";
    NSString *s = [NSString stringWithFormat:@"%@", v];
    if ([s isEqualToString:@"(null)"]) return @"";
    return s;
}

@end
