
#import "HQITWithdrawOrderDetailViewModel.h"
#import "HQITOrderHistoryModels.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITAmountFormatter.h"
#import "HQITCategoryText.h"

@interface HQITWithdrawOrderDetailViewModel ()
@property (nonatomic, copy, readwrite) NSString *inputOrderId;
@property (nonatomic, copy, readwrite, nullable) NSString *inputProductId;
@property (nonatomic, copy, readwrite, nullable) NSString *resolvedOrderId;
@property (nonatomic, copy, readwrite, nullable) NSString *productId;
@property (nonatomic, copy, readwrite) NSString *productName;
@property (nonatomic, copy, readwrite, nullable) NSString *productLogo;
@property (nonatomic, copy, readwrite) NSString *statusTitle;
@property (nonatomic, strong, readwrite) UIColor *statusTextColor;
@property (nonatomic, strong, readwrite) UIColor *statusBgColor;
@property (nonatomic, copy, readwrite) NSString *tipText;
@property (nonatomic, copy, readwrite, nullable) NSString *maskedBankAccount;
@property (nonatomic, copy, readwrite) NSArray<NSDictionary *> *amountList;
@property (nonatomic, assign, readwrite) NSInteger selectedAmountIndex;
@property (nonatomic, assign, readwrite) NSInteger selectedTermIndex;
@property (nonatomic, assign, readwrite) BOOL isLoading;
@property (nonatomic, assign, readwrite) BOOL isSubmitting;
@property (nonatomic, strong) NSDictionary *rootData;
@property (nonatomic, strong) NSDictionary *orderDetail;
@end

@implementation HQITWithdrawOrderDetailViewModel

- (instancetype)initWithOrderId:(NSString *)orderId productId:(NSString *)productId {
    self = [super init];
    if (self) {
        _inputOrderId = [orderId copy] ?: @"";
        _inputProductId = [productId copy];
        _productName = @"—";
        _amountList = @[];
        _tipText = @"";
        _statusTitle = @"";
        _statusTextColor = [UIColor grayColor];
        _statusBgColor = [UIColor colorWithWhite:0.9 alpha:1];
        _rootData = @{};
        _orderDetail = @{};
    }
    return self;
}

- (void)notify {
    if (self.onUpdated) self.onUpdated();
}

- (void)loadDetail {
    if (self.isLoading) return;
    self.isLoading = YES;
    NSMutableDictionary *unsignedData = [NSMutableDictionary dictionary];
    if (self.inputProductId.length) unsignedData[@"productId"] = self.inputProductId;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/withdrawn/detail"
                                         signedData:@{@"orderId": self.inputOrderId.length ? self.inputOrderId : @"1"}
                                       unsignedData:unsignedData.count ? unsignedData : nil
                                        showLoading:@YES
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isLoading = NO;
        [self applyResponseData:response.data];
        [self notify];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isLoading = NO;
        if (self.onErrorMessage) self.onErrorMessage(message.length ? message : @"Request failed");
        [self notify];
    }];
}

#pragma mark - Parse

