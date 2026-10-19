

#import "HQITKYCEmergencyViewModel.h"
#import "HQITNetworkClient.h"
#import "HQITCategoryText.h"
#import "HQITIndianPhoneValidator.h"

@implementation HQITKYCEmergencyGroup

- (NSString *)sectionTitle {
    return [NSString stringWithFormat:@"Contact %02ld", (long)MAX(self.groupNo, 1)];
}

- (BOOL)isCompletelyEmpty {
    NSString *n = [self.nameRow commitValue];
    NSString *p = [self.phoneRow commitValue];
    NSString *r = [self.relationRow commitValue];
    return n.length == 0 && p.length == 0 && r.length == 0;
}

@end

@interface HQITKYCEmergencyViewModel ()
@property (nonatomic, copy, readwrite) NSString *kycId;
@property (nonatomic, copy, readwrite) NSArray<HQITKYCEmergencyGroup *> *groups;
@property (nonatomic, strong, readwrite, nullable) HQITKYCFormRow *emailRow;
@property (nonatomic, copy, readwrite) NSArray<HQITKYCFormRow *> *rows;
@property (nonatomic, assign, readwrite) BOOL isSubmitting;
@end

@implementation HQITKYCEmergencyViewModel

- (instancetype)initWithKycId:(NSString *)kycId {
    self = [super init];
    if (self) {
        _kycId = [kycId copy] ?: @"";
        _groups = @[];
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
        [self rebuildGroups];
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
        if ([row isEmailField]) {
            if (maxL <= 0 || maxL > 128) maxL = 128;
        } else if (maxL <= 0) {
            maxL = 100;
        }
        row.maxLength = maxL;

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

        NSString *prefill = [NSString stringWithFormat:@"%@", d[@"expense"] ?: d[@"value"] ?: d[@"displayValue"] ?: @""];
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
            if ([row isEmailField] && (NSInteger)row.displayValue.length > row.maxLength && row.maxLength > 0) {
                row.displayValue = [row.displayValue substringToIndex:(NSUInteger)row.maxLength];
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

- (BOOL)isRelationRow:(HQITKYCFormRow *)row {
    return [row.itemCode.lowercaseString containsString:@"relation"];
}

- (BOOL)isNameRow:(HQITKYCFormRow *)row {
    NSString *c = row.itemCode.lowercaseString;
    if ([c containsString:@"relation"]) return NO;
    return [c containsString:@"name"];
}

- (BOOL)isPhoneRow:(HQITKYCFormRow *)row {
    return [row isIndianMobileField] && ![row isWhatsAppField] && ![row isEmailField];
}

- (NSInteger)groupNoForRow:(HQITKYCFormRow *)row {
    NSString *code = row.itemCode.lowercaseString;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"(?:contact|urgent|emerg)[^0-9]*([0-9]+)"
                                                                        options:0
                                                                          error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:code options:0 range:NSMakeRange(0, code.length)];
    if (m && m.numberOfRanges > 1) {
        NSString *num = [code substringWithRange:[m rangeAtIndex:1]];
        NSInteger n = num.integerValue;
        if (n > 0) return n;
    }
    // Doc: max(1, itemSort/10)
    return (NSInteger)MAX(1L, (long)(row.itemSort / 10));
}

- (void)rebuildGroups {
    NSMutableDictionary<NSNumber *, HQITKYCEmergencyGroup *> *map = [NSMutableDictionary dictionary];
    HQITKYCFormRow *email = nil;

    for (HQITKYCFormRow *row in self.rows) {
        if ([row isEmailField]) {
            email = row;
            continue;
        }
        NSInteger gNo = [self groupNoForRow:row];
        HQITKYCEmergencyGroup *g = map[@(gNo)];
        if (!g) {
            g = [[HQITKYCEmergencyGroup alloc] init];
            g.groupNo = gNo;
            map[@(gNo)] = g;
        }
        if ([self isRelationRow:row]) g.relationRow = row;
        else if ([self isNameRow:row]) g.nameRow = row;
        else if ([row.itemCode.lowercaseString containsString:@"phone"]
                 || [row.itemCode.lowercaseString containsString:@"mobile"]
                 || [self isPhoneRow:row]) {
            g.phoneRow = row;
        }
    }

    NSArray *keys = [[map allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *groups = [NSMutableArray array];
    NSInteger displayNo = 1;
    for (NSNumber *k in keys) {
        HQITKYCEmergencyGroup *g = map[k];
        g.groupNo = displayNo++;
        [groups addObject:g];
    }
    self.groups = groups;
    self.emailRow = email;
}

- (void)applyRelation:(HQITKYCFormRow *)row key:(NSString *)key label:(NSString *)label {
    row.valueKey = key;
    row.displayValue = label;
    [self notify];
}

- (void)applyEmail:(NSString *)text {
    if (!self.emailRow) return;
    NSString *t = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger maxL = self.emailRow.maxLength > 0 ? MIN(self.emailRow.maxLength, 128) : 128;
    if ((NSInteger)t.length > maxL) {
        t = [t substringToIndex:(NSUInteger)maxL];
    }
    self.emailRow.displayValue = t;
    self.emailRow.maxLength = maxL;
}

- (void)clearNamePhoneForGroup:(HQITKYCEmergencyGroup *)group {
    group.nameRow.displayValue = nil;
    group.nameRow.valueKey = nil;
    group.phoneRow.displayValue = nil;
    group.phoneRow.valueKey = nil;
    [self notify];
}

- (NSString *)displayPhoneForRow:(HQITKYCFormRow *)phoneRow {
    NSString *raw = [phoneRow commitValue];
    if (raw.length == 0) return @"";
    NSString *norm = [HQITIndianPhoneValidator normalizedIndianMobileFrom:raw] ?: [HQITIndianPhoneValidator digitsOnly:raw];
    if (norm.length == 10) {
        return [NSString stringWithFormat:@"%@ %@",
                [norm substringToIndex:5],
                [norm substringFromIndex:5]];
    }
    if (norm.length > 0) return norm;
    return raw;
}

- (NSString *)validateAndApplyContactName:(NSString *)name
                                    phone:(NSString *)phone
                                 forGroup:(HQITKYCEmergencyGroup *)group {
    NSString *nm = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *digits = [HQITIndianPhoneValidator digitsOnly:phone];
    if (digits.length == 12 && [digits hasPrefix:@"91"]) {
        digits = [digits substringFromIndex:2];
    }
    NSString *norm = [HQITIndianPhoneValidator normalizedIndianMobileFrom:digits];
    if (nm.length == 0 || digits.length == 0) {
        return @"Invalid contact";
    }
    if (!norm.length) {
        return [HQITCategoryText textForKey:@"m14" defaultText:@"Please enter correct phone number"];
    }
    for (HQITKYCEmergencyGroup *g in self.groups) {
        if (g == group) continue;
        NSString *other = [HQITIndianPhoneValidator normalizedIndianMobileFrom:[g.phoneRow commitValue]];
        if (other.length && [other isEqualToString:norm]) {
            return [HQITCategoryText textForKey:@"m13"
                                  defaultText:@"This contact has already been submitted. Please use another contact."];
        }
    }
    group.nameRow.displayValue = nm;
    group.phoneRow.displayValue = norm;
    [self notify];
    return nil;
}

- (NSString *)a25ForItemName:(NSString *)name {
    NSString *tpl = [HQITCategoryText textForKey:@"a25"
                                   defaultText:@"KT_XXX is empty or in an incorrect format."];
    return [tpl stringByReplacingOccurrencesOfString:@"KT_XXX" withString:name.length ? name : @"Field"];
}

- (NSString *)incompleteMessageForGroup:(NSInteger)groupNo {
    NSString *key = (arc4random_uniform(2) == 0) ? @"m19" : @"m20";
    NSString *tpl = [HQITCategoryText textForKey:key
                                    defaultText:@"Contact KT_CONTACTNO is incomplete. Please fill in relationship, name and phone."];
    return [tpl stringByReplacingOccurrencesOfString:@"KT_CONTACTNO"
                                         withString:[NSString stringWithFormat:@"%ld", (long)groupNo]];
}

- (NSString *)validateEmergencyRows {
    static NSString *emailRegex = @"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}([.-][A-Za-z]{2,})*$";

    for (HQITKYCEmergencyGroup *g in self.groups) {
        if ([g isCompletelyEmpty]) continue;
        NSString *name = [g.nameRow commitValue];
        NSString *phone = [g.phoneRow commitValue];
        NSString *rel = [g.relationRow commitValue];
        if (name.length == 0 || phone.length == 0 || rel.length == 0) {
            return [self incompleteMessageForGroup:g.groupNo];
        }
        if (![HQITIndianPhoneValidator isValidIndianMobile:phone]) {
            return [HQITCategoryText textForKey:@"m14" defaultText:@"Please enter correct phone number"];
        }
    }

    NSMutableSet *seen = [NSMutableSet set];
    for (HQITKYCEmergencyGroup *g in self.groups) {
        NSString *norm = [HQITIndianPhoneValidator normalizedIndianMobileFrom:[g.phoneRow commitValue]];
        if (norm.length == 0) continue;
        if ([seen containsObject:norm]) {
            return [HQITCategoryText textForKey:@"m13"
                                  defaultText:@"This contact has already been submitted. Please use another contact."];
        }
        [seen addObject:norm];
    }

    if (self.emailRow) {
        NSString *email = [self.emailRow commitValue];
        if (self.emailRow.isRequired && email.length == 0) {
            return @"Please enter your Email";
        }
        if (email.length > 0) {
            NSString *pattern = self.emailRow.regularExpression.length ? self.emailRow.regularExpression : emailRegex;
            NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
            if (![p evaluateWithObject:email]) {
                return [HQITCategoryText textForKey:@"m12" defaultText:@"Invalid email format."];
            }
        }
    }

    for (HQITKYCFormRow *row in self.rows) {
        if ([row isEmailField]) continue;
        if ([self isRelationRow:row] || [self isNameRow:row] || [self isPhoneRow:row]
            || [row.itemCode.lowercaseString containsString:@"phone"]
            || [row.itemCode.lowercaseString containsString:@"mobile"]) {
            continue;
        }
        NSString *cv = [row commitValue];
        if (row.isRequired && cv.length == 0) {
            return [self a25ForItemName:row.itemName];
        }
        if (cv.length > 0 && row.regularExpression.length > 0) {
            NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", row.regularExpression];
            if (![p evaluateWithObject:cv]) {
                return [self a25ForItemName:row.itemName];
            }
        }
    }
    return nil;
}

- (void)commit {
    if (self.isSubmitting) return;
    NSString *err = [self validateEmergencyRows];
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

@end
