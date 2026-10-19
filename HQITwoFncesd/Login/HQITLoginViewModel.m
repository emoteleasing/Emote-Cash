

#import "HQITLoginViewModel.h"
#import "HQITIndianPhoneValidator.h"
#import "HQITNetworkClient.h"
#import "HQITSessionManager.h"
#import "HQITDeviceInfoCollector.h"
#import "HQITAppStartupManager.h"
#import "HQITAppConfigHelper.h"
#import "HQITBuryRecorder.h"
#import "HQITHUDHelper.h"
#import "HQITStorageKeys.h"

static NSInteger const kHQITOTPCountdownSeconds = 60;

@interface HQITLoginViewModel ()
@property (nonatomic, assign, readwrite) BOOL isSendingOTP;
@property (nonatomic, assign, readwrite) BOOL isSigningIn;
@property (nonatomic, assign, readwrite) BOOL isCountingDown;
@property (nonatomic, assign, readwrite) NSInteger countdownSeconds;
@property (nonatomic, strong, nullable) NSTimer *countdownTimer;
@end

@implementation HQITLoginViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _mobileDigits = @"";
        _otpDigits = @"";
        _agreementAccepted = YES;
        _countdownSeconds = 0;
    }
    return self;
}

- (void)dealloc {
    [self invalidateCountdown];
}

- (NSString *)filteredMobileInput:(NSString *)text {
    NSString *digits = [HQITIndianPhoneValidator digitsOnly:text];
    NSInteger maxLen = [HQITIndianPhoneValidator maxLengthForDigits:digits];
    if ((NSInteger)digits.length > maxLen) {
        digits = [digits substringToIndex:(NSUInteger)maxLen];
    }
    return digits;
}

- (NSString *)filteredOTPInput:(NSString *)text {
    NSString *digits = [HQITIndianPhoneValidator digitsOnly:text];
    if (digits.length > 6) {
        digits = [digits substringToIndex:6];
    }
    return digits;
}

- (void)toast:(NSString *)message {
    if (self.onToast) {
        self.onToast(message ?: @"");
    } else {
        [HQITHUDHelper showToast:message];
    }
}

- (nullable NSString *)stringFromData:(id)data key:(NSString *)key {
    if (![data isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *dict = (NSDictionary *)data;
    id v = dict[key];
    if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) return v;
    if ([v respondsToSelector:@selector(stringValue)]) {
        NSString *s = [v stringValue];
        if (s.length > 0) return s;
    }
    return nil;
}

- (BOOL)boolFromData:(id)data key:(NSString *)key {
    if (![data isKindOfClass:[NSDictionary class]]) return NO;
    id v = ((NSDictionary *)data)[key];
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v boolValue];
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)v lowercaseString];
        return [s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"];
    }
    return NO;
}

- (nullable NSString *)privacyPolicyURLString {
    return [HQITAppConfigHelper stringForHrefConfigKey:@"policyHref"];
}

- (nullable NSString *)serviceAgreementURLString {
    return [HQITAppConfigHelper stringForHrefConfigKey:@"agreementHref"];
}

#pragma mark - OTP

- (void)requestOTP {
    if (self.isSendingOTP || self.isCountingDown) {
        [self toast:@"Wait, OTP sending"];
        return;
    }

    NSString *msg = [HQITIndianPhoneValidator validationMessageForInput:self.mobileDigits allowEmpty:NO];
    if (msg.length > 0) {
        [self toast:msg];
        return;
    }

    NSString *mobile = [HQITIndianPhoneValidator normalizedIndianMobileFrom:self.mobileDigits];
    if (mobile.length == 0) {
        [self toast:HQITPhoneErrorInvalid];
        return;
    }

    [HQITBuryRecorder recordEventCode:4 eventContent:nil remark1:nil remark2:nil remark3:nil];
    self.isSendingOTP = YES;
    if (self.onOTPButtonStateChanged) self.onOTPButtonStateChanged();
    [HQITHUDHelper showLoadingWithMessage:@"Sending OTP..."];

    NSDictionary *signedData = @{
        @"mobile": mobile,
        @"verifyType": @"1",
    };

    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/sms/sendVerifySms"
                                         signedData:signedData
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        [HQITHUDHelper hideLoading];
        self.isSendingOTP = NO;
        [self startCountdown];
        [self toast:@"OTP sent"];
        if (self.onOTPButtonStateChanged) self.onOTPButtonStateChanged();
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        [HQITHUDHelper hideLoading];
        self.isSendingOTP = NO;
        // Network layer already toasted resultMsg when showErrorToast=YES; only fallback when empty.
        if (message.length == 0) {
            [self toast:@"OTP send failed"];
        }
        if (self.onOTPButtonStateChanged) self.onOTPButtonStateChanged();
    }];
}

