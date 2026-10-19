

#import "HQITDeviceInfoCollector.h"
#import "HQITSessionManager.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <mach/mach.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <netinet/in.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreLocation/CoreLocation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CFNetwork/CFNetwork.h>
#import <AFNetworking/AFNetworkReachabilityManager.h>
#import <objc/runtime.h>

@interface HQITDeviceInfoCollector (WiFiPrivate)
+ (BOOL)hqit_hasLocationAuth;
+ (NSDictionary<NSString *, NSString *> *)emptyWiFiInfo;
@end

static NSString * const kHQITWiFiTempAccuracyPurposeKey = @"WifiSSID";

@interface HQITWiFiLocationWarmer : NSObject <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *manager;
@property (nonatomic, copy, nullable) void (^onDone)(void);
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL didKickLocation;
@end

@implementation HQITWiFiLocationWarmer

- (instancetype)init {
    self = [super init];
    if (self) {
        _manager = [[CLLocationManager alloc] init];
        _manager.delegate = self;
        _manager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }
    return self;
}

- (void)warmThen:(void (^)(void))block {
    self.onDone = block;
    if (![HQITDeviceInfoCollector hqit_hasLocationAuth]) {
        [self complete];
        return;
    }
    __weak typeof(self) weakSelf = self;
    void (^kickLocation)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.finished || self.didKickLocation) return;
        self.didKickLocation = YES;
        if (@available(iOS 14.0, *)) {
            [self.manager requestLocation];
        } else {
            [self.manager startUpdatingLocation];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf complete];
        });
    };

    if (@available(iOS 14.0, *)) {
        if (self.manager.accuracyAuthorization == CLAccuracyAuthorizationReducedAccuracy) {
            NSLog(@"[WiFi] location accuracy=reduced → requestTemporaryFullAccuracy purpose=%@",
                  kHQITWiFiTempAccuracyPurposeKey);
            [self.manager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:kHQITWiFiTempAccuracyPurposeKey
                                                                       completion:^(NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self || self.finished) return;
                    if (error) {
                        NSLog(@"[WiFi] temporary full accuracy fail: %@", error.localizedDescription);
                    } else {
                        NSLog(@"[WiFi] temporary full accuracy done acc=%ld",
                              (long)self.manager.accuracyAuthorization);
                    }
                    kickLocation();
                });
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || self.finished || self.didKickLocation) return;
                NSLog(@"[WiFi] temporary full accuracy timeout → continue warm");
                kickLocation();
            });
            return;
        }
    }
    kickLocation();
}

- (void)complete {
    if (self.finished) return;
    self.finished = YES;
    [self.manager stopUpdatingLocation];
    void (^block)(void) = self.onDone;
    self.onDone = nil;
    if (block) block();
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    [self complete];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"[WiFi] location warm fail: %@", error.localizedDescription);
    [self complete];
}

@end

@implementation HQITDeviceInfoCollector

#pragma mark - Public

+ (NSDictionary<NSString *, NSString *> *)collectDeviceInfoIncludeWiFiDetails:(BOOL)includeWiFiDetails {
    return [self collectDeviceInfoWithOrderId:nil includeWiFiDetails:includeWiFiDetails];
}

