

#import "HQITKYCFormViewModel.h"
#import "HQITNetworkClient.h"
#import "HQITCategoryText.h"
#import "HQITIndianPhoneValidator.h"
#import "HQITHUDHelper.h"
#import <ctype.h>

@interface HQITKYCFormViewModel ()
@property (nonatomic, copy, readwrite) NSString *kycId;
@property (nonatomic, copy, readwrite) NSArray<HQITKYCFormRow *> *rows;
@property (nonatomic, assign, readwrite) BOOL isSubmitting;
@end

@implementation HQITKYCFormViewModel

- (instancetype)initWithKycId:(NSString *)kycId {
    self = [super init];
    if (self) {
        _kycId = [kycId copy] ?: @"";
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
                                         signedData:@{@"kycId": self.kycId ?: @""}
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.rows = [self parseRows:response.data];
        [self notify];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.onErrorMessage) self.onErrorMessage(message.length ? message : @"Load failed");
    }];
}

- (NSArray<HQITKYCFormRow *> *)parseRows:(id)raw {
    NSArray *list = nil;
    if ([raw isKindOfClass:[NSDictionary class]]) {
        id v = raw[@"kycItemList"] ?: raw[@"kycItemList"] ?: raw[@"itemList"] ?: raw[@"exact"];
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
        id codeVal = d[@"itemCode"];
        row.itemCode = codeVal ? [[NSString stringWithFormat:@"%@", codeVal] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
        if ([row.itemCode isEqualToString:@"(null)"]) row.itemCode = @"";
        row.itemName = [NSString stringWithFormat:@"%@", d[@"itemName"] ?: d[@"itemName"] ?: d[@"item_name"] ?: @""];
        if ([row.itemName isEqualToString:@"(null)"]) row.itemName = @"";
        row.itemType = [d[@"itemType"] ?: d[@"itemType"] ?: d[@"item_type"] ?: @1 integerValue];
        row.isRequired = [[d[@"isRequired"] ?: d[@"isRequired"] ?: d[@"is_required"] ?: @0 description] integerValue] == 1;
        row.itemSort = [d[@"itemSort"] ?: d[@"itemSort"] ?: d[@"item_sort"] ?: @0 integerValue];
        row.regularExpression = d[@"regularExpression"] ?: d[@"regularExpression"] ?: d[@"regular_expression"];
        NSInteger maxL = [d[@"maxLength"] ?: d[@"max_length"] ?: @0 integerValue];
        row.maxLength = maxL > 0 ? maxL : [self defaultMaxLengthForCode:row.itemCode];

        NSMutableArray *buttons = [NSMutableArray array];
        id bl = d[@"buttonList"] ?: d[@"buttonList"] ?: d[@"button_list"];
        if ([bl isKindOfClass:[NSArray class]]) {
            for (id b in (NSArray *)bl) {
                if (![b isKindOfClass:[NSDictionary class]]) continue;
                HQITKYCButtonOption *opt = [[HQITKYCButtonOption alloc] init];
                opt.buttonKey = [NSString stringWithFormat:@"%@", b[@"buttonKey"] ?: b[@"key"] ?: @""];
                opt.buttonLabel = [NSString stringWithFormat:@"%@", b[@"buttonLabel"] ?: b[@"exit"] ?: b[@"button_label"] ?: b[@"label"] ?: @""];
                opt.buttonSort = [b[@"buttonSort"] ?: b[@"buttonSort"] ?: b[@"button_sort"] ?: @0 integerValue];
                if ([opt.buttonKey isEqualToString:@"(null)"]) opt.buttonKey = @"";
                if ([opt.buttonLabel isEqualToString:@"(null)"]) opt.buttonLabel = @"";
                [buttons addObject:opt];
            }
            [buttons sortUsingComparator:^NSComparisonResult(HQITKYCButtonOption *a, HQITKYCButtonOption *b) {
                return a.buttonSort < b.buttonSort ? NSOrderedAscending : (a.buttonSort > b.buttonSort ? NSOrderedDescending : NSOrderedSame);
            }];
        }
        row.buttonList = buttons;

        // Prefill
        NSString *prefill = [NSString stringWithFormat:@"%@", d[@"itemValue"] ?: d[@"value"] ?: d[@"displayValue"] ?: @""];
        if (prefill.length > 0 && ![prefill isEqualToString:@"(null)"]) {
            if (row.itemType == HQITKYCItemTypeLocalSelect || row.itemType == HQITKYCItemTypeAPISelect) {
                row.valueKey = prefill;
                for (HQITKYCButtonOption *o in buttons) {
                    if ([o.buttonKey isEqualToString:prefill]) {
                        row.displayValue = o.buttonLabel;
                        break;
                    }
                }
                if (row.displayValue.length == 0) row.displayValue = prefill;
            } else {
                row.displayValue = prefill;
            }
        }
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
    if ([c isEqualToString:@"child_count"]) return 3;
    if ([c isEqualToString:@"account_no"] || [c isEqualToString:@"account_no_verify"]) return 18;
    if ([c isEqualToString:@"credit_card"]) return 32;
    if ([c isEqualToString:@"ifsc"]) return 11;
    if ([c containsString:@"email"]) return 128;
    if ([c isEqualToString:@"whatsapp"]) return 13;
    if ([c isEqualToString:@"zip_code"]) return 16;
    if ([c isEqualToString:@"first_name"] || [c isEqualToString:@"last_name"]) return 50;
    if ([c isEqualToString:@"address"]) return 256;
    return 100;
}

- (NSInteger)maxLengthForRow:(HQITKYCFormRow *)row {
    if (row.maxLength > 0) return row.maxLength;
    return [self defaultMaxLengthForCode:row.itemCode];
}

- (NSString *)filterInput:(NSString *)text forRow:(HQITKYCFormRow *)row {
    NSString *code = row.itemCode.lowercaseString;
    NSString *out = text ?: @"";
    if ([code isEqualToString:@"child_count"] || [code isEqualToString:@"whatsapp"] ||
        [code isEqualToString:@"account_no"] || [code isEqualToString:@"account_no_verify"] ||
        [code isEqualToString:@"credit_card"] || [code isEqualToString:@"zip_code"] ||
        [row isIndianMobileField]) {
        out = [HQITIndianPhoneValidator digitsOnly:out];
        if ([row isIndianMobileField] || [row isWhatsAppField]) {
            NSInteger max = [HQITIndianPhoneValidator maxLengthForDigits:out];
            if ((NSInteger)out.length > max) out = [out substringToIndex:max];
            // reject illegal prefix
            if (out.length > 0) {
                unichar f = [out characterAtIndex:0];
                if (f != '0' && (f < '6' || f > '9')) {
                    return row.displayValue ?: @"";
                }
            }
        }
    } else if ([code isEqualToString:@"ifsc"]) {
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

- (void)applySelectionForRow:(HQITKYCFormRow *)row key:(NSString *)key label:(NSString *)label {
    row.valueKey = key;
    row.displayValue = label;
    if ([row isProvinceField]) {
        row.provinceId = key;
        [self clearCityRows];
    }
    if ([row isCityField]) {
        // keep
    }
    [self notify];
}

- (void)applyInputForRow:(HQITKYCFormRow *)row text:(NSString *)text {
    row.displayValue = [self filterInput:text forRow:row];
    row.valueKey = nil;
    // Do not notify — avoid rebuilding text fields on every keystroke.
}

- (HQITKYCFormRow *)provinceRow {
    for (HQITKYCFormRow *r in self.rows) {
        if ([r isProvinceField]) return r;
    }
    return nil;
}

- (void)clearCityRows {
    for (HQITKYCFormRow *r in self.rows) {
        if ([r isCityField]) {
            r.displayValue = nil;
            r.valueKey = nil;
        }
    }
}

- (NSString *)a25ForItemName:(NSString *)name {
    NSString *tpl = [HQITCategoryText textForKey:@"a25"
                                   defaultText:@"KT_XXX is empty or in an incorrect format."];
    return [tpl stringByReplacingOccurrencesOfString:@"KT_XXX" withString:name.length ? name : @"Field"];
}

- (NSString *)validateFormRows {
    static NSString *emailRegex = @"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}([.-][A-Za-z]{2,})*$";
    HQITKYCFormRow *province = nil;
    HQITKYCFormRow *city = nil;
    for (HQITKYCFormRow *row in self.rows) {
        if ([row isProvinceField]) province = row;
        if ([row isCityField]) city = row;

        NSString *cv = [row commitValue];
        if (row.isRequired && cv.length == 0) {
            return [self a25ForItemName:row.itemName];
        }
        if (row.itemType == HQITKYCItemTypeInput && cv.length > 0) {
            if ([row isEmailField]) {
                NSString *pattern = row.regularExpression.length ? row.regularExpression : emailRegex;
                NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
                if (![p evaluateWithObject:cv]) {
                    return [self a25ForItemName:row.itemName];
                }
            }
            if ([row isIndianMobileField]) {
                if (![HQITIndianPhoneValidator isValidIndianMobile:cv]) {
                    return [HQITCategoryText textForKey:@"m14" defaultText:@"Please enter correct phone number"];
                }
            }
            if (row.regularExpression.length > 0 && ![row isEmailField]) {
                NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", row.regularExpression];
                if (![p evaluateWithObject:cv]) {
                    return [self a25ForItemName:row.itemName];
                }
            }
        }
    }
    if (province && city) {
        if ([province commitValue].length == 0 && [city commitValue].length > 0) {
            return [HQITCategoryText textForKey:@"k22" defaultText:@"Please select province first."];
        }
    }
    return nil;
}

- (void)commit {
    if (self.isSubmitting) return;
    NSString *err = [self validateFormRows];
    if (err.length) {
        if (self.onErrorMessage) self.onErrorMessage(err);
        return;
    }
    NSMutableArray *list = [NSMutableArray array];
    for (HQITKYCFormRow *row in self.rows) {
        NSString *v = [row submitValue];
        if (v.length == 0) continue;
        HQITKYCCommitItem *item = [[HQITKYCCommitItem alloc] init];
        item.itemCode = row.itemCode;
        item.itemValueType = @"1";
        item.itemValue = v;
        [list addObject:[item toDictionary]];
    }

    self.isSubmitting = YES;
    [self notify];
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/kyc/commit"
                                         signedData:@{@"kycId": self.kycId ?: @""}
                                       unsignedData:@{
                                           @"kycCommitItemList": list,
                                       }
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

- (NSArray<HQITKYCButtonOption *> *)parseRemoteOptions:(id)raw {
    NSArray *list = nil;
    if ([raw isKindOfClass:[NSDictionary class]]) {
        id v = raw[@"buttonList"] ?: raw[@"list"] ?: raw[@"data"];
        if ([v isKindOfClass:[NSArray class]]) list = v;
    } else if ([raw isKindOfClass:[NSArray class]]) {
        list = raw;
    }
    NSMutableArray *opts = [NSMutableArray array];
    for (id item in list ?: @[]) {
        if ([item isKindOfClass:[NSString class]]) {
            [opts addObject:[HQITKYCButtonOption new]];
            HQITKYCButtonOption *o = opts.lastObject;
            o.buttonKey = item;
            o.buttonLabel = item;
            continue;
        }
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = (NSDictionary *)item;
        HQITKYCButtonOption *o = [[HQITKYCButtonOption alloc] init];
        o.buttonKey = [NSString stringWithFormat:@"%@", d[@"buttonKey"] ?: d[@"provinceId"] ?: d[@"cityId"] ?: d[@"id"] ?: d[@"key"] ?: @""];
        o.buttonLabel = [NSString stringWithFormat:@"%@", d[@"buttonLabel"] ?: d[@"provinceName"] ?: d[@"cityName"] ?: d[@"name"] ?: d[@"label"] ?: o.buttonKey];
        if ([o.buttonKey isEqualToString:@"(null)"]) o.buttonKey = @"";
        if ([o.buttonLabel isEqualToString:@"(null)"]) o.buttonLabel = o.buttonKey;
        [opts addObject:o];
    }
    return opts;
}

- (void)loadProvinceOptionsThen:(void (^)(NSArray<HQITKYCButtonOption *> *))completion {
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/sys/province"
                                         signedData:@{@"countryId": @"63"}
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        if (completion) completion([self parseRemoteOptions:response.data]);
    } failure:^(NSError *error, NSString *message) {
        if (completion) completion(@[]);
    }];
}

- (void)loadCityOptionsForProvinceId:(NSString *)provinceId
                                then:(void (^)(NSArray<HQITKYCButtonOption *> *))completion {
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/sys/city"
                                         signedData:@{@"provinceId": provinceId ?: @"", @"countryId": @"63"}
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        if (completion) completion([self parseRemoteOptions:response.data]);
    } failure:^(NSError *error, NSString *message) {
        if (completion) completion(@[]);
    }];
}

@end
