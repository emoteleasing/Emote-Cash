

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITLoginVoidBlock)(void);
typedef void (^HQITLoginStringBlock)(NSString *message);
typedef void (^HQITLoginCountdownBlock)(NSInteger secondsLeft, BOOL finished);

@interface HQITLoginViewModel : NSObject

@property (nonatomic, copy) NSString *mobileDigits;
@property (nonatomic, copy) NSString *otpDigits;
@property (nonatomic, assign) BOOL agreementAccepted;
@property (nonatomic, assign, readonly) BOOL isSendingOTP;
@property (nonatomic, assign, readonly) BOOL isSigningIn;
@property (nonatomic, assign, readonly) BOOL isCountingDown;
@property (nonatomic, assign, readonly) NSInteger countdownSeconds;

@property (nonatomic, copy, nullable) HQITLoginStringBlock onToast;
@property (nonatomic, copy, nullable) HQITLoginCountdownBlock onCountdown;
@property (nonatomic, copy, nullable) HQITLoginVoidBlock onLoginSuccess;
@property (nonatomic, copy, nullable) HQITLoginVoidBlock onOTPButtonStateChanged;

- (NSString *)filteredMobileInput:(NSString *)text;
- (NSString *)filteredOTPInput:(NSString *)text;

- (void)requestOTP;
- (void)signIn;
- (nullable NSString *)privacyPolicyURLString;
- (nullable NSString *)serviceAgreementURLString;

- (void)invalidateCountdown;

@end

NS_ASSUME_NONNULL_END