+ (NSDictionary<NSString *, NSString *> *)collectDeviceInfoWithOrderId:(NSString *)orderId
                                                 includeWiFiDetails:(BOOL)includeWiFiDetails {
    NSMutableDictionary<NSString *, NSString *> *dict = [NSMutableDictionary dictionary];
    UIDevice *device = [UIDevice currentDevice];
    device.batteryMonitoringEnabled = YES;

    NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    dict[@"versionCode"] = (ver.length > 0) ? ver : @"1.0.0";
    dict[@"idfv"] = [self nullSafe:device.identifierForVendor.UUIDString];
    dict[@"uuid"] = [self nullSafe:[HQITSessionManager shared].deviceId];
    dict[@"idfa"] = [self idfaString];
    NSString *oid = [orderId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    dict[@"orderId"] = (oid.length > 0) ? oid : @"null";

    dict[@"ramTotal"] = [self formatGBFromBytes:[NSProcessInfo processInfo].physicalMemory];
    dict[@"ramCanUse"] = [self formatGBFromBytes:[self freeMemoryBytes]];
    unsigned long long sysSize = 0, sysFree = 0;
    [self fileSystemSize:&sysSize freeSize:&sysFree];
    dict[@"cashTotal"] = [self formatGBFromBytes:sysSize];
    dict[@"cashCanUse"] = [self formatGBFromBytes:sysFree];

    NSTimeInterval uptime = [NSProcessInfo processInfo].systemUptime;
    long long bootMs = (long long)llround(uptime * 1000.0);
    dict[@"totalBootTime"] = [NSString stringWithFormat:@"%lld", bootMs];
    dict[@"totalBootTimeWake"] = dict[@"totalBootTime"];
    NSTimeInterval lastBoot = [[NSDate date] timeIntervalSince1970] - uptime;
    dict[@"lastBootTime"] = [NSString stringWithFormat:@"%lld", (long long)llround(lastBoot * 1000.0)];
    BOOL charging = (device.batteryState == UIDeviceBatteryStateCharging
                     || device.batteryState == UIDeviceBatteryStateFull);
    dict[@"charged"] = charging ? @"true" : @"false";
    float level = device.batteryLevel;
    NSInteger pct = (level < 0) ? 0 : (NSInteger)llround(level * 100.0);
    dict[@"batteryLevel"] = [NSString stringWithFormat:@"%ld", (long)pct];

#if DEBUG
    dict[@"debugged"] = @"true";
#else
    dict[@"debugged"] = @"false";
#endif
#if TARGET_OS_SIMULATOR
    dict[@"simulated"] = @"true";
#else
    dict[@"simulated"] = @"false";
#endif
    dict[@"rooted"] = [self isJailbroken] ? @"true" : @"false";
    dict[@"proxied"] = [self isProxied] ? @"true" : @"false";
    dict[@"isvpn"] = [self isVPNConnected] ? @"true" : @"false";

    dict[@"systemVersions"] = [self nullSafe:device.systemVersion];
    NSString *lang = [NSLocale currentLocale].languageCode;
    dict[@"defaultLanguage"] = [self nullSafe:lang];
    dict[@"defaultTimeZone"] = [self nullSafe:[NSTimeZone localTimeZone].name];
    CGRect bounds = UIScreen.mainScreen.bounds;
    CGFloat native = UIScreen.mainScreen.nativeScale;
    NSInteger pxW = (NSInteger)llround(bounds.size.width * native);
    NSInteger pxH = (NSInteger)llround(bounds.size.height * native);
    dict[@"screenResolution"] = [NSString stringWithFormat:@"%ld-%ld", (long)pxW, (long)pxH];
    dict[@"screenWidth"] = [NSString stringWithFormat:@"%ld", (long)(NSInteger)bounds.size.width];
    dict[@"screenHeight"] = [NSString stringWithFormat:@"%ld", (long)(NSInteger)bounds.size.height];
    dict[@"screenBrightness"] = [NSString stringWithFormat:@"%ld",
                                 (long)llround(UIScreen.mainScreen.brightness * 100.0)];
    dict[@"cpuNum"] = [NSString stringWithFormat:@"%ld", (long)[NSProcessInfo processInfo].processorCount];
    dict[@"deviceType"] = @"3";
    dict[@"sdkVersion"] = @"null";

    dict[@"network"] = [self networkCodeString];
    if (includeWiFiDetails) {
        NSDictionary *wifi = [self wifiInfo];
        [dict addEntriesFromDictionary:wifi];
    } else {
        dict[@"wifiSsid"] = @"null";
        dict[@"wifiName"] = @"null";
        dict[@"wifiBssid"] = @"null";
        dict[@"mac"] = @"null";
    }

    dict[@"phoneMark"] = [self nullSafe:[self deviceModelMachine]];
    dict[@"phoneType"] = [self nullSafe:device.name];

    // §3.4.8 SIM
    [self fillTelephony:dict];

    dict[@"videoInternal"] = @"-99";
    dict[@"albumFile"] = @"-99";
    dict[@"imageInternal"] = @"-99";

    return [self sanitizeAndFilter:dict];
}

+ (void)collectDeviceInfoForOrder:(NSString *)orderId
                       completion:(void (^)(NSDictionary<NSString *, NSString *> *info))completion {
    void (^finish)(NSDictionary *) = ^(NSDictionary *info) {
        if (!completion) return;
        if ([NSThread isMainThread]) {
            completion(info);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(info); });
        }
    };
    void (^run)(void) = ^{
        NSMutableDictionary *base =
            [[self collectDeviceInfoWithOrderId:orderId includeWiFiDetails:NO] mutableCopy];
        [self fetchWiFiInfoAsync:^(NSDictionary<NSString *, NSString *> *wifi) {
            if (wifi.count) [base addEntriesFromDictionary:wifi];
            finish([self sanitizeAndFilter:base]);
        }];
    };
    if ([NSThread isMainThread]) {
        run();
    } else {
        dispatch_async(dispatch_get_main_queue(), run);
    }
}

