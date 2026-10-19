

#import "HQITAccurateRecommendSuccessViewModel.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITAmountFormatter.h"
#import "HQITOrderHistoryModels.h"
#import "HQITHUDHelper.h"

@implementation HQITAccurateRecommendSuccessDetailRow
@end

@implementation HQITAccurateRecommendSuccessOrderItem
@end

@interface HQITAccurateRecommendSuccessViewModel ()
@property (nonatomic, copy, readwrite) NSArray<NSString *> *orderIds;
@property (nonatomic, copy, readwrite) NSArray<HQITAccurateRecommendSuccessOrderItem *> *orders;
@property (nonatomic, assign, readwrite) BOOL isLoading;
@end

@implementation HQITAccurateRecommendSuccessViewModel

- (instancetype)initWithOrderIds:(NSArray<NSString *> *)orderIds {
    self = [super init];
    if (self) {
        NSMutableArray *clean = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        for (id obj in orderIds ?: @[]) {
            NSString *oid = [[NSString stringWithFormat:@"%@", obj]
                             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (oid.length == 0 || [oid isEqualToString:@"(null)"]) continue;
            if ([seen containsObject:oid]) continue;
            [seen addObject:oid];
            [clean addObject:oid];
        }
        _orderIds = [clean copy];
        _orders = @[];
    }
    return self;
}

- (void)notify {
    if (self.onUpdated) self.onUpdated();
}

- (void)loadAllOrderDetails {
    if (self.isLoading) return;
    if (self.orderIds.count == 0) {
        self.orders = @[];
        [self notify];
        return;
    }
    self.isLoading = YES;
    [HQITHUDHelper showLoadingWithMessage:@"Loading..."];
    [self fetchNextAtIndex:0 accumulated:[NSMutableArray array]];
}

- (void)fetchNextAtIndex:(NSInteger)index accumulated:(NSMutableArray *)acc {
    if (index >= (NSInteger)self.orderIds.count) {
        self.orders = [acc copy];
        self.isLoading = NO;
        [HQITHUDHelper hideLoading];
        [self notify];
        if (acc.count == 0 && self.onErrorMessage) {
            self.onErrorMessage(@"Failed to load order details");
        }
        return;
    }
    NSString *oid = self.orderIds[index];
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/order/detailV2"
                                         signedData:@{@"orderId": oid.length ? oid : @"1"}
                                       unsignedData:@{@"appType": @"DC"}
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        HQITAccurateRecommendSuccessOrderItem *item = [self parseItemFrom:response.data orderId:oid];
        if (item) [acc addObject:item];
        [self fetchNextAtIndex:index + 1 accumulated:acc];
    } failure:^(NSError *error, NSString *message) {
        (void)error; (void)message;
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self fetchNextAtIndex:index + 1 accumulated:acc];
    }];
}

