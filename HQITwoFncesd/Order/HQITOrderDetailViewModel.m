
#import "HQITOrderDetailViewModel.h"
#import "HQITOrderHistoryModels.h"
#import "HQITBankAccountViewModel.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITAmountFormatter.h"
#import "HQITCategoryText.h"

@interface HQITOrderDetailViewModel ()
@property (nonatomic, copy, readwrite) NSString *inputOrderId;
@property (nonatomic, copy, readwrite, nullable) NSString *inputProductId;
@property (nonatomic, copy, readwrite) NSString *productName;
@property (nonatomic, copy, readwrite, nullable) NSString *productLogo;
@property (nonatomic, copy, readwrite, nullable) NSString *productId;
@property (nonatomic, assign, readwrite) NSInteger orderStatus;
@property (nonatomic, copy, readwrite) NSString *statusTitle;
@property (nonatomic, strong, readwrite) UIColor *statusTextColor;
@property (nonatomic, strong, readwrite) UIColor *statusBgColor;
@property (nonatomic, copy, readwrite) NSString *loanAmountDisplay;
@property (nonatomic, copy, readwrite, nullable) NSString *emisDisplay;
@property (nonatomic, copy, readwrite, nullable) NSString *maskedBankAccount;
@property (nonatomic, strong, readwrite, nullable) HQITBankAccountItem *bankAccountItem;
@property (nonatomic, copy, readwrite) NSArray<HQITOrderDetailRow *> *detailRows;
@property (nonatomic, copy, readwrite) NSString *tipPrimary;
@property (nonatomic, copy, readwrite, nullable) NSString *tipSecondary;
@property (nonatomic, assign, readwrite) HQITOrderDetailAction primaryAction;
@property (nonatomic, copy, readwrite, nullable) NSString *primaryButtonTitle;
@property (nonatomic, assign, readwrite) HQITOrderDetailAction secondaryAction;
@property (nonatomic, copy, readwrite, nullable) NSString *secondaryButtonTitle;
@property (nonatomic, copy, readwrite, nullable) NSString *resolvedOrderId;
@property (nonatomic, copy, readwrite, nullable) NSString *loanAmountRaw;
@property (nonatomic, copy, readwrite, nullable) NSString *loanTermRaw;
@property (nonatomic, assign, readwrite) BOOL isLoading;
@property (nonatomic, copy) NSString *ifExtension;
@end

@implementation HQITOrderDetailViewModel

- (instancetype)initWithOrderId:(NSString *)orderId productId:(NSString *)productId {
    self = [super init];
    if (self) {
        _inputOrderId = [orderId copy] ?: @"";
        _inputProductId = [productId copy];
        _productName = @"—";
        _loanAmountDisplay = @"—";
        _detailRows = @[];
        _tipPrimary = @"";
        _statusTitle = @"";
        _statusTextColor = [UIColor grayColor];
        _statusBgColor = [UIColor colorWithWhite:0.9 alpha:1];
        _ifExtension = @"";
    }
    return self;
}

- (void)loadDetail {
    if (self.isLoading) return;
    self.isLoading = YES;
    NSMutableDictionary *unsignedData = [@{@"appType": @"DC"} mutableCopy];
    if (self.inputProductId.length) unsignedData[@"productId"] = self.inputProductId;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/detailV2"
                                         signedData:@{@"orderId": self.inputOrderId.length ? self.inputOrderId : @"1"}
                                       unsignedData:unsignedData
                                        showLoading:@YES
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isLoading = NO;
        [self applyResponseData:response.data];
        if (self.onUpdated) self.onUpdated();
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isLoading = NO;
        if (self.onErrorMessage) self.onErrorMessage(message.length ? message : @"Request failed");
        if (self.onUpdated) self.onUpdated();
    }];
}

#pragma mark - Parse