+ (BOOL)hqit_hasLocationAuth {
    CLAuthorizationStatus st = [CLLocationManager authorizationStatus];
    return (st == kCLAuthorizationStatusAuthorizedWhenInUse
            || st == kCLAuthorizationStatusAuthorizedAlways);
}

#pragma mark - Sanitize

+ (NSSet<NSString *> *)excludedUploadFieldKeys {
    return [NSSet setWithArray:@[
        @"batteryTemperature", @"batteryHealth", @"batteryMax",
        @"cpuMinFrequency", @"cpuMaxFrequency", @"cpuCurrentFrequency", @"cpuModel",
        @"productionDate", @"imei", @"androidId",
        @"audioExternal", @"audioInternal", @"videoExternal",
        @"appVersion", @"systemVersion", @"deviceUUID", @"deviceUuid", @"networkType",
        @"storageCapacity", @"availableStorage", @"totalMemory", @"availableMemory",
        @"runningTime", @"chargingStatus", @"charging", @"brightness", @"screenSize",
        @"language", @"timezone", @"timeZone", @"proxy", @"vpn",
        @"deviceBrand", @"household", @"reserve",
        @"deviceName", @"deviceModel", @"deviceUUID",
    ]];
}

+ (NSDictionary<NSString *, NSString *> *)sanitizeAndFilter:(NSDictionary<NSString *, NSString *> *)raw {
    NSSet *excluded = [self excludedUploadFieldKeys];
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    [raw enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (![key isKindOfClass:[NSString class]] || [excluded containsObject:key]) return;
        NSString *s = nil;
        if ([obj isKindOfClass:[NSString class]]) {
            s = (NSString *)obj;
        } else if ([obj isKindOfClass:[NSNumber class]]) {
            s = [(NSNumber *)obj stringValue];
        } else if (obj == nil || obj == [NSNull null]) {
            s = @"";
        } else {
            s = [NSString stringWithFormat:@"%@", obj];
        }
        if ([s isEqualToString:@"(null)"]) s = @"";
        out[key] = [self nullSafe:s];
    }];
    return out;
}

+ (NSString *)nullSafe:(NSString *)value {
    return value.length > 0 ? value : @"null";
}

#pragma mark - Identity