- (void)applyResponseData:(id)raw {
    NSDictionary *data = [raw isKindOfClass:[NSDictionary class]] ? (NSDictionary *)raw : @{};
    self.rootData = data;
    NSDictionary *product = [self asDict:data[@"product"]]
        ?: [self asDict:data[@"product"]]
        ?: [self asDict:data[@"product"]]
        ?: [self asDict:data[@"productInfo"]];
    if (!product) {
        id plist = data[@"productList"] ?: data[@"product_list"] ?: data[@"productInfoList"] ?: data[@"productInfoList"];
        if ([plist isKindOfClass:[NSArray class]] && [(NSArray *)plist count] > 0) {
            product = [self asDict:[(NSArray *)plist firstObject]];
        }
    }
    NSDictionary *od = [self asDict:data[@"orderDetail"]]
        ?: [self asDict:data[@"orderDetail"]]
        ?: [self asDict:data[@"order_detail"]];
    if (!od) od = data;
    self.orderDetail = od;

    self.productName = [self stringFrom:product key:@"productName"]
        ?: [self stringFrom:data key:@"productName"]
        ?: [self stringFrom:od key:@"productName"]
        ?: [self stringFrom:[self firstAmountDictIn:data orderDetail:od]
                       key:@"productName"]
        ?: (self.inputProductId.length ? self.inputProductId : nil)
        ?: @"—";
    self.productLogo = [self stringFrom:product key:@"productLogo"]
        ?: [self stringFrom:data key:@"productLogo"]
        ?: [self stringFrom:od key:@"productLogo"]
        ?: [self stringFrom:[self firstAmountDictIn:data orderDetail:od]
                       key:@"productLogo"];
    self.productId = [self stringFrom:product key:@"productId"]
        ?: [self stringFrom:data key:@"productId"]
        ?: [self stringFrom:[self firstAmountDictIn:data orderDetail:od] key:@"productId"]
        ?: self.inputProductId;

    NSString *detailOid = [self stringFrom:od key:@"orderId"];
    if (detailOid.length && ![detailOid isEqualToString:@"1"]) {
        self.resolvedOrderId = detailOid;
    } else if (self.inputOrderId.length && ![self.inputOrderId isEqualToString:@"1"]) {
        self.resolvedOrderId = self.inputOrderId;
    } else {
        self.resolvedOrderId = nil;
    }

    NSInteger status = [[self stringFrom:od key:@"orderStatus"] integerValue];
    if (status == 0) status = 32;
    NSString *title = nil; UIColor *tc = nil, *bg = nil;
    [HQITOrderStatusStyle applyStyleForStatusCode:status title:&title textColor:&tc bgColor:&bg];
    self.statusTitle = title.length ? title : @"Pending withdrawal";
    self.statusTextColor = tc;
    self.statusBgColor = bg;

    NSString *tipFallback = @"You have a pending loan order, and we need your confirmation. Once confirmed, we will transfer the funds to your bank account immediately.";
    self.tipText = [HQITCategoryText textForKey:@"d26" defaultText:tipFallback];

    [self parseBankFrom:data orderDetail:od];
    self.amountList = [self parseAmountListFrom:data orderDetail:od];
    self.selectedAmountIndex = 0;
    self.selectedTermIndex = 0;

    if (self.productLogo.length == 0 && self.amountList.count > 0) {
        NSDictionary *amt0 = self.amountList.firstObject;
        self.productLogo = [self stringFrom:amt0 key:@"productLogo"];
        if (self.productName.length == 0 || [self.productName isEqualToString:@"—"] || [self.productName isEqualToString:self.inputProductId]) {
            NSString *n = [self stringFrom:amt0 key:@"productName"];
            if (n.length) self.productName = n;
        }
    }
}

- (NSDictionary *)firstAmountDictIn:(NSDictionary *)data orderDetail:(NSDictionary *)od {
    id raw = data[@"amountDetailList"] ?: data[@"amountDetailList"] ?: data[@"amount_detail_list"]
        ?: od[@"amountDetailList"] ?: od[@"amountDetailList"] ?: od[@"amount_detail_list"];
    if (![raw isKindOfClass:[NSArray class]] || [(NSArray *)raw count] == 0) return nil;
    id first = [(NSArray *)raw firstObject];
    return [first isKindOfClass:[NSDictionary class]] ? first : nil;
}

