

#import "HQITNetworkConstants.h"
#import "HQITDeviceInfoCollector.h"
#import <UIKit/UIKit.h>

NSString * const HQITAppId = @"emotecash";
NSString * const HQITSalt = @"nJV9FFRJ6rJkcRkY";
NSString * const HQITAdjustAppToken = @"ry93vjpnafi8";
NSString * const HQITSecretKey = @"MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBALHlrsKZ";
NSString * const HQITAPIVersion = @"2.0";
NSString * const HQITChannel = @"app_store";
NSString * const HQITOSValue = @"2";
NSString * const HQITClientLanguage = @"en";
NSString * const HQITFixedBaseURL = @"https://api.emotecash.com";
NSString * const HQITLogTag = @"[HQITNet]";
NSString * const HQITSystemBusyMessage = @"The system is busy. Please try again in 2 minutes.";

NSString * HQITClientUserAgentString(void) {
    static NSString *cached;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        if (ver.length == 0) ver = @"1.0.0";
        NSString *os = [UIDevice currentDevice].systemVersion ?: @"";
        NSString *model = [HQITDeviceInfoCollector deviceMarketingModelName];
        cached = [NSString stringWithFormat:@"%@/%@(Apple;Mobile;%@;iOS %@;)",
                  HQITAppId, ver, model, os];
    });
    return cached ?: HQITAppId;
}

NSString * HQITSanitizeNetworkErrorMessage(NSString *raw) {
    NSString *s = [raw isKindOfClass:[NSString class]]
        ? [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (s.length == 0) return HQITSystemBusyMessage;
    static NSRegularExpression *cjkRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cjkRegex = [NSRegularExpression regularExpressionWithPattern:@"[\\u4E00-\\u9FFF\\u3400-\\u4DBF\\uF900-\\uFAFF]"
                                                             options:0
                                                               error:nil];
    });
    if (cjkRegex && [cjkRegex numberOfMatchesInString:s options:0 range:NSMakeRange(0, s.length)] > 0) {
        return HQITSystemBusyMessage;
    }
    return s;
}

NSArray<NSString *> * HQITPublicParamOnlyEndpoints(void) {
    return @[
        @"/app/v3/app/config",
        @"/app/v3/category/gory",
        @"/app/v3/user/suphome",
        @"/app/v3/user/info",
        @"/app/v3/mobile/registerDevice",
        @"/app/v3/auth/close",
        @"/app/v3/payAccountInfo/update",
    ];
}

NSArray<NSString *> * HQITNoLoadingEndpoints(void) {
    return @[
        @"/app/v3/app/config",
        @"/app/v3/category/gory",
        @"/app/v3/mobile/device",
        @"/app/v3/mobile/registerDevice",
        @"/app/v3/mobile/contact",
        @"/app/v3/user/info",
        @"/app/v3/bury/record",
        @"/app/v3/product/termV3",
    ];
}

NSArray<NSString *> * HQITNoErrorToastEndpoints(void) {
    return @[
        @"/app/v3/app/config",
        @"/app/v3/category/gory",
        @"/app/v3/mobile/device",
        @"/app/v3/mobile/registerDevice",
        @"/app/v3/mobile/contact",
        @"/app/v3/user/info",
        @"/app/v3/bury/record",
        @"/app/v3/product/termV3",
    ];
}

NSArray<NSNumber *> * HQITTermV3NoToastCodes(void) {
    return @[ @6230002, @6230003, @6234303 ];
}

NSArray<NSNumber *> * HQITNoErrorToastCodes(void) {
    return @[ @6212011, @6212201, @2009006 ];
}