+ (NSString *)idfaString {
    if (@available(iOS 14, *)) {
        if (ATTrackingManager.trackingAuthorizationStatus != ATTrackingManagerAuthorizationStatusAuthorized) {
            return @"null";
        }
    }
    NSString *idfa = [ASIdentifierManager sharedManager].advertisingIdentifier.UUIDString ?: @"";
    if (idfa.length == 0) return @"null";
    NSString *lower = idfa.lowercaseString;
    if ([lower isEqualToString:@"00000000-0000-0000-0000-000000000000"]) return @"null";
    if ([lower hasPrefix:@"00000000"]) return @"null";
    return idfa;
}

+ (NSString *)deviceModelMachine {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding] ?: @"";
}

+ (NSString *)deviceMarketingModelName {
    NSString *machine = [self deviceModelMachine];
    if (machine.length == 0) return [UIDevice currentDevice].model ?: @"iPhone";
    // Simulator
    if ([machine isEqualToString:@"x86_64"] || [machine isEqualToString:@"i386"] || [machine isEqualToString:@"arm64"]) {
#if TARGET_OS_SIMULATOR
        return @"Simulator";
#endif
    }
    static NSDictionary<NSString *, NSString *> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            // iPhone 6 / 6s / SE1
            @"iPhone7,1": @"iPhone 6 Plus", @"iPhone7,2": @"iPhone 6",
            @"iPhone8,1": @"iPhone 6s", @"iPhone8,2": @"iPhone 6s Plus",
            @"iPhone8,4": @"iPhone SE (1st generation)",
            // iPhone 7 / 8 / X
            @"iPhone9,1": @"iPhone 7", @"iPhone9,3": @"iPhone 7",
            @"iPhone9,2": @"iPhone 7 Plus", @"iPhone9,4": @"iPhone 7 Plus",
            @"iPhone10,1": @"iPhone 8", @"iPhone10,4": @"iPhone 8",
            @"iPhone10,2": @"iPhone 8 Plus", @"iPhone10,5": @"iPhone 8 Plus",
            @"iPhone10,3": @"iPhone X", @"iPhone10,6": @"iPhone X",
            // XS / XR / 11 / SE2
            @"iPhone11,2": @"iPhone XS",
            @"iPhone11,4": @"iPhone XS Max", @"iPhone11,6": @"iPhone XS Max",
            @"iPhone11,8": @"iPhone XR",
            @"iPhone12,1": @"iPhone 11", @"iPhone12,3": @"iPhone 11 Pro", @"iPhone12,5": @"iPhone 11 Pro Max",
            @"iPhone12,8": @"iPhone SE (2nd generation)",
            // 12 / 13 / SE3
            @"iPhone13,1": @"iPhone 12 mini", @"iPhone13,2": @"iPhone 12",
            @"iPhone13,3": @"iPhone 12 Pro", @"iPhone13,4": @"iPhone 12 Pro Max",
            @"iPhone14,4": @"iPhone 13 mini", @"iPhone14,5": @"iPhone 13",
            @"iPhone14,2": @"iPhone 13 Pro", @"iPhone14,3": @"iPhone 13 Pro Max",
            @"iPhone14,6": @"iPhone SE (3rd generation)",
            @"iPhone14,7": @"iPhone 14", @"iPhone14,8": @"iPhone 14 Plus",
            // 14 Pro / 15 / 15 Pro
            @"iPhone15,2": @"iPhone 14 Pro", @"iPhone15,3": @"iPhone 14 Pro Max",
            @"iPhone15,4": @"iPhone 15", @"iPhone15,5": @"iPhone 15 Plus",
            @"iPhone16,1": @"iPhone 15 Pro", @"iPhone16,2": @"iPhone 15 Pro Max",
            // 16 / 16e
            @"iPhone17,1": @"iPhone 16 Pro", @"iPhone17,2": @"iPhone 16 Pro Max",
            @"iPhone17,3": @"iPhone 16", @"iPhone17,4": @"iPhone 16 Plus",
            @"iPhone17,5": @"iPhone 16e",
            // 17 / Air / 17e（2025–2026）
            @"iPhone18,1": @"iPhone 17 Pro", @"iPhone18,2": @"iPhone 17 Pro Max",
            @"iPhone18,3": @"iPhone 17", @"iPhone18,4": @"iPhone Air",
            @"iPhone18,5": @"iPhone 17e",
            @"iPhone19,2": @"iPhone 18 Pro",
            @"iPhone19,3": @"iPhone 18 Pro Max", @"iPhone19,7": @"iPhone 18 Pro Max",
            @"iPad13,1": @"iPad Air (4th generation)", @"iPad13,2": @"iPad Air (4th generation)",
            @"iPad13,16": @"iPad Air (5th generation)", @"iPad13,17": @"iPad Air (5th generation)",
            @"iPad14,1": @"iPad mini (6th generation)", @"iPad14,2": @"iPad mini (6th generation)",
            @"iPad14,8": @"iPad Air 11-inch (M2)", @"iPad14,9": @"iPad Air 11-inch (M2)",
            @"iPad14,10": @"iPad Air 13-inch (M2)", @"iPad14,11": @"iPad Air 13-inch (M2)",
            @"iPad16,3": @"iPad Pro 11-inch (M4)", @"iPad16,4": @"iPad Pro 11-inch (M4)",
            @"iPad16,5": @"iPad Pro 13-inch (M4)", @"iPad16,6": @"iPad Pro 13-inch (M4)",
        };
    });
    NSString *name = map[machine];
    if (name.length) return name;
    if ([machine hasPrefix:@"iPhone"]) return @"iPhone";
    if ([machine hasPrefix:@"iPad"]) return @"iPad";
    return machine;
}

