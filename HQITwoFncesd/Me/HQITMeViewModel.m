

#import "HQITMeViewModel.h"
#import "HQITNetworkClient.h"
#import "HQITSessionManager.h"
#import "HQITStorageKeys.h"
#import "HQITAdjustManager.h"

@interface HQITMeViewModel ()
@property (nonatomic, copy, readwrite) NSString *displayName;
@property (nonatomic, copy, readwrite) NSString *maskedMobile;
@property (nonatomic, assign, readwrite) NSInteger userStatus;
@property (nonatomic, copy) NSString *rawName;
@property (nonatomic, copy) NSString *rawMobile;
@end

@implementation HQITMeViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadCached];
        [self refreshDisplay];
    }
    return self;
}

- (NSString *)appDisplayName {
    NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (name.length == 0) name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    return name.length ? name : @"QuickLoan";
}

- (void)loadCached {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    self.rawName = [ud stringForKey:HQITStorageKeyUserName] ?: @"";
    self.rawMobile = [ud stringForKey:HQITStorageKeyUserMobile] ?: @"";
    self.userStatus = [ud integerForKey:HQITStorageKeyUserStatus];
}

- (void)persist {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (self.rawName.length) [ud setObject:self.rawName forKey:HQITStorageKeyUserName];
    else [ud removeObjectForKey:HQITStorageKeyUserName];
    if (self.rawMobile.length) [ud setObject:self.rawMobile forKey:HQITStorageKeyUserMobile];
    else [ud removeObjectForKey:HQITStorageKeyUserMobile];
    [ud setInteger:self.userStatus forKey:HQITStorageKeyUserStatus];
    [ud synchronize];
}

- (void)clearCachedProfile {
    self.rawName = @"";
    self.rawMobile = @"";
    self.userStatus = 10;
    [self persist];
    [self refreshDisplay];
    if (self.onUpdated) self.onUpdated();
}

- (NSString *)maskMobile:(NSString *)mobile {
    NSString *digits = [[mobile componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
    if (digits.length >= 12 && [digits hasPrefix:@"91"]) {
        digits = [digits substringFromIndex:2];
    }
    if (digits.length >= 11 && [digits hasPrefix:@"0"]) {
        digits = [digits substringFromIndex:1];
    }
    if (digits.length == 0) {
        return mobile.length ? mobile : @"--";
    }
    if (digits.length == 10) {
        return [NSString stringWithFormat:@"+91 %@", digits];
    }
    if ([digits hasPrefix:@"91"] && digits.length > 2) {
        return [NSString stringWithFormat:@"+91 %@", [digits substringFromIndex:2]];
    }
    return digits;
}

- (void)refreshDisplay {
    // KYC incomplete: show app name instead of empty name
    if (self.userStatus == 10 || self.rawName.length == 0) {
        self.displayName = [self appDisplayName];
    } else {
        self.displayName = self.rawName;
    }
    self.maskedMobile = [self maskMobile:self.rawMobile];
}

- (void)reloadUserInfo {
    if (![HQITSessionManager shared].isLoggedIn) {
        [self clearCachedProfile];
        return;
    }
    NSMutableDictionary *unsignedData = [NSMutableDictionary dictionary];
    NSString *adid = [[HQITAdjustManager shared] currentAdid];
    if (adid.length > 0) {
        unsignedData[@"adid"] = adid;
    }

    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/user/info"
                                         signedData:@{}
                                       unsignedData:unsignedData.count ? unsignedData : nil
                                        showLoading:@YES
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSDictionary *data = [response.data isKindOfClass:[NSDictionary class]] ? response.data : @{};
        NSString *name = [self stringFrom:data key:@"name"];
        // Empty name clears cache (§11.2)
        self.rawName = name ?: @"";
        NSString *mobile = [self stringFrom:data key:@"phone"];
        if (mobile.length) self.rawMobile = mobile;
        id statusVal = data[@"userStatus"] ?: @(self.userStatus);
        NSInteger status = [[statusVal description] integerValue];
        self.userStatus = status;
        [self persist];
        [self refreshDisplay];
        if (self.onUpdated) self.onUpdated();
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self refreshDisplay];
        if (self.onUpdated) self.onUpdated();
    }];
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
        if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) return v;
        if ([v respondsToSelector:@selector(stringValue)] && [[v stringValue] length] > 0) return [v stringValue];
    }
    return @"";
}

@end
