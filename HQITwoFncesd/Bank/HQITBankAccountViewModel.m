

#import "HQITBankAccountViewModel.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITAdjustManager.h"

@implementation HQITBankAccountItem

- (NSString *)ifscPrefix {
    NSString *code = [self.bankCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (code.length <= 4) return nil;
    return [code substringToIndex:4];
}

- (NSString *)ifscSuffix {
    NSString *code = [self.bankCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (code.length == 0) return @"—";
    if (code.length <= 4) return code;
    return [code substringFromIndex:4];
}

@end

@interface HQITBankAccountViewModel ()
@property (nonatomic, strong, readwrite, nullable) HQITBankAccountItem *displayItem;
@property (nonatomic, assign, readwrite) BOOL isLoading;
@property (nonatomic, assign, readwrite) BOOL hasLoadedOnce;
@property (nonatomic, assign, readwrite) BOOL canModify;
@property (nonatomic, assign) BOOL modifySwitchOn;
@property (nonatomic, assign) NSInteger loadGen;
@end

@implementation HQITBankAccountViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _modifySwitchOn = NO;
    }
    return self;
}

- (void)notify {
    if (self.onUpdated) self.onUpdated();
}

- (void)reload {
    NSInteger gen = ++self.loadGen;
    self.isLoading = YES;
    [self notify];

    __weak typeof(self) weakSelf = self;
    __block NSArray<HQITBankAccountItem *> *items = @[];
    __block BOOL switchOn = NO;
    __block NSString *listError = nil;
    __block NSInteger pending = 2;

    void (^finishOne)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        pending -= 1;
        if (pending > 0) return;
        if (gen != self.loadGen) return;
        self.modifySwitchOn = switchOn;
        self.displayItem = items.firstObject;
        self.canModify = switchOn && (self.displayItem != nil);
        self.isLoading = NO;
        self.hasLoadedOnce = YES;
        [self notify];
        if (listError.length && self.onToast) self.onToast(listError);
    };

    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/bankcard/list"
                                         signedData:@{}
                                       unsignedData:nil
                                        showLoading:@YES
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        items = [self parseList:response.data];
        finishOne();
    } failure:^(NSError *error, NSString *message) {
        listError = message.length ? message : @"Load failed";
        finishOne();
    }];

    NSMutableDictionary *infoUnsigned = [NSMutableDictionary dictionary];
    NSString *adid = [[HQITAdjustManager shared] currentAdid];
    if (adid.length > 0) infoUnsigned[@"adid"] = adid;

    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/user/info"
                                         signedData:@{}
                                       unsignedData:infoUnsigned.count ? infoUnsigned : nil
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        switchOn = [self parseModifySwitch:response.data];
        finishOne();
    } failure:^(NSError *error, NSString *message) {
        switchOn = NO;
        finishOne();
    }];
}

#pragma mark - Parse

- (BOOL)parseModifySwitch:(id)data {
    if (![data isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *dict = (NSDictionary *)data;
    id v = dict[@"payAccountModifySwitch"] ?: dict[@"pay_account_modify_switch"] ?: dict[@"payAccountModifySwitch"];
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue] == 1;
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [[(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        return [s isEqualToString:@"on"] || [s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"];
    }
    return NO;
}

- (NSArray *)arrayFromData:(id)data {
    if ([data isKindOfClass:[NSArray class]]) return data;
    if (![data isKindOfClass:[NSDictionary class]]) return @[];
    NSDictionary *dict = (NSDictionary *)data;
    for (NSString *key in @[@"bankCardList", @"bank_card_list", @"bankCardList", @"exact", @"payAccountInfoList", @"payAccountInfoDtoList", @"accountList", @"records", @"rows", @"pile"]) {
        id v = dict[key];
        if ([v isKindOfClass:[NSArray class]]) return v;
    }
    if (dict[@"accountNo"] || dict[@"accountNo"] || dict[@"accountNo"] || dict[@"account_no"] || dict[@"bankCode"] || dict[@"bankCode"] || dict[@"bank_code"]) {
        return @[dict];
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

- (BOOL)boolFlag:(id)v {
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue] == 1;
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)v lowercaseString];
        return [s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"];
    }
    return NO;
}

- (NSString *)formatAccountNo:(NSString *)raw {
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
    }
    if (digits.length == 0) return raw.length ? raw : @"—";
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < digits.length; i++) {
        if (i > 0 && i % 4 == 0) [out appendString:@" "];
        [out appendFormat:@"%C", [digits characterAtIndex:i]];
    }
    return out;
}

- (NSArray<HQITBankAccountItem *> *)parseList:(id)data {
    NSArray *arr = [self arrayFromData:data];
    NSMutableArray<HQITBankAccountItem *> *out = [NSMutableArray array];
    for (id obj in arr) {
        if (![obj isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *dict = (NSDictionary *)obj;
        HQITBankAccountItem *item = [[HQITBankAccountItem alloc] init];
        item.recordId = [self stringFrom:dict key:@"recordId"];
        item.bankCode = [self stringFrom:dict key:@"bankCode"];
        item.accountNo = [self stringFrom:dict key:@"accountNo"];
        item.accountNoDisplay = [self formatAccountNo:item.accountNo];
        item.accountName = [self stringFrom:dict key:@"accountName"];
        if (item.accountName.length == 0) item.accountName = @"—";
        item.creditCard = [self stringFrom:dict key:@"creditCard"];
        item.bankName = [self stringFrom:dict key:@"bankName"];
        item.isDefault = [self boolFlag:dict[@"defaultFlag"]] || [self boolFlag:dict[@"default_flag"]];
        [out addObject:item];
    }
    return out;
}

@end