#pragma mark - Memory / Disk

+ (NSString *)formatGBFromBytes:(unsigned long long)bytes {
    if (bytes == 0) return @"0";
    double gb = (double)bytes / (1024.0 * 1024.0 * 1024.0);
    if (gb <= 0) return @"0";
    NSString *s = [NSString stringWithFormat:@"%.6f", gb];
    while ([s hasSuffix:@"0"]) {
        s = [s substringToIndex:s.length - 1];
    }
    if ([s hasSuffix:@"."]) {
        s = [s substringToIndex:s.length - 1];
    }
    return s.length ? s : @"0";
}

+ (unsigned long long)freeMemoryBytes {
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_statistics64_data_t vmstat;
    kern_return_t kr = host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmstat, &count);
    if (kr != KERN_SUCCESS) return 0;
    return (unsigned long long)vmstat.free_count * (unsigned long long)vm_kernel_page_size;
}

+ (void)fileSystemSize:(unsigned long long *)outSize freeSize:(unsigned long long *)outFree {
    if (outSize) *outSize = 0;
    if (outFree) *outFree = 0;
    NSError *err = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&err];
    if (!attrs) return;
    if (outSize) *outSize = [attrs[NSFileSystemSize] unsignedLongLongValue];
    if (outFree) *outFree = [attrs[NSFileSystemFreeSize] unsignedLongLongValue];
}

#pragma mark - Risk

+ (BOOL)isJailbroken {
    NSArray *paths = @[
        @"/Applications/Cydia.app",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/bin/bash",
        @"/usr/sbin/sshd",
        @"/etc/apt",
        @"/private/var/lib/apt/",
    ];
    for (NSString *path in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return YES;
    }
    return NO;
}

+ (BOOL)isProxied {
    CFDictionaryRef proxies = CFNetworkCopySystemProxySettings();
    if (!proxies) return NO;
    NSDictionary *dict = CFBridgingRelease(proxies);
    id httpEnable = dict[(NSString *)kCFNetworkProxiesHTTPEnable];
    id httpsEnable = dict[@"HTTPSEnable"];
    id socksEnable = dict[@"SOCKSEnable"];
    id pacEnable = dict[(NSString *)kCFNetworkProxiesProxyAutoConfigEnable];
    BOOL on = ([httpEnable integerValue] == 1
               || [httpsEnable integerValue] == 1
               || [socksEnable integerValue] == 1
               || [pacEnable integerValue] == 1);
    NSString *host = dict[(NSString *)kCFNetworkProxiesHTTPProxy];
    if (host.length > 0 && [httpEnable integerValue] == 1) on = YES;
    return on;
}

