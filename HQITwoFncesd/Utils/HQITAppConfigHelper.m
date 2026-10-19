

#import "HQITAppConfigHelper.h"
#import "HQITAppStartupManager.h"
#import "HQITCategoryText.h"

@implementation HQITAppConfigHelper

+ (id)dynamicParameterValueForKey:(NSString *)key {
    if (key.length == 0) return nil;
    id dp = [[HQITAppStartupManager shared] configValueForKey:@"dynamicParameter"];
    if (![dp isKindOfClass:[NSDictionary class]]) {
        dp = [[HQITAppStartupManager shared] configValueForKey:@"dynamic_parameter"];
    }
    if ([dp isKindOfClass:[NSDictionary class]]) {
        id v = dp[key] ?: dp[[key lowercaseString]];
        if (v != nil && v != [NSNull null]) return v;
    }
    // Flat fallback in cached config
    return [[HQITAppStartupManager shared] configValueForKey:key];
}


+ (NSString *)rejectH5URLString {
    id v = [[HQITAppStartupManager shared] configValueForKey:@"rejectH5"];
    if (![v isKindOfClass:[NSString class]] || [(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
        v = [self dynamicParameterValueForKey:@"rejectH5"];
    }
    if (![v isKindOfClass:[NSString class]] || [(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
        NSString *fromCategory = [HQITCategoryText textForKey:@"rejectH5" defaultText:@""];
        v = fromCategory.length > 0 ? fromCategory : nil;
    }
    if (![v isKindOfClass:[NSString class]]) return nil;
    return [self normalizeURLString:(NSString *)v];
}

+ (BOOL)isRejectH5Configured {
    return [self rejectH5URLString].length > 0;
}

+ (NSString *)normalizeURLString:(NSString *)raw {
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return nil;
    if ([s.lowercaseString isEqualToString:@"null"]) return nil;

    NSString *lower = s.lowercaseString;
    NSRange https = [lower rangeOfString:@"https://" options:NSBackwardsSearch];
    NSRange http = [lower rangeOfString:@"http://" options:NSBackwardsSearch];
    NSUInteger start = NSNotFound;
    if (https.location != NSNotFound) start = https.location;
    if (http.location != NSNotFound && (start == NSNotFound || http.location > start)) {
        start = http.location;
    }
    if (start != NSNotFound && start > 0) {
        s = [s substringFromIndex:start];
    }

    while ([s.lowercaseString containsString:@"/null/"]) {
        NSRange r = [s.lowercaseString rangeOfString:@"/null/"];
        if (r.location == NSNotFound) break;
        s = [NSString stringWithFormat:@"%@/%@", [s substringToIndex:r.location], [s substringFromIndex:NSMaxRange(r)]];
    }
    if ([s.lowercaseString hasSuffix:@"/null"]) {
        s = [s substringToIndex:s.length - 5];
    }

    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return nil;

    NSURL *u = [NSURL URLWithString:s];
    if (!u.scheme.length || u.host.length == 0) return nil;
    NSString *scheme = u.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return nil;
    NSString *host = u.host.lowercaseString ?: @"";
    if ([host isEqualToString:@"null"] || [host hasPrefix:@"null."]) return nil;
    return s;
}

+ (NSString *)fixedLocalWebURLForConfigKey:(NSString *)key {
    if ([key isEqualToString:@"conditionsHref"]) return @"https://www.emoteleasing.com/loanContract.html";
    if ([key isEqualToString:@"agreementHref"]) return @"https://www.emoteleasing.com/ServiceAgreement.html";
    if ([key isEqualToString:@"policyHref"]) return @"https://www.emoteleasing.com/PrivacyPolicy.html";
    if ([key isEqualToString:@"contactHref"]) return @"https://www.emoteleasing.com/contactUs.html";
    return nil;
}

+ (NSString *)fixedCustomerServiceEmail {
    return @"customercare@emoteleasing.com";
}

+ (NSString *)fixedOfficialWebsiteURL {
    return @"https://www.emoteleasing.com";
}

+ (NSString *)stringForHrefConfigKey:(NSString *)key {
    if (key.length == 0) return nil;
    if ([key isEqualToString:@"appEmail"]) return [self fixedCustomerServiceEmail];
    if ([key isEqualToString:@"officialWebsiteUrl"]) return [self fixedOfficialWebsiteURL];
    NSString *fixedWeb = [self fixedLocalWebURLForConfigKey:key];
    if (fixedWeb.length) return fixedWeb;
    id v = [[HQITAppStartupManager shared] configValueForKey:key];
    NSString *raw = nil;
    if ([v isKindOfClass:[NSString class]]) {
        raw = [(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } else if ([v respondsToSelector:@selector(stringValue)]) {
        raw = [[v stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (raw.length == 0 || [raw.lowercaseString isEqualToString:@"null"]) return nil;
    // Web href keys must be http(s)
    if ([key hasSuffix:@"Href"] || [key isEqualToString:@"rejectH5"]) {
        return [self normalizeURLString:raw];
    }
    return raw;
}

+ (NSInteger)integerForConfigKey:(NSString *)key defaultValue:(NSInteger)defaultValue {
    id v = [self dynamicParameterValueForKey:key];
    if (!v) v = [[HQITAppStartupManager shared] configValueForKey:key];
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length == 0) return defaultValue;
        return s.integerValue;
    }
    return defaultValue;
}

+ (NSInteger)feedbackGuidanceMode {
    id v = [self dynamicParameterValueForKey:@"feedbackGuidance"];
    if (!v) v = [self dynamicParameterValueForKey:@"feedback_guidance"];
    if (!v) v = [[HQITAppStartupManager shared] configValueForKey:@"feedbackGuidance"];
    if (!v) v = [[HQITAppStartupManager shared] configValueForKey:@"feedback_guidance"];
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v integerValue];
    return 0;
}

@end