- (NSArray<NSDictionary *> *)parseAmountListFrom:(NSDictionary *)data orderDetail:(NSDictionary *)od {
    id raw = data[@"amountDetailList"] ?: data[@"amountDetailList"] ?: data[@"amount_detail_list"]
        ?: od[@"amountDetailList"] ?: od[@"amountDetailList"] ?: od[@"amount_detail_list"];
    if ([raw isKindOfClass:[NSArray class]] && [(NSArray *)raw count] > 0) {
        NSMutableDictionary *byAmount = [NSMutableDictionary dictionary];
        for (id row in (NSArray *)raw) {
            if (![row isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *d = (NSDictionary *)row;
            NSString *amt = [self loanAmountRawFrom:d];
            if (amt.length == 0) continue;
            NSMutableDictionary *merged = [d mutableCopy];
            if (![merged[@"termDetailList"] isKindOfClass:[NSArray class]]
                && ![merged[@"term_detail_list"] isKindOfClass:[NSArray class]]) {
                id terms = data[@"termDetailList"] ?: data[@"term_detail_list"]
                    ?: data[@"productTermItemList"] ?: data[@"product_term_item_list"] ?: data[@"productTermItemList"]
                    ?: od[@"termDetailList"] ?: od[@"term_detail_list"]
                    ?: od[@"productTermItemList"] ?: od[@"product_term_item_list"] ?: od[@"productTermItemList"];
                if ([terms isKindOfClass:[NSArray class]] && [(NSArray *)terms count] > 0) {
                    merged[@"termDetailList"] = terms;
                } else {
                    NSDictionary *single = [self syntheticTermFrom:od fallbackAmount:d];
                    if (single) merged[@"termDetailList"] = @[single];
                }
            }
            if (!byAmount[amt]) byAmount[amt] = [merged copy];
        }
        NSArray *keys = [byAmount.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            double da = a.doubleValue, db = b.doubleValue;
            if (da > db) return NSOrderedAscending;
            if (da < db) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        NSMutableArray *out = [NSMutableArray array];
        for (NSString *k in keys) [out addObject:byAmount[k]];
        if (out.count) return out;
    }

    NSString *loan = [self loanAmountRawFrom:od] ?: [self loanAmountRawFrom:data];
    if (loan.length == 0) return @[];
    NSMutableDictionary *single = [@{@"loanAmount": loan} mutableCopy];
    id terms = data[@"termDetailList"] ?: data[@"term_detail_list"]
        ?: data[@"productTermItemList"] ?: data[@"product_term_item_list"]
        ?: od[@"termDetailList"] ?: od[@"term_detail_list"];
    if ([terms isKindOfClass:[NSArray class]] && [(NSArray *)terms count] > 0) {
        single[@"termDetailList"] = terms;
    } else {
        NSDictionary *t = [self syntheticTermFrom:od fallbackAmount:nil];
        if (t) single[@"termDetailList"] = @[t];
    }
    for (NSString *k in @[@"receiptAmount", @"feeAmount", @"interestAmount", @"taxAmount",
                          @"applyDate", @"dueDate", @"EMIAmount", @"EMIRepayDate", @"EMIs",
                          @"showTerm", @"loanTerm"]) {
        id v = od[k];
        if (v) single[k] = v;
    }
    return @[single];
}

- (NSDictionary *)syntheticTermFrom:(NSDictionary *)od fallbackAmount:(NSDictionary *)amt {
    NSMutableDictionary *t = [NSMutableDictionary dictionary];
    NSString *show = [self stringFrom:od key:@"showTerm"]
        ?: [self stringFrom:amt key:@"showTerm"];
    NSString *loanTerm = [self stringFrom:od key:@"loanTerm"]
        ?: [self stringFrom:amt key:@"loanTerm"];
    if (show.length) t[@"showTerm"] = show;
    if (loanTerm.length) t[@"loanTerm"] = loanTerm;
    NSString *emis = [self stringFrom:od key:@"EMIs"];
    if (emis.length) t[@"EMIs"] = emis;
    NSString *emiAmt = [self stringFrom:od key:@"EMIAmount"];
    if (emiAmt.length) t[@"EMIAmount"] = emiAmt;
    NSString *emiDate = [self stringFrom:od key:@"EMIRepayDate"];
    if (emiDate.length) t[@"EMIRepayDate"] = emiDate;
    for (NSString *k in @[@"receiptAmount", @"feeAmount", @"interestAmount", @"taxAmount", @"dueDate", @"applyDate"]) {
        id v = od[k];
        if (v) t[k] = v;
    }
    return t.count ? t : nil;
}

- (void)parseBankFrom:(NSDictionary *)data orderDetail:(NSDictionary *)od {
    NSDictionary *card = [self firstBankCardIn:data] ?: [self firstBankCardIn:od];
    if (!card) {
        self.maskedBankAccount = nil;
        return;
    }
    NSString *acc = [self stringFrom:card key:@"accountNo"];
    self.maskedBankAccount = [self maskAccount:acc];
}

- (NSDictionary *)firstBankCardIn:(NSDictionary *)dict {
    id single = dict[@"bankCard"] ?: dict[@"bank_card"];
    if ([single isKindOfClass:[NSDictionary class]]) return single;
    for (NSString *k in @[@"bankCardList", @"bank_card_list"]) {
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
    if (digits.length < 8) return account.length ? account : nil;
    NSString *head = [digits substringToIndex:4];
    NSString *tail = [digits substringFromIndex:digits.length - 4];
    return [NSString stringWithFormat:@"%@ **** **** %@", head, tail];
}

#pragma mark - Selection

- (NSDictionary *)currentAmount {
    if (self.selectedAmountIndex < 0 || self.selectedAmountIndex >= (NSInteger)self.amountList.count) return @{};
    return self.amountList[self.selectedAmountIndex];
}

- (NSArray<NSDictionary *> *)currentTerms {
    NSDictionary *amt = [self currentAmount];
    id list = amt[@"termDetailList"] ?: amt[@"term_detail_list"]
        ?: amt[@"productTermItemList"] ?: amt[@"product_term_item_list"];
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

- (BOOL)isMultiAmount { return self.amountList.count > 1; }
- (BOOL)isMultiTerm { return [self currentTerms].count > 1; }

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
    NSInteger days = [self integerFrom:term key:@"loanTerm"];
    if (days >= 30) return MAX(1, (NSInteger)llround(days / 30.0));
    return 0;
}

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

#pragma mark - Display

- (NSString *)displayAmountAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.amountList.count) return @"";
    NSString *raw = [self loanAmountRawFrom:self.amountList[index]];
    return [HQITAmountFormatter formatPlainAmount:raw prefixCurrency:YES];
}

- (NSString *)currentLoanAmountRaw {
    return [self loanAmountRawFrom:[self currentAmount]];
}

- (NSString *)currentLoanTermRaw {
    NSDictionary *term = [self currentTerm];
    NSString *loanTerm = [self stringFrom:term key:@"loanTerm"];
    if (loanTerm.length) return loanTerm;
    return [self currentShowTermRaw];
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
        } else if (show.length) {
            [labels addObject:[self formatTermDisplay:show]];
        } else {
            [labels addObject:[NSString stringWithFormat:@"Option %ld", (long)(i + 1)]];
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
                                 value:[self formatDate:[self valueFromSources:@[term, amt, self.orderDetail, self.rootData]
                                                                         key:@"EMIRepayDate"]]
                               infoKey:nil
                            emphasized:YES]];
        [rows addObject:[self rowTitle:@"EMI Amount"
                                 value:[self formatMoney:[self emiAmountValue] prefix:YES]
                               infoKey:nil
                            emphasized:YES]];
        NSInteger n = [self emiCount];
        [rows addObject:[self rowTitle:@"EMIs"
                                 value:n > 0 ? [NSString stringWithFormat:@"%ld EMIS", (long)n] : @"—"
                               infoKey:nil
                            emphasized:YES]];
    }

    NSString *received = [self valueFromSources:@[term, amt, self.orderDetail, self.rootData]
                                           key:@"receiptAmount"];
    if (received.length == 0) {
        double loan = [self currentLoanAmountRaw].doubleValue;
        double fee = [self valueFromSources:@[term, amt, self.orderDetail, self.rootData]
                                       key:@"feeAmount"].doubleValue;
        if (loan > 0) received = [NSString stringWithFormat:@"%.0f", loan - fee];
    }
    [rows addObject:[self rowTitle:@"Amount received" value:[self formatMoney:received prefix:NO] infoKey:@"received" emphasized:NO]];
    [rows addObject:[self rowTitle:@"Service fee"
                             value:[self formatMoney:[self valueFromSources:@[term, amt, self.orderDetail, self.rootData]
                                                                       key:@"feeAmount"]
                                              prefix:NO]
                           infoKey:@"fee"
                        emphasized:NO]];
    [rows addObject:[self rowTitle:@"Interest"
                             value:[self formatMoney:[self valueFromSources:@[term, amt, self.orderDetail, self.rootData]
                                                                       key:@"interestAmount"]
                                              prefix:NO]
                           infoKey:@"interest"
                        emphasized:NO]];
    [rows addObject:[self rowTitle:@"GST"
                             value:[self formatMoney:[self valueFromSources:@[term, amt, self.orderDetail, self.rootData]
                                                                       key:@"taxAmount"]
                                              prefix:NO]
                           infoKey:nil
                        emphasized:NO]];
    [rows addObject:[self rowTitle:@"Date of application"
                             value:[self formatDate:[self valueFromSources:@[term, amt, self.orderDetail, self.rootData]
                                                                     key:@"applyDate"]]
                           infoKey:nil
                        emphasized:NO]];
    if (![self isEMI]) {
        [rows addObject:[self rowTitle:@"Due date"
                                 value:[self formatDate:[self valueFromSources:@[term, amt, self.orderDetail, self.rootData]
                                                                         key:@"dueDate"]]
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
    return [self valueFromSources:@[term, [self currentAmount], self.orderDetail] key:@"EMIAmount"];
}

#pragma mark - Withdraw

- (void)submitWithdrawal {
    if (self.isSubmitting) return;
    NSString *oid = self.resolvedOrderId;
    if (oid.length == 0) {
        if (self.onErrorMessage) self.onErrorMessage(@"Order ID is required");
        return;
    }
    self.isSubmitting = YES;
    [self notify];

    NSMutableDictionary *unsignedData = [NSMutableDictionary dictionary];
    NSString *loanAmount = [self currentLoanAmountRaw];
    NSString *loanTerm = [self currentLoanTermRaw];
    if (loanAmount.length) unsignedData[@"loanAmount"] = loanAmount;
    if (loanTerm.length) unsignedData[@"loanTerm"] = loanTerm;

    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/apply/withdrawal"
                                         signedData:@{@"orderId": oid}
                                       unsignedData:unsignedData.count ? unsignedData : nil
                                        showLoading:@YES
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        [self notify];
        if (self.onWithdrawSuccess) self.onWithdrawSuccess();
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        [self notify];
        if (self.onErrorMessage) self.onErrorMessage(message.length ? message : @"Request failed");
    }];
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
    return raw;
}

- (NSString *)valueFromSources:(NSArray *)sources key:(NSString *)key {
    return [self valueFromSources:sources keys:(key.length ? @[key] : @[])];
}

- (NSString *)valueFromSources:(NSArray *)sources keys:(NSArray<NSString *> *)keys {
    for (id src in sources) {
        if (![src isKindOfClass:[NSDictionary class]]) continue;
        NSString *v = [self stringFrom:(NSDictionary *)src keys:keys];
        if (v.length) return v;
    }
    return @"";
}

- (NSDictionary *)asDict:(id)obj {
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
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
        if ([v isKindOfClass:[NSDictionary class]]) {
            NSString *nested = [self stringFrom:(NSDictionary *)v key:@"url"];
            if (nested.length) return nested;
            continue;
        }
        NSString *s = [NSString stringWithFormat:@"%@", v];
        if ([s isEqualToString:@"(null)"] || [s isEqualToString:@"<null>"]) continue;
        s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length) return s;
    }
    return @"";
}

- (NSInteger)integerFrom:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    return [self stringFrom:dict keys:keys].integerValue;
}

@end
