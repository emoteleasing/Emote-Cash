

#import "HQITBankAccountEditViewModel.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITCategoryText.h"
#import "HQITIndianPhoneValidator.h"
#import <ctype.h>

@interface HQITBankAccountEditViewModel ()
@property (nonatomic, strong, readwrite) HQITBankAccountItem *account;
@property (nonatomic, copy, readwrite) NSArray<HQITKYCFormRow *> *rows;
@property (nonatomic, assign, readwrite) BOOL isSubmitting;
@end

@implementation HQITBankAccountEditViewModel

- (instancetype)initWithAccount:(HQITBankAccountItem *)account {
    self = [super init];
    if (self) {
        _account = account;
        _rows = @[];
    }
    return self;
}

- (void)notify {
    if (self.onUpdated) self.onUpdated();
}

- (void)loadInit {
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/kyc/init"
                                         signedData:@{@"kycId": @"pay_account"}
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.rows = [self parseRows:response.data];
        [self applyBoundAccount];
        [self notify];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.onErrorMessage) self.onErrorMessage(message.length ? message : @"Load failed");
    }];
}

- (void)applyBoundAccount {
    for (HQITKYCFormRow *row in self.rows) {
        NSString *code = row.itemCode.lowercaseString;
        if ([code isEqualToString:@"ifsc"] || [code isEqualToString:@"bank_code"]) {
            row.displayValue = self.account.bankCode ?: @"";
        } else if ([code isEqualToString:@"account_no"]) {
            row.displayValue = self.account.accountNo ?: @"";
        } else if ([code isEqualToString:@"account_no_verify"]) {
            row.displayValue = self.account.accountNo ?: @"";
        } else if ([self isAccountNameRow:row]) {
            row.displayValue = self.account.accountName ?: @"";
        } else if ([code isEqualToString:@"credit_card"]) {
            row.displayValue = self.account.creditCard ?: @"";
        }
        row.valueKey = nil;
    }
}

