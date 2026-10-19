

#import "HQITKYCModels.h"
#import "HQITIndianPhoneValidator.h"

@implementation HQITKYCButtonOption
@end

@implementation HQITKYCFormRow

- (NSString *)commitValue {
    NSString *raw = self.valueKey.length > 0 ? self.valueKey : self.displayValue;
    raw = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (raw.length == 0 || [[raw uppercaseString] isEqualToString:@"NULL"]) return @"";
    return raw;
}

- (NSString *)submitValue {
    NSString *v = [self commitValue];
    if ([self isIndianMobileField] && v.length > 0) {
        NSString *norm = [HQITIndianPhoneValidator normalizedIndianMobileFrom:v];
        return norm.length ? norm : v;
    }
    return v;
}

- (BOOL)codeOrNameContains:(NSArray<NSString *> *)tokens {
    NSString *code = (self.itemCode ?: @"").lowercaseString;
    NSString *name = (self.itemName ?: @"").lowercaseString;
    for (NSString *t in tokens) {
        if ([code containsString:t] || [name containsString:t]) return YES;
    }
    return NO;
}

- (BOOL)isIndianMobileField {
    if ([self.itemCode.lowercaseString isEqualToString:@"whatsapp"]) return YES;
    return [self codeOrNameContains:@[@"phone", @"mobile", @"contact"]];
}

- (BOOL)isEmailField {
    return [self codeOrNameContains:@[@"email"]];
}

- (BOOL)isWhatsAppField {
    return [self.itemCode.lowercaseString isEqualToString:@"whatsapp"];
}

- (BOOL)isProvinceField {
    return [self codeOrNameContains:@[@"conservation", @"conservation", @"hybrid", @"hybrid"]];
}

- (BOOL)isCityField {
    return [self codeOrNameContains:@[@"hay", @"hay"]];
}

@end

@implementation HQITKYCStepInfo
@end

@implementation HQITKYCCommitItem
- (NSDictionary *)toDictionary {
    return @{
        @"itemCode": self.itemCode ?: @"",
        @"itemValueType": self.itemValueType ?: @"1",
        @"itemValue": self.itemValue ?: @"",
    };
}
@end