+ (BOOL)hqit_isVPNInterfaceName:(NSString *)name {
    NSString *lower = name.lowercaseString ?: @"";
    return [lower containsString:@"tap"]
        || [lower containsString:@"tun"]
        || [lower containsString:@"ppp"]
        || [lower containsString:@"ipsec"];
}

+ (BOOL)isVPNConnected {
    // iOS always has idle utun* (IPv6 link-local) even when the user VPN is off.
    // Treat as VPN only when a tun/ppp/ipsec/tap interface is both:
    // 1) present in system proxy __SCOPED__ (active tunnel), and
    // 2) UP with an IPv4 address.
    CFDictionaryRef cfDict = CFNetworkCopySystemProxySettings();
    NSDictionary *dict = cfDict ? CFBridgingRelease(cfDict) : nil;
    NSDictionary *scoped = [dict[@"__SCOPED__"] isKindOfClass:[NSDictionary class]] ? dict[@"__SCOPED__"] : nil;
    BOOL scopedHit = NO;
    for (NSString *key in scoped) {
        if (![key isKindOfClass:[NSString class]]) continue;
        if ([self hqit_isVPNInterfaceName:key]) {
            scopedHit = YES;
            break;
        }
    }
    if (!scopedHit) {
        NSLog(@"[HQITDevice] isvpn=false (no active tun/ppp/ipsec in __SCOPED__)");
        return NO;
    }

    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) {
        NSLog(@"[HQITDevice] isvpn=false (getifaddrs failed)");
        return NO;
    }
    BOOL hasIPv4 = NO;
    NSString *hitName = nil;
    for (struct ifaddrs *addr = interfaces; addr != NULL; addr = addr->ifa_next) {
        if (!addr->ifa_name || !addr->ifa_addr) continue;
        if (!(addr->ifa_flags & IFF_UP)) continue;
        if (addr->ifa_addr->sa_family != AF_INET) continue;
        NSString *name = [NSString stringWithUTF8String:addr->ifa_name];
        if (![self hqit_isVPNInterfaceName:name]) continue;
        hasIPv4 = YES;
        hitName = name;
        break;
    }
    freeifaddrs(interfaces);
    NSLog(@"[HQITDevice] isvpn=%@ iface=%@", hasIPv4 ? @"true" : @"false", hitName ?: @"(none)");
    return hasIPv4;
}

#pragma mark - Network code

+ (NSString *)networkCodeString {
    AFNetworkReachabilityManager *mgr = [AFNetworkReachabilityManager sharedManager];
    if (!mgr.isReachable) {
        if (mgr.networkReachabilityStatus == AFNetworkReachabilityStatusUnknown) {
            [mgr startMonitoring];
        }
        if (!mgr.isReachable && mgr.networkReachabilityStatus != AFNetworkReachabilityStatusReachableViaWiFi
            && mgr.networkReachabilityStatus != AFNetworkReachabilityStatusReachableViaWWAN) {
            return @"0";
        }
    }
    if (mgr.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi
        || (mgr.isReachableViaWiFi)) {
        return @"1";
    }
    if (mgr.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN
        || mgr.isReachableViaWWAN) {
        return [self cellularGenerationCode];
    }
    return @"0";
}

