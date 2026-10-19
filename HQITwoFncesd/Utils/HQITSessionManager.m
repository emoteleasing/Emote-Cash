

#import "HQITSessionManager.h"
#import "HQITStorageKeys.h"
#import <UIKit/UIKit.h>
#import <Security/Security.h>

static NSString * const kHQITDeviceIdKeychainService = @"com.hqitwofncesd.name_password";
static NSString * const kHQITDeviceIdKeychainAccount = @"com.hqitwofncesd.name_password";

@implementation HQITSessionManager

+ (instancetype)shared {
    static HQITSessionManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HQITSessionManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userId = [[NSUserDefaults standardUserDefaults] stringForKey:HQITStorageKeyUserId];
        _token = [[NSUserDefaults standardUserDefaults] stringForKey:HQITStorageKeyToken];
        _isRegister = [[NSUserDefaults standardUserDefaults] boolForKey:HQITStorageKeyIsRegister];
    }
    return self;
}

#pragma mark - deviceId

- (NSString *)deviceId {
    NSString *fromKC = [self hqit_keychainReadDeviceId];
    if (fromKC.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:fromKC forKey:HQITStorageKeyDeviceId];
        return fromKC;
    }
    NSString *fromUD = [[NSUserDefaults standardUserDefaults] stringForKey:HQITStorageKeyDeviceId];
    if (fromUD.length > 0) {
        [self hqit_keychainWriteDeviceId:fromUD];
        return fromUD;
    }
    NSString *idfv = [UIDevice currentDevice].identifierForVendor.UUIDString;
    NSString *created = idfv.length > 0 ? idfv : [[NSUUID UUID] UUIDString];
    [self hqit_keychainWriteDeviceId:created];
    [[NSUserDefaults standardUserDefaults] setObject:created forKey:HQITStorageKeyDeviceId];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return created;
}

- (nullable NSString *)hqit_keychainReadDeviceId {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kHQITDeviceIdKeychainService,
        (__bridge id)kSecAttrAccount: kHQITDeviceIdKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef result = NULL;
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (st != errSecSuccess || !result) return nil;
    NSData *data = CFBridgingRelease(result);
    if (@available(iOS 11.0, *)) {
        NSError *err = nil;
        id obj = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class] fromData:data error:&err];
        if ([obj isKindOfClass:[NSString class]] && [(NSString *)obj length] > 0) {
            return (NSString *)obj;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    @try {
        id obj = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if ([obj isKindOfClass:[NSString class]] && [(NSString *)obj length] > 0) {
            return (NSString *)obj;
        }
    } @catch (__unused NSException *ex) {}
#pragma clang diagnostic pop
    NSString *plain = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return plain.length > 0 ? plain : nil;
}

- (void)hqit_keychainWriteDeviceId:(NSString *)deviceId {
    if (deviceId.length == 0) return;
    NSData *data = nil;
    if (@available(iOS 11.0, *)) {
        NSError *err = nil;
        data = [NSKeyedArchiver archivedDataWithRootObject:deviceId
                                     requiringSecureCoding:NO
                                                     error:&err];
    }
    if (!data) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        data = [NSKeyedArchiver archivedDataWithRootObject:deviceId];
#pragma clang diagnostic pop
    }
    if (!data) {
        data = [deviceId dataUsingEncoding:NSUTF8StringEncoding];
    }
    NSDictionary *del = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kHQITDeviceIdKeychainService,
        (__bridge id)kSecAttrAccount: kHQITDeviceIdKeychainAccount,
    };
    SecItemDelete((__bridge CFDictionaryRef)del);
    NSDictionary *add = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kHQITDeviceIdKeychainService,
        (__bridge id)kSecAttrAccount: kHQITDeviceIdKeychainAccount,
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
    };
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);
}

#pragma mark - Session

- (BOOL)isLoggedIn {
    return self.userId.length > 0 && self.token.length > 0;
}

- (void)saveUserId:(NSString *)userId token:(NSString *)token {
    [self saveUserId:userId token:token isRegister:self.isRegister];
}

- (void)saveUserId:(NSString *)userId token:(NSString *)token isRegister:(BOOL)isRegister {
    self.userId = userId;
    self.token = token;
    self.isRegister = isRegister;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (userId.length > 0) {
        [ud setObject:userId forKey:HQITStorageKeyUserId];
    } else {
        [ud removeObjectForKey:HQITStorageKeyUserId];
    }
    if (token.length > 0) {
        [ud setObject:token forKey:HQITStorageKeyToken];
    } else {
        [ud removeObjectForKey:HQITStorageKeyToken];
    }
    [ud setBool:isRegister forKey:HQITStorageKeyIsRegister];
    [ud synchronize];
}

- (void)clearSession {
    self.isRegister = NO;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:HQITStorageKeyIsRegister];
    [self saveUserId:nil token:nil isRegister:NO];
}

@end