- (void)startCountdown {
    [self invalidateCountdown];
    self.isCountingDown = YES;
    self.countdownSeconds = kHQITOTPCountdownSeconds;
    if (self.onCountdown) self.onCountdown(self.countdownSeconds, NO);
    if (self.onOTPButtonStateChanged) self.onOTPButtonStateChanged();

    __weak typeof(self) weakSelf = self;
    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            [timer invalidate];
            return;
        }
        self.countdownSeconds -= 1;
        if (self.countdownSeconds <= 0) {
            [self invalidateCountdown];
            if (self.onCountdown) self.onCountdown(0, YES);
            if (self.onOTPButtonStateChanged) self.onOTPButtonStateChanged();
            return;
        }
        if (self.onCountdown) self.onCountdown(self.countdownSeconds, NO);
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.countdownTimer forMode:NSRunLoopCommonModes];
}

- (void)invalidateCountdown {
    [self.countdownTimer invalidate];
    self.countdownTimer = nil;
    self.isCountingDown = NO;
    self.countdownSeconds = 0;
}

#pragma mark - Sign in

- (void)signIn {
    if (self.isSigningIn) {
        [self toast:@"Login is under way, kindly wait"];
        return;
    }

    NSString *phoneMsg = [HQITIndianPhoneValidator validationMessageForInput:self.mobileDigits allowEmpty:NO];
    if (phoneMsg.length > 0) {
        [self toast:phoneMsg];
        return;
    }
    NSString *mobile = [HQITIndianPhoneValidator normalizedIndianMobileFrom:self.mobileDigits];
    if (mobile.length == 0) {
        [self toast:HQITPhoneErrorInvalid];
        return;
    }

    NSString *otp = [HQITIndianPhoneValidator digitsOnly:self.otpDigits];
    if (otp.length != 6) {
        [self toast:@"Kindly provide a valid OTP"];
        return;
    }

    if (!self.agreementAccepted) {
        [self toast:@"Kindly review and agree first"];
        return;
    }

    [HQITBuryRecorder recordEventCode:5 eventContent:nil remark1:nil remark2:nil remark3:nil];
    self.isSigningIn = YES;
    [HQITHUDHelper showLoadingWithMessage:@"Signing in..."];

    NSString *deviceId = [HQITSessionManager shared].deviceId ?: @"";
    NSDictionary *signedData = @{
        @"mobile": mobile,
        @"verifyCode": otp,
        @"longitude": @"-360",
        @"latitude": @"-360",
        @"imei": @"null",
        @"serialNo": deviceId,
    };

    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/auth/registerOrLogin"
                                         signedData:signedData
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        [HQITHUDHelper hideLoading];
        if (!self) return;
        self.isSigningIn = NO;
        NSString *userId = [self stringFromData:response.data key:@"userId"];
        NSString *token = [self stringFromData:response.data key:@"token"];
        if (userId.length == 0 || token.length == 0) {
            [self toast:@"Login data save failed"];
            return;
        }
        BOOL isRegister = [self boolFromData:response.data key:@"isRegister"];
        [[HQITSessionManager shared] saveUserId:userId token:token isRegister:isRegister];
        // Cache login mobile so Me page can show it before /user/info returns.
        if (mobile.length) {
            [[NSUserDefaults standardUserDefaults] setObject:mobile forKey:HQITStorageKeyUserMobile];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        [self uploadRegisterDevice];
        if (self.onLoginSuccess) {
            self.onLoginSuccess();
        }
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self) self.isSigningIn = NO;
        [HQITHUDHelper hideLoading];
        NSString *msg = message.length > 0 ? message : @"Login failed, please try again";
        [HQITHUDHelper showToast:msg];
    }];
}

- (void)uploadRegisterDevice {
    NSDictionary *info = [HQITDeviceInfoCollector collectDeviceInfoWithOrderId:nil includeWiFiDetails:NO];
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/mobile/registerDevice"
                                         signedData:nil
                                       unsignedData:info
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        NSLog(@"[HQITLogin] registerDevice ok");
    } failure:^(NSError *error, NSString *message) {
        NSLog(@"[HQITLogin] registerDevice fail: %@", message);
    }];
}

@end