+ (NSString *)cellularGenerationCode {
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    NSString *tech = nil;
    NSDictionary *map = info.serviceCurrentRadioAccessTechnology;
    if (map.count > 0) {
        tech = map.allValues.firstObject;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (tech.length == 0) tech = info.currentRadioAccessTechnology;
#pragma clang diagnostic pop
    if (tech.length == 0) return @"0";

    // 2G
    NSSet *g2 = [NSSet setWithArray:@[
        CTRadioAccessTechnologyGPRS,
        CTRadioAccessTechnologyEdge,
        CTRadioAccessTechnologyCDMA1x,
    ]];
    // 3G
    NSSet *g3 = [NSSet setWithArray:@[
        CTRadioAccessTechnologyWCDMA,
        CTRadioAccessTechnologyHSDPA,
        CTRadioAccessTechnologyHSUPA,
        CTRadioAccessTechnologyCDMAEVDORev0,
        CTRadioAccessTechnologyCDMAEVDORevA,
        CTRadioAccessTechnologyCDMAEVDORevB,
        CTRadioAccessTechnologyeHRPD,
    ]];
    // 4G
    NSSet *g4 = [NSSet setWithArray:@[ CTRadioAccessTechnologyLTE ]];
    if ([g2 containsObject:tech]) return @"2";
    if ([g3 containsObject:tech]) return @"3";
    if ([g4 containsObject:tech]) return @"4";
    if (@available(iOS 14.1, *)) {
        if ([tech isEqualToString:CTRadioAccessTechnologyNRNSA]
            || [tech isEqualToString:CTRadioAccessTechnologyNR]) {
            return @"5";
        }
    }
    return @"0";
}

#pragma mark - Wi‑Fi §3.5

+ (NSDictionary<NSString *, NSString *> *)emptyWiFiInfo {
    return @{
        @"wifiSsid": @"null",
        @"wifiName": @"null",
        @"wifiBssid": @"null",
        @"mac": @"null",
    };
}

+ (NSDictionary<NSString *, NSString *> *)wifiDictWithSSID:(NSString *)ssid bssid:(NSString *)bssid {
    if (ssid.length == 0) return [self emptyWiFiInfo];
    NSString *b = bssid.length > 0 ? bssid : @"null";
    return @{
        @"wifiSsid": ssid,
        @"wifiName": ssid,
        @"wifiBssid": b,
        @"mac": b,
    };
}

+ (NSDictionary<NSString *, NSString *> *)wifiInfo {
    NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
    BOOL ios26Plus = (ver.majorVersion >= 26);
    if (ios26Plus) {
        NSLog(@"[WiFi] sync path skip on iOS26+ (use collectDeviceInfoForOrder)");
        return [self emptyWiFiInfo];
    }
    return [self wifiInfoFromCaptiveNetwork] ?: [self emptyWiFiInfo];
}

+ (nullable NSDictionary<NSString *, NSString *> *)wifiInfoFromCaptiveNetwork {
    CFArrayRef interfaces = CNCopySupportedInterfaces();
    if (!interfaces) return nil;
    NSDictionary *out = nil;
    if (CFArrayGetCount(interfaces) > 0) {
        CFDictionaryRef networkInfo = CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(interfaces, 0));
        if (networkInfo) {
            NSDictionary *info = CFBridgingRelease(networkInfo);
            NSString *s = info[@"SSID"];
            NSString *b = info[@"BSSID"];
            if ([s isKindOfClass:[NSString class]] && s.length > 0) {
                NSString *bssid = ([b isKindOfClass:[NSString class]] && b.length > 0) ? b : nil;
                out = [self wifiDictWithSSID:s bssid:bssid];
            }
        }
    }
    CFRelease(interfaces);
    return out;
}