- (void)applyResponseData:(id)raw {
    NSDictionary *data = [raw isKindOfClass:[NSDictionary class]] ? (NSDictionary *)raw : @{};
    NSDictionary *product = [self asDict:data[@"product"]]
        ?: [self asDict:data[@"product"]]
        ?: [self asDict:data[@"product"]]
        ?: [self asDict:data[@"productInfo"]];
    NSDictionary *bank = [self asDict:data[@"bankCard"]] ?: [self asDict:data[@"bank_card"]] ?: [self asDict:data[@"bankCard"]];
    if (!bank) {
        id list = data[@"bankCardList"] ?: data[@"bank_card_list"] ?: data[@"bankCardList"];
        if ([list isKindOfClass:[NSArray class]] && [(NSArray *)list count] > 0) {
            bank = [self asDict:[(NSArray *)list firstObject]];
        }
    }
    // orderDetail→hillside
    NSDictionary *od = [self asDict:data[@"orderDetail"]];
    if (!od) od = data;

    self.productName = [self valueIn:product key:@"productName"]
        ?: [self valueIn:data key:@"productName"]
        ?: @"—";
    self.productLogo = [self valueIn:product key:@"productLogo"];
    self.productId = [self valueIn:product key:@"productId"] ?: self.inputProductId;

    NSInteger status = [[self valueIn:od key:@"orderStatus"] integerValue];
    self.orderStatus = status;
    NSString *title = nil; UIColor *tc = nil, *bg = nil;
    [HQITOrderStatusStyle applyStyleForStatusCode:status title:&title textColor:&tc bgColor:&bg];
    self.statusTitle = title ?: @"";
    self.statusTextColor = tc;
    self.statusBgColor = bg;

    NSString *loanRaw = [self valueIn:od key:@"loanAmount"];
    self.loanAmountRaw = loanRaw.length ? loanRaw : nil;
    self.loanAmountDisplay = loanRaw.length
        ? [HQITAmountFormatter formatPlainAmount:loanRaw prefixCurrency:YES]
        : @"—";
    NSString *termRaw = [self valueIn:od key:@"loanTerm"];
    self.loanTermRaw = termRaw.length ? termRaw : nil;

    NSInteger emis = [[self valueIn:od key:@"EMIs"] integerValue];
    self.emisDisplay = emis > 0 ? [NSString stringWithFormat:@"%ld EMIS", (long)emis] : nil;

    NSString *acc = [self valueIn:bank key:@"accountNo"];
    NSString *masked = [self maskAccount:acc];
    self.maskedBankAccount = masked;
    self.bankAccountItem = nil;
    if (acc.length) {
        HQITBankAccountItem *item = [[HQITBankAccountItem alloc] init];
        item.recordId = [self valueIn:bank key:@"recordId"] ?: @"";
        item.bankCode = [self valueIn:bank key:@"bankCode"] ?: @"";
        item.accountNo = acc;
        item.accountNoDisplay = masked ?: acc;
        item.accountName = [self valueIn:bank key:@"accountName"] ?: @"";
        item.bankName = [self valueIn:bank key:@"bankName"];
        item.creditCard = [self valueIn:bank key:@"creditCard"];
        item.isDefault = YES;
        self.bankAccountItem = item;
    }

    NSString *detailOid = [self valueIn:od key:@"orderId"];
    if (detailOid.length && ![detailOid isEqualToString:@"1"]) {
        self.resolvedOrderId = detailOid;
    } else if (self.inputOrderId.length && ![self.inputOrderId isEqualToString:@"1"]) {
        self.resolvedOrderId = self.inputOrderId;
    } else {
        self.resolvedOrderId = nil;
    }

    // ifExtension→bench
    self.ifExtension = [self valueIn:od key:@"ifExtension"] ?: @"";
    self.detailRows = [self buildDetailRowsForStatus:status orderDetail:od emisCount:emis];
    [self rebuildTipsForStatus:status];
    [self rebuildActionsForStatus:status ifExtension:self.ifExtension];
}