- (HQITAccurateRecommendSuccessOrderItem *)parseItemFrom:(id)raw orderId:(NSString *)orderId {
    NSDictionary *data = [raw isKindOfClass:[NSDictionary class]] ? (NSDictionary *)raw : @{};
    NSDictionary *product = [self asDict:data[@"product"]] ?: [self asDict:data[@"productInfo"]];
    NSDictionary *od = [self asDict:data[@"orderDetail"]];
    if (!od) od = data;

    HQITAccurateRecommendSuccessOrderItem *item = [[HQITAccurateRecommendSuccessOrderItem alloc] init];
    item.orderId = orderId ?: @"";
    NSString *name = [self stringIn:product key:@"productName"] ?: [self stringIn:data key:@"productName"];
    item.productName = name.length ? name : @"—";
    item.productLogoURL = [self stringIn:product key:@"productLogo"];

    NSInteger status = [[self stringIn:od key:@"orderStatus"] integerValue];
    NSString *title = nil;
    UIColor *tc = nil, *bg = nil;
    [HQITOrderStatusStyle applyStyleForStatusCode:status title:&title textColor:&tc bgColor:&bg];
    item.statusTitle = title.length ? title : @"Under review";
    item.statusTextColor = tc ?: [UIColor colorWithRed:0x7B/255.0 green:0x1F/255.0 blue:0xA2/255.0 alpha:1];
    item.statusBgColor = bg ?: [UIColor colorWithRed:0xF3/255.0 green:0xE5/255.0 blue:0xF5/255.0 alpha:1];

    NSMutableArray *rows = [NSMutableArray array];
    NSString *loanRaw = [self stringIn:od key:@"loanAmount"];
    [self addMoneyRow:rows title:@"Loan amount" raw:loanRaw prefix:YES infoKey:nil];

    NSInteger emis = [[self stringIn:od key:@"EMIs"] integerValue];
    if (emis > 0) {
        [self addDateRow:rows title:@"1st EMI Date" raw:[self stringIn:od key:@"EMIRepayDate"]];
        [self addMoneyRow:rows title:@"EMI Amount" raw:[self stringIn:od key:@"EMIAmount"] prefix:YES infoKey:nil];
        [self addTextRow:rows title:@"EMIs" value:[NSString stringWithFormat:@"%ld EMIs", (long)emis]];
    } else {
        NSString *term = [self stringIn:od key:@"loanTerm"] ?: [self stringIn:od key:@"showTerm"];
        NSString *termDisplay = @"—";
        if (term.length) {
            NSCharacterSet *nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
            if ([term rangeOfCharacterFromSet:nonDigit].location == NSNotFound) {
                termDisplay = [NSString stringWithFormat:@"%@ Days", term];
            } else {
                termDisplay = term;
            }
        }
        [self addTextRow:rows title:@"Loan term" value:termDisplay];
    }

    [self addMoneyRow:rows title:@"Amount received"
                  raw:[self stringIn:od key:@"receiptAmount"] ?: [self stringIn:od key:@"arrivalAmount"]
               prefix:NO infoKey:@"received"];
    [self addMoneyRow:rows title:@"Service fee" raw:[self stringIn:od key:@"feeAmount"] prefix:NO infoKey:@"fee"];
    [self addMoneyRow:rows title:@"Interest" raw:[self stringIn:od key:@"interestAmount"] prefix:NO infoKey:@"interest"];
    [self addMoneyRow:rows title:@"GST" raw:[self stringIn:od key:@"taxAmount"] prefix:NO infoKey:nil];
    [self addDateRow:rows title:@"Date of application"
                 raw:[self stringIn:od key:@"applyDate"] ?: [self stringIn:od key:@"borrowingDate"]];

    item.detailRows = [rows copy];
    return item;
}

#pragma mark - Row helpers

- (void)addTextRow:(NSMutableArray *)rows title:(NSString *)title value:(NSString *)value {
    HQITAccurateRecommendSuccessDetailRow *r = [[HQITAccurateRecommendSuccessDetailRow alloc] init];
    r.title = title;
    r.value = value.length ? value : @"—";
    [rows addObject:r];
}

- (void)addMoneyRow:(NSMutableArray *)rows title:(NSString *)title raw:(NSString *)raw prefix:(BOOL)prefix infoKey:(NSString *)infoKey {
    HQITAccurateRecommendSuccessDetailRow *r = [[HQITAccurateRecommendSuccessDetailRow alloc] init];
    r.title = title;
    r.value = raw.length ? [HQITAmountFormatter formatPlainAmount:raw prefixCurrency:prefix] : @"—";
    r.infoKey = infoKey;
    [rows addObject:r];
}

- (void)addDateRow:(NSMutableArray *)rows title:(NSString *)title raw:(NSString *)raw {
    HQITAccurateRecommendSuccessDetailRow *r = [[HQITAccurateRecommendSuccessDetailRow alloc] init];
    r.title = title;
    r.value = [self formatDate:raw];
    [rows addObject:r];
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
    return [v isKindOfClass:[NSDictionary class]] ? (NSDictionary *)v : nil;
}

- (NSString *)stringIn:(NSDictionary *)dict key:(NSString *)key {
    if (![dict isKindOfClass:[NSDictionary class]] || key.length == 0) return nil;
    id v = dict[key];
    if (v == nil || v == [NSNull null]) return nil;
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return s.length && ![s isEqualToString:@"(null)"] ? s : nil;
    }
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
    return nil;
}

@end