+ (void)fetchWiFiInfoAsync:(void (^)(NSDictionary<NSString *, NSString *> *wifi))completion {
    if (!completion) return;
    NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
    BOOL ios26Plus = (ver.majorVersion >= 26);
    BOOL locOK = [self hqit_hasLocationAuth];
    NSLog(@"[WiFi] async fetch iOS %ld.%ld locationOK=%d",
          (long)ver.majorVersion, (long)ver.minorVersion, locOK ? 1 : 0);

    void (^deliver)(NSDictionary *) = ^(NSDictionary *wifi) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(wifi ?: [self emptyWiFiInfo]);
        });
    };

    if (!locOK) {
        NSLog(@"[WiFi] no location auth → null");
        deliver([self emptyWiFiInfo]);
        return;
    }

    HQITWiFiLocationWarmer *warmer = [[HQITWiFiLocationWarmer alloc] init];
    static char kWiFiWarmerKey;
    objc_setAssociatedObject(self, &kWiFiWarmerKey, warmer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    __weak typeof(self) weakSelf = self;
    [warmer warmThen:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            deliver([HQITDeviceInfoCollector emptyWiFiInfo]);
            return;
        }
        [self hqit_fetchCurrentHotspotIOS26:ios26Plus completion:^(NSString *ssid, NSString *bssid) {
            objc_setAssociatedObject(self, &kWiFiWarmerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (ssid.length > 0) {
                NSLog(@"[WiFi] got SSID=%@", ssid);
                deliver([self wifiDictWithSSID:ssid bssid:bssid]);
                return;
            }
            if (!ios26Plus) {
                NSDictionary *cap = [self wifiInfoFromCaptiveNetwork];
                if (cap) {
                    NSLog(@"[WiFi] CNCopy fallback OK");
                    deliver(cap);
                    return;
                }
            } else {
                NSLog(@"[WiFi] iOS26+ NEHotspot empty, no CNCopy");
            }
            deliver([self emptyWiFiInfo]);
        }];
    }];
}

+ (void)hqit_fetchCurrentHotspotIOS26:(BOOL)ios26Plus
                           completion:(void (^)(NSString * _Nullable ssid, NSString * _Nullable bssid))completion {
    if (!completion) return;
    if (@available(iOS 14.0, *)) {
        __block BOOL done = NO;
        void (^finish)(NSString *, NSString *) = ^(NSString *s, NSString *b) {
            if (done) return;
            done = YES;
            completion(s, b);
        };
        [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
            NSString *s = currentNetwork.SSID;
            NSString *b = currentNetwork.BSSID;
            if (s.length > 0) {
                finish(s, b.length > 0 ? b : nil);
            } else {
                NSLog(@"[WiFi] NEHotspotNetwork empty network=%@", currentNetwork);
                finish(nil, nil);
            }
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (done) return;
            NSLog(@"[WiFi] NEHotspotNetwork timeout 2s");
            finish(nil, nil);
        });
        return;
    }
    (void)ios26Plus;
    completion(nil, nil);
}

#pragma mark - SIM

+ (void)fillTelephony:(NSMutableDictionary *)dict {
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    NSDictionary<NSString *, CTCarrier *> *carriers = info.serviceSubscriberCellularProviders;
    NSArray *keys = carriers.allKeys ?: @[];
    NSInteger simCount = 0;
    NSString *tel1 = @"--";
    NSString *tel2 = @"--";
    NSInteger slot = 0;
    for (NSInteger i = 0; i < (NSInteger)keys.count && i < 2; i++) {
        CTCarrier *c = carriers[keys[i]];
        slot += 1;
        NSString *name = [c.carrierName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length > 0
            && ![name isEqualToString:@"--"]
            && ![name isEqualToString:@"---"]
            && ![name isEqualToString:@"-"]) {
            simCount += 1;
            if (i == 0) tel1 = name;
            else tel2 = name;
        }
    }
    dict[@"simCount"] = [NSString stringWithFormat:@"%ld", (long)simCount];
    dict[@"slotCount"] = [NSString stringWithFormat:@"%ld", (long)MIN(slot, (NSInteger)2)];
    dict[@"telephony"] = tel1;
    dict[@"telephony2"] = tel2;
}

@end