- (NSArray<HQITOrderDetailRow *> *)buildDetailRowsForStatus:(NSInteger)status
                                               orderDetail:(NSDictionary *)od
                                                 emisCount:(NSInteger)emisCount {
    NSMutableArray<HQITOrderDetailRow *> *rows = [NSMutableArray array];

    if (emisCount > 0) {
        [self addDateRow:rows title:@"1st EMI Date" raw:[self valueIn:od key:@"EMIRepayDate"]];
        [self addMoneyRow:rows title:@"EMI Amount" raw:[self valueIn:od key:@"EMIAmount"] prefix:YES infoKey:nil];
    }

    NSArray *keys = [self whitelistKeysForStatus:status];
    BOOL hasReduction = [self hasNonZeroAmount:[self valueIn:od key:@"reductionAmount"]];
    BOOL hasRepaid = [self hasNonZeroAmount:[self valueIn:od key:@"alreadyRepaymentAmount"]];

    for (NSString *key in keys) {
        if ([key isEqualToString:@"receiptAmount"]) {
            [self addMoneyRow:rows title:@"Amount received"
                          raw:[self valueIn:od key:@"receiptAmount"]
                       prefix:NO infoKey:@"received"];
        } else if ([key isEqualToString:@"interestAmount"]) {
            [self addMoneyRow:rows title:@"Interest"
                          raw:[self valueIn:od key:@"interestAmount"]
                       prefix:NO infoKey:@"interest"];
        } else if ([key isEqualToString:@"feeAmount"]) {
            [self addMoneyRow:rows title:@"Service fee"
                          raw:[self valueIn:od key:@"feeAmount"]
                       prefix:NO infoKey:@"fee"];
        } else if ([key isEqualToString:@"taxAmount"]) {
            [self addMoneyRow:rows title:@"GST"
                          raw:[self valueIn:od key:@"taxAmount"]
                       prefix:NO infoKey:nil];
        } else if ([key isEqualToString:@"applyDate"]) {
            [self addDateRow:rows title:@"Date of application"
                         raw:[self valueIn:od key:@"applyDate"]];
        } else if ([key isEqualToString:@"payoutDate"]) {
            [self addDateRow:rows title:@"Payment date"
                         raw:[self valueIn:od key:@"payoutDate"]];
        } else if ([key isEqualToString:@"dueDate"]) {
            [self addDateRow:rows title:@"Due date"
                         raw:[self valueIn:od key:@"dueDate"]];
        } else if ([key isEqualToString:@"penaltyAmount"]) {
            NSString *raw = [self valueIn:od key:@"penaltyAmount"];
            if ([self hasNonZeroAmount:raw]) {
                [self addMoneyRow:rows title:@"Late charge" raw:raw prefix:NO infoKey:nil];
            }
        } else if ([key isEqualToString:@"totalRepaymentAmount"]) {
            NSString *raw = [self valueIn:od key:@"totalRepaymentAmount"];
            if ([self hasNonZeroAmount:raw]) {
                [self addMoneyRow:rows title:@"Total repayment" raw:raw prefix:NO infoKey:nil];
            }
        } else if ([key isEqualToString:@"reductionAmount"]) {
            NSString *raw = [self valueIn:od key:@"reductionAmount"];
            if ([self hasNonZeroAmount:raw]) {
                [self addMoneyRow:rows title:@"Amount of deduction" raw:raw prefix:NO infoKey:nil];
            }
        } else if ([key isEqualToString:@"alreadyRepaymentAmount"]) {
            NSString *raw = [self valueIn:od key:@"alreadyRepaymentAmount"];
            if ([self hasNonZeroAmount:raw]) {
                [self addMoneyRow:rows title:@"Amount repaid" raw:raw prefix:NO infoKey:nil];
            }
        } else if ([key isEqualToString:@"shouldRepaymentAmount"]) {
            // Amount due: hide when both deduction & repaid are empty
            if (!hasReduction && !hasRepaid) continue;
            NSString *raw = [self valueIn:od key:@"shouldRepaymentAmount"];
            if ([self hasNonZeroAmount:raw]) {
                [self addMoneyRow:rows title:@"Amount due" raw:raw prefix:NO infoKey:nil];
            }
        } else if ([key isEqualToString:@"repaymentDate"]) {
            NSString *raw = [self valueIn:od key:@"repaymentDate"];
            if (raw.length) {
                [self addDateRow:rows title:@"Repayment date" raw:raw];
            }
        }
    }

    return rows;
}

- (NSArray<NSString *> *)whitelistKeysForStatus:(NSInteger)status {
    switch (status) {
        case 60:
            return @[@"receiptAmount", @"interestAmount", @"feeAmount", @"taxAmount",
                     @"payoutDate", @"dueDate",
                     @"totalRepaymentAmount", @"reductionAmount", @"alreadyRepaymentAmount", @"shouldRepaymentAmount"];
        case 61:
            return @[@"receiptAmount", @"interestAmount", @"feeAmount", @"taxAmount",
                     @"payoutDate", @"dueDate", @"penaltyAmount",
                     @"totalRepaymentAmount", @"reductionAmount", @"alreadyRepaymentAmount", @"shouldRepaymentAmount"];
        case 70:
            return @[@"receiptAmount", @"interestAmount", @"feeAmount", @"taxAmount",
                     @"payoutDate", @"dueDate",
                     @"totalRepaymentAmount", @"reductionAmount", @"alreadyRepaymentAmount", @"repaymentDate"];
        case 10: case 30: case 31: case 32: case 36: case 50: case 99:
        default:
            return @[@"receiptAmount", @"interestAmount", @"feeAmount", @"taxAmount",
                     @"applyDate", @"dueDate"];
    }
}