- (NSArray<HQITKYCFormRow *> *)parseRows:(id)raw {
    NSArray *list = nil;
    if ([raw isKindOfClass:[NSDictionary class]]) {
        id v = raw[@"kycItemList"] ?: raw[@"itemList"] ?: raw[@"exact"];
        if ([v isKindOfClass:[NSArray class]]) list = v;
    } else if ([raw isKindOfClass:[NSArray class]]) {
        list = raw;
    }
    if (![list isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray<HQITKYCFormRow *> *rows = [NSMutableArray array];
    for (id obj in list) {
        if (![obj isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = (NSDictionary *)obj;
        HQITKYCFormRow *row = [[HQITKYCFormRow alloc] init];
        row.itemCode = [NSString stringWithFormat:@"%@", d[@"itemCode"] ?: d[@"item_code"] ?: @""];
        row.itemName = [NSString stringWithFormat:@"%@", d[@"itemName"] ?: d[@"item_name"] ?: @""];
        row.itemType = [d[@"itemType"] ?: d[@"item_type"] ?: @1 integerValue];
        row.isRequired = [[d[@"isRequired"] ?: d[@"is_required"] ?: @0 description] integerValue] == 1;
        row.itemSort = [d[@"itemSort"] ?: d[@"item_sort"] ?: @0 integerValue];
        row.regularExpression = d[@"regularExpression"] ?: d[@"regular_expression"];
        NSInteger maxL = [d[@"maxLength"] ?: d[@"max_length"] ?: @0 integerValue];
        row.maxLength = maxL > 0 ? maxL : [self defaultMaxLengthForCode:row.itemCode];
        if (row.itemCode.length == 0) continue;
        [rows addObject:row];
    }
    [rows sortUsingComparator:^NSComparisonResult(HQITKYCFormRow *a, HQITKYCFormRow *b) {
        return a.itemSort < b.itemSort ? NSOrderedAscending : (a.itemSort > b.itemSort ? NSOrderedDescending : NSOrderedSame);
    }];
    return rows;
}

- (NSInteger)defaultMaxLengthForCode:(NSString *)code {
    NSString *c = code.lowercaseString;
    if ([c isEqualToString:@"account_no"] || [c isEqualToString:@"account_no_verify"]) return 18;
    if ([c isEqualToString:@"credit_card"]) return 32;
    if ([c isEqualToString:@"ifsc"]) return 11;
    return 100;
}

- (NSInteger)maxLengthForRow:(HQITKYCFormRow *)row {
    if (row.maxLength > 0) return row.maxLength;
    return [self defaultMaxLengthForCode:row.itemCode];
}

- (BOOL)isAccountNameRow:(HQITKYCFormRow *)row {
    NSString *c = row.itemCode.lowercaseString;
    return [c isEqualToString:@"account_name"] || [c isEqualToString:@"offend"];
}

- (HQITKYCFormRow *)rowForCode:(NSString *)code {
    NSString *target = code.lowercaseString;
    for (HQITKYCFormRow *r in self.rows) {
        if ([r.itemCode.lowercaseString isEqualToString:target]) return r;
    }
    return nil;
}

- (NSString *)filterInput:(NSString *)text forRow:(HQITKYCFormRow *)row {
    NSString *code = row.itemCode.lowercaseString;
    NSString *out = text ?: @"";
    if ([code isEqualToString:@"account_no"] || [code isEqualToString:@"account_no_verify"] ||
        [code isEqualToString:@"credit_card"]) {
        out = [HQITIndianPhoneValidator digitsOnly:out];
    } else if ([code isEqualToString:@"ifsc"] || [code isEqualToString:@"bank_code"]) {
        NSMutableString *m = [NSMutableString string];
        for (NSUInteger i = 0; i < out.length; i++) {
            unichar c = [out characterAtIndex:i];
            if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
                [m appendFormat:@"%C", (unichar)toupper(c)];
            }
        }
        out = m;
    }
    NSInteger maxL = [self maxLengthForRow:row];
    if ((NSInteger)out.length > maxL) {
        out = [out substringToIndex:maxL];
    }
    return out;
}

- (void)applyInputForRow:(HQITKYCFormRow *)row text:(NSString *)text {
    if ([self isAccountNameRow:row]) return;
    row.displayValue = [self filterInput:text forRow:row];
    row.valueKey = nil;
}

- (void)applyIFSCCode:(NSString *)code {
    HQITKYCFormRow *row = [self rowForCode:@"ifsc"];
    if (!row) row = [self rowForCode:@"bank_code"];
    if (!row) return;
    row.displayValue = [self filterInput:code forRow:row];
    [self notify];
}

- (NSString *)a25ForItemName:(NSString *)name {
    NSString *tpl = [HQITCategoryText textForKey:@"a25"
                                   defaultText:@"KT_XXX is empty or in an incorrect format."];
    return [tpl stringByReplacingOccurrencesOfString:@"KT_XXX" withString:name.length ? name : @"Field"];
}

- (NSString *)validatePaymentAccountRows {
    HQITKYCFormRow *accountNo = nil;
    HQITKYCFormRow *accountVerify = nil;
    for (HQITKYCFormRow *row in self.rows) {
        NSString *code = row.itemCode.lowercaseString;
        if ([code isEqualToString:@"account_no"]) accountNo = row;
        if ([code isEqualToString:@"account_no_verify"]) accountVerify = row;

        NSString *cv = [row commitValue];
        if ([code isEqualToString:@"credit_card"]) {
            if (cv.length > 0 && row.regularExpression.length > 0) {
                NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", row.regularExpression];
                if (![p evaluateWithObject:cv]) {
                    return [self a25ForItemName:row.itemName];
                }
            }
            continue;
        }
        if (row.isRequired && cv.length == 0) {
            return [self a25ForItemName:row.itemName];
        }
        if (row.itemType == HQITKYCItemTypeInput && cv.length > 0 && row.regularExpression.length > 0) {
            NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", row.regularExpression];
            if (![p evaluateWithObject:cv]) {
                return [self a25ForItemName:row.itemName];
            }
        }
    }

    if (accountNo && accountVerify) {
        NSString *a = [accountNo commitValue];
        NSString *b = [accountVerify commitValue];
        if ((a.length > 0 || b.length > 0) && ![a isEqualToString:b]) {
            return [HQITCategoryText textForKey:@"k60"
                                  defaultText:@"Bank account numbers do not match. Please check."];
        }
    }
    return nil;
}

- (NSString *)valueForCodes:(NSArray<NSString *> *)codes {
    for (NSString *code in codes) {
        HQITKYCFormRow *row = [self rowForCode:code];
        if (!row) continue;
        NSString *v = [row submitValue] ?: @"";
        if (v.length) return v;
    }
    for (HQITKYCFormRow *row in self.rows) {
        for (NSString *code in codes) {
            if ([row.itemCode.lowercaseString isEqualToString:code.lowercaseString]) {
                return [row submitValue] ?: @"";
            }
        }
    }
    return @"";
}

- (void)commit {
    if (self.isSubmitting) return;
    NSString *err = [self validatePaymentAccountRows];
    if (err.length) {
        if (self.onErrorMessage) self.onErrorMessage(err);
        return;
    }

    NSString *bankCode = [self valueForCodes:@[@"ifsc", @"bank_code"]];
    NSString *accountNo = [self valueForCodes:@[@"account_no"]];
    NSString *accountNoVerify = [self valueForCodes:@[@"account_no_verify"]];
    NSString *creditCard = [self valueForCodes:@[@"credit_card"]];
    NSString *accountName = [self valueForCodes:@[@"account_name", @"offend"]];
    if (accountNoVerify.length == 0) accountNoVerify = accountNo;
    if (!creditCard) creditCard = @"";

    NSDictionary *signedData = @{
        @"accountType": @"unknown",
        @"bankCode": bankCode ?: @"",
        @"accountNo": accountNo ?: @"",
    };
    NSMutableDictionary *unsignedData = [@{
        @"accountNoVerify": accountNoVerify ?: @"",
        @"creditCard": creditCard ?: @"",
    } mutableCopy];
    if (accountName.length > 0 && ![accountName isEqualToString:@"—"]) {
        unsignedData[@"accountName"] = accountName;
    }

    self.isSubmitting = YES;
    [self notify];
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/bankcard/modify"
                                         signedData:signedData
                                       unsignedData:unsignedData
                                        showLoading:@YES
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        [self notify];
        if (self.onCommitSuccess) self.onCommitSuccess();
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        [self notify];
    }];
}

@end