- (void)rebuildTipsForStatus:(NSInteger)status {
    NSString *tipId = nil;
    NSString *fallback = @"";
    switch (status) {
        case 10: tipId = @"d18"; fallback = @"Please submit complete information. In this case we will deal with your application in a shorter time."; break;
        case 30: tipId = @"d9"; fallback = @"Your application is under review, and the credit evaluation results determine your loan amount"; break;
        case 31: tipId = @"d57"; fallback = @"Your loan application can not be approved."; break;
        case 32: tipId = @"d26"; fallback = @"You have an order pending withdrawal. After entering the page to confirm, the funds will be transferred to your bank account immediately."; break;
        case 36: tipId = @"d13"; fallback = @"Your bank card information is unable to receive the loan. Please update it promptly to ensure timely disbursement."; break;
        case 50: tipId = @"d11"; fallback = @"Your loan application has been approved. The loan will be disbursed to your account shortly. Please keep an eye on your account."; break;
        case 60: tipId = @"d21"; fallback = @"Please repay the loan on time before the due date. Timely repayments will significantly increase your subsequent loan eligibility."; break;
        case 61: tipId = @"d22"; fallback = @"You are overdue. Please repay as soon as possible. Otherwise it will affect your credit."; break;
        case 70: tipId = @"d29"; fallback = @"This order has been successfully settled. You can now apply for a new loan with a higher amount."; break;
        case 99: tipId = @"d31"; fallback = @"The order has been canceled. If you need to reorder or have any questions, please contact us."; break;
        default: break;
    }
    self.tipPrimary = tipId.length ? [HQITCategoryText textForKey:tipId defaultText:fallback] : fallback;
    self.tipSecondary = (status == 60 || status == 61)
        ? @"UPI is valid for 15 minutes. To avoid your loss, please use the new link generated by the repayment button to repay."
        : nil;
}

- (void)rebuildActionsForStatus:(NSInteger)status ifExtension:(NSString *)ifExtension {
    self.primaryAction = HQITOrderDetailActionNone;
    self.primaryButtonTitle = nil;
    self.secondaryAction = HQITOrderDetailActionNone;
    self.secondaryButtonTitle = nil;
    if (status == 10) {
        self.primaryAction = HQITOrderDetailActionContinueSubmitting;
        self.primaryButtonTitle = @"Continue submitting";
    } else if (status == 36) {
        self.primaryAction = HQITOrderDetailActionChangeBank;
        self.primaryButtonTitle = @"Change Bank Account";
    } else if (status == 60) {
        if ([ifExtension isEqualToString:@"1"]) {
            self.secondaryAction = HQITOrderDetailActionDefer;
            self.secondaryButtonTitle = @"Defer";
        }
        self.primaryAction = HQITOrderDetailActionRepay;
        self.primaryButtonTitle = @"Repay";
    } else if (status == 61) {
        self.primaryAction = HQITOrderDetailActionRepay;
        self.primaryButtonTitle = @"Repay";
    }
}

- (void)requestPaymentLinkForAction:(HQITOrderDetailAction)action
                          onSuccess:(void (^)(NSString *urlString))onSuccess
                          onFailure:(void (^)(NSString *message))onFailure {
    if (self.isActionBusy) return;
    NSString *oid = self.resolvedOrderId;
    if (oid.length == 0) {
        if (onFailure) onFailure:@"Order ID is required";
        return;
    }
    NSString *endpoint = (action == HQITOrderDetailActionDefer)
        ? @"/app/v3/order/repay/extension"
        : @"/app/v3/order/repay/connect";
    self.isActionBusy = YES;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:endpoint
                                         signedData:@{@"orderId": oid}
                                       unsignedData:@{@"periodNoList": @[@"1"]}
                                        showLoading:@YES
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isActionBusy = NO;
        NSDictionary *data = [response.data isKindOfClass:[NSDictionary class]] ? response.data : @{};
        NSString *url = nil;
        id connect = data[@"connect"] ?: data[@"href"] ?: data[@"url"];
        if ([connect isKindOfClass:[NSString class]]) url = (NSString *)connect;
        url = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (url.length == 0) {
            if (onFailure) onFailure(@"No payment link available");
            return;
        }
        NSURL *parsed = [NSURL URLWithString:url];
        NSString *scheme = parsed.scheme.lowercaseString;
        if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
            if (onFailure) onFailure(@"Invalid link");
            return;
        }
        if (onSuccess) onSuccess(url);
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isActionBusy = NO;
        if (onFailure) onFailure(message.length ? message : @"Request failed");
    }];
}

- (void)requestWithdrawalOnSuccess:(void (^)(void))onSuccess
                         onFailure:(void (^)(NSString *message))onFailure {
    if (self.isActionBusy) return;
    NSString *oid = self.resolvedOrderId;
    if (oid.length == 0) {
        if (onFailure) onFailure(@"Order ID is required");
        return;
    }
    self.isActionBusy = YES;
    NSMutableDictionary *unsignedData = [NSMutableDictionary dictionary];
    if (self.loanAmountRaw.length) unsignedData[@"loanAmount"] = self.loanAmountRaw;
    if (self.loanTermRaw.length) unsignedData[@"loanTerm"] = self.loanTermRaw;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/apply/withdrawal"
                                         signedData:@{@"orderId": oid}
                                       unsignedData:unsignedData.count ? unsignedData : nil
                                        showLoading:@YES
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isActionBusy = NO;
        if (onSuccess) onSuccess();
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isActionBusy = NO;
        if (onFailure) onFailure(message.length ? message : @"Request failed");
    }];
}

#pragma mark - Row helpers

- (void)addMoneyRow:(NSMutableArray *)rows title:(NSString *)title raw:(NSString *)raw prefix:(BOOL)prefix infoKey:(NSString *)infoKey {
    HQITOrderDetailRow *r = [[HQITOrderDetailRow alloc] init];
    r.title = title;
    r.value = raw.length ? [HQITAmountFormatter formatPlainAmount:raw prefixCurrency:prefix] : @"—";
    r.infoKey = infoKey;
    [rows addObject:r];
}

- (void)addDateRow:(NSMutableArray *)rows title:(NSString *)title raw:(NSString *)raw {
    HQITOrderDetailRow *r = [[HQITOrderDetailRow alloc] init];
    r.title = title;
    r.value = [self formatDate:raw];
    [rows addObject:r];
}

#pragma mark - Utils

- (BOOL)hasNonZeroAmount:(NSString *)raw {
    if (raw.length == 0) return NO;
    NSString *t = [[raw stringByReplacingOccurrencesOfString:@"," withString:@""]
                   stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([t isEqualToString:@"0"] || [t isEqualToString:@"0.0"] || [t isEqualToString:@"0.00"]) return NO;
    return fabs(t.doubleValue) > 0.000001;
}

- (NSString *)maskAccount:(NSString *)account {
    if (account.length == 0) return nil;
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < account.length; i++) {
        unichar c = [account characterAtIndex:i];
        if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
    }
    if (digits.length < 4) return account;
    NSString *tail = [digits substringFromIndex:digits.length - 4];
    if (digits.length >= 8) {
        NSString *head = [digits substringToIndex:4];
        return [NSString stringWithFormat:@"%@ **** **** %@", head, tail];
    }
    return [NSString stringWithFormat:@"**** **** **** %@", tail];
}

- (NSString *)formatDate:(NSString *)raw {
    if (raw.length == 0) return @"—";
    NSCharacterSet *nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([raw rangeOfCharacterFromSet:nonDigit].location == NSNotFound && raw.length >= 10) {
        long long v = raw.longLongValue;
        if (v > 1000000000000LL) v /= 1000;
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)v];
        return [[self dateFormatter] stringFromDate:date] ?: raw;
    }
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

- (NSDictionary *)asDict:(id)v {
    return [v isKindOfClass:[NSDictionary class]] ? v : nil;
}

- (NSString *)valueIn:(NSDictionary *)dict key:(NSString *)key {
    return [self valueIn:dict keys:(key.length ? @[key] : @[])];
}

- (NSString *)valueIn:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    for (NSString *k in keys) {
        id v = dict[k];
        if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) return v;
        if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
    }
    return nil;
}

@end
