

#import "HQITLoginViewController.h"
#import "HQITLoginViewModel.h"
#import "HQITAgreementWebViewController.h"
#import "HQITBaseNavigationController.h"
#import "HQITHUDHelper.h"
#import "HQITBuryRecorder.h"
#import "HQITFontHelper.h"
#import "HQITAppShell.h"
#import "HQITNetworkConstants.h"
#import "HQITIndianPhoneValidator.h"
#import <Masonry/Masonry.h>

static NSString * const kHQITPrivacyLink = @"hqit://privacy";
static NSString * const kHQITServiceLink = @"hqit://service";

@interface HQITLoginViewController () <UITextFieldDelegate, UITextViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) HQITLoginViewModel *viewModel;

@property (nonatomic, strong) UIImageView *bgImageView;
@property (nonatomic, strong) UIView *logoContainer;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UILabel *welcomeLabel;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *signInNowLabel;
@property (nonatomic, strong) UIView *mobileBox;
@property (nonatomic, strong) UIImageView *flagImageView;
@property (nonatomic, strong) UILabel *countryCodeLabel;
@property (nonatomic, strong) UIView *mobileDivider;
@property (nonatomic, strong) UITextField *mobileField;
@property (nonatomic, strong) UIView *otpRow;
@property (nonatomic, strong) UIView *otpBox;
@property (nonatomic, strong) UITextField *otpField;
@property (nonatomic, strong) UIButton *getOTPButton;
@property (nonatomic, strong) UIButton *agreeButton;
@property (nonatomic, strong) UITextView *agreeTextView;
@property (nonatomic, strong) UIButton *signInButton;
@property (nonatomic, copy) NSString *otpIdleTitle;
@end

@implementation HQITLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    self.navigationController.navigationBarHidden = YES;
    self.otpIdleTitle = @"Get OTP";

    self.viewModel = [[HQITLoginViewModel alloc] init];
    [self buildUI];
    [self bindViewModel];
    [self updateAgreeIcon];
    [self refreshGetOTPButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - Colors

- (UIColor *)color102B4B {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)color999999 {
    return [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1];
}

- (UIColor *)color666666 {
    return [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
}

- (UIColor *)colorC10A02 {
    return [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
}

- (UIColor *)borderColor {
    return [UIColor colorWithRed:0xE5/255.0 green:0xE5/255.0 blue:0xE5/255.0 alpha:1];
}

- (void)styleInputBox:(UIView *)box {
    box.backgroundColor = [UIColor whiteColor];
    box.layer.cornerRadius = 12;
    box.layer.borderWidth = 1.25;
    box.layer.borderColor = [self borderColor].CGColor;
    box.clipsToBounds = YES;
}

- (void)setBoldTitle:(NSString *)title onButton:(UIButton *)button fontSize:(CGFloat)fontSize {
    if (title.length == 0) title = @"";
    NSAttributedString *attr = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSFontAttributeName: [HQITFontHelper boldFontOfSize:fontSize],
        NSForegroundColorAttributeName: [UIColor whiteColor],
    }];
    [button setAttributedTitle:attr forState:UIControlStateNormal];
    [button setAttributedTitle:attr forState:UIControlStateDisabled];
    button.titleLabel.font = [HQITFontHelper boldFontOfSize:fontSize];
}

- (UIImage *)stretchableButtonImageNamed:(NSString *)name {
    UIImage *img = [UIImage imageNamed:name];
    if (!img) return nil;
    CGFloat w = MAX(img.size.width, 1);
    CGFloat h = MAX(img.size.height, 1);
    UIEdgeInsets insets = UIEdgeInsetsMake(h * 0.45, w * 0.45, h * 0.45, w * 0.45);
    return [img resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch];
}

#pragma mark - UI

- (void)buildUI {
    self.bgImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"in_bg"]];
    self.bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.bgImageView.clipsToBounds = YES;
    [self.view addSubview:self.bgImageView];
    [self.bgImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    // App icon: 97x97
    self.logoContainer = [[UIView alloc] init];
    self.logoContainer.backgroundColor = [UIColor clearColor];
    self.logoContainer.clipsToBounds = YES;
    [self.view addSubview:self.logoContainer];
    [self.logoContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(48);
        make.centerX.equalTo(self.view);
        make.width.height.mas_equalTo(97);
    }];

    self.logoImageView = [[UIImageView alloc] init];
    self.logoImageView.image = [UIImage imageNamed:@"one_logo"];
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.logoImageView.clipsToBounds = YES;
    [self.logoContainer addSubview:self.logoImageView];
    [self.logoImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.logoContainer);
    }];

    self.welcomeLabel = [[UILabel alloc] init];
    self.welcomeLabel.text = @"Welcome";
    self.welcomeLabel.textColor = [UIColor whiteColor];
    self.welcomeLabel.font = [HQITFontHelper boldFontOfSize:22];
    self.welcomeLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.welcomeLabel];
    [self.welcomeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.logoContainer.mas_bottom).offset(16);
        make.centerX.equalTo(self.view);
        make.bottom.lessThanOrEqualTo(self.view.mas_top).offset(338 - 8);
    }];

    // White card: 338 from screen top
    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor whiteColor];
    self.cardView.layer.cornerRadius = 24;
    self.cardView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.cardView.clipsToBounds = YES;
    [self.view addSubview:self.cardView];
    [self.cardView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.view);
        make.top.equalTo(self.view).offset(338);
    }];

    self.signInNowLabel = [[UILabel alloc] init];
    self.signInNowLabel.text = @"Sign In Now";
    self.signInNowLabel.textColor = [self color102B4B];
    self.signInNowLabel.font = [HQITFontHelper boldFontOfSize:22];
    [self.cardView addSubview:self.signInNowLabel];
    [self.signInNowLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView).offset(28);
        make.left.equalTo(self.cardView).offset(24);
        make.right.equalTo(self.cardView).offset(-24);
    }];

    self.mobileBox = [[UIView alloc] init];
    [self styleInputBox:self.mobileBox];
    [self.cardView addSubview:self.mobileBox];
    [self.mobileBox mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.signInNowLabel.mas_bottom).offset(24);
        make.left.equalTo(self.cardView).offset(20);
        make.right.equalTo(self.cardView).offset(-20);
        make.height.mas_equalTo(48);
    }];

    self.flagImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"in_icon"]];
    self.flagImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.flagImageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.flagImageView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.mobileBox addSubview:self.flagImageView];
    [self.flagImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.mobileBox).offset(10);
        make.centerY.equalTo(self.mobileBox);
        make.width.height.mas_equalTo(20);
    }];

    self.countryCodeLabel = [[UILabel alloc] init];
    self.countryCodeLabel.text = @"+91";
    self.countryCodeLabel.font = [HQITFontHelper boldFontOfSize:14];
    self.countryCodeLabel.textColor = [self color102B4B];
    [self.countryCodeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.countryCodeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.mobileBox addSubview:self.countryCodeLabel];
    [self.countryCodeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.flagImageView.mas_right).offset(6);
        make.centerY.equalTo(self.mobileBox);
    }];

    // Divider: 10pt from +91
    self.mobileDivider = [[UIView alloc] init];
    self.mobileDivider.backgroundColor = [self borderColor];
    [self.mobileBox addSubview:self.mobileDivider];
    [self.mobileDivider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.countryCodeLabel.mas_right).offset(10);
        make.centerY.equalTo(self.mobileBox);
        make.width.mas_equalTo(1);
        make.height.mas_equalTo(20);
    }];

    self.mobileField = [[UITextField alloc] init];
    UIFont *regular14 = [HQITFontHelper regularFontOfSize:14];
    self.mobileField.font = regular14;
    self.mobileField.textColor = [self color102B4B];
    self.mobileField.keyboardType = UIKeyboardTypeNumberPad;
    self.mobileField.delegate = self;
    self.mobileField.adjustsFontSizeToFitWidth = NO;
    self.mobileField.clearsOnBeginEditing = NO;
    self.mobileField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Kindly provide your mobile number"
                                                                             attributes:@{NSForegroundColorAttributeName: [self color999999],
                                                                                          NSFontAttributeName: regular14}];
    [self.mobileField setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.mobileField addTarget:self action:@selector(onMobileEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.mobileBox addSubview:self.mobileField];
    [self.mobileField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.mobileDivider.mas_right).offset(10);
        make.right.equalTo(self.mobileBox).offset(-10);
        make.top.bottom.equalTo(self.mobileBox);
    }];
    self.mobileBox.userInteractionEnabled = YES;
    UITapGestureRecognizer *mobileBoxTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMobileBoxTapped)];
    mobileBoxTap.cancelsTouchesInView = NO;
    mobileBoxTap.delegate = self;
    [self.mobileBox addGestureRecognizer:mobileBoxTap];

    self.otpRow = [[UIView alloc] init];
    [self.cardView addSubview:self.otpRow];
    [self.otpRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.mobileBox.mas_bottom).offset(16);
        make.left.equalTo(self.cardView).offset(20);
        make.right.equalTo(self.cardView).offset(-20);
        make.height.mas_equalTo(48);
    }];

    self.otpBox = [[UIView alloc] init];
    [self styleInputBox:self.otpBox];
    [self.otpRow addSubview:self.otpBox];

    self.getOTPButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *otpBg = [self stretchableButtonImageNamed:@"short_button_bg"] ?: [self stretchableButtonImageNamed:@"button_bg"];
    if (otpBg) {
        [self.getOTPButton setBackgroundImage:otpBg forState:UIControlStateNormal];
    } else {
        self.getOTPButton.backgroundColor = [self colorC10A02];
    }
    self.getOTPButton.layer.cornerRadius = 12;
    self.getOTPButton.clipsToBounds = YES;
    [self.getOTPButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self setBoldTitle:self.otpIdleTitle onButton:self.getOTPButton fontSize:14];
    [self.getOTPButton addTarget:self action:@selector(onGetOTPTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.otpRow addSubview:self.getOTPButton];

    // Narrower Get OTP to widen OTP input
    [self.getOTPButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.top.bottom.equalTo(self.otpRow);
        make.width.mas_equalTo(96);
    }];
    [self.otpBox mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(self.otpRow);
        make.right.equalTo(self.getOTPButton.mas_left).offset(-10);
    }];

    self.otpField = [[UITextField alloc] init];
    self.otpField.font = [HQITFontHelper regularFontOfSize:14];
    self.otpField.textColor = [self color102B4B];
    self.otpField.keyboardType = UIKeyboardTypeNumberPad;
    self.otpField.delegate = self;
    self.otpField.clearsOnBeginEditing = NO;
    self.otpField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter OTP"
                                                                          attributes:@{NSForegroundColorAttributeName: [self color999999],
                                                                                       NSFontAttributeName: [HQITFontHelper regularFontOfSize:14]}];
    [self.otpField addTarget:self action:@selector(onOTPEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.otpBox addSubview:self.otpField];
    [self.otpField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.otpBox).offset(14);
        make.right.equalTo(self.otpBox).offset(-14);
        make.top.bottom.equalTo(self.otpBox);
    }];
    self.otpBox.userInteractionEnabled = YES;
    UITapGestureRecognizer *otpBoxTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOTPBoxTapped)];
    otpBoxTap.cancelsTouchesInView = NO;
    otpBoxTap.delegate = self;
    [self.otpBox addGestureRecognizer:otpBoxTap];

    self.agreeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.agreeButton addTarget:self action:@selector(onAgreeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.agreeButton];
    [self.agreeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.otpRow.mas_bottom).offset(18);
        make.left.equalTo(self.cardView).offset(20);
        make.width.height.mas_equalTo(22);
    }];

    self.agreeTextView = [[UITextView alloc] init];
    self.agreeTextView.backgroundColor = [UIColor clearColor];
    self.agreeTextView.editable = NO;
    self.agreeTextView.scrollEnabled = NO;
    self.agreeTextView.textContainerInset = UIEdgeInsetsZero;
    self.agreeTextView.textContainer.lineFragmentPadding = 0;
    self.agreeTextView.delegate = self;
    self.agreeTextView.linkTextAttributes = @{
        NSForegroundColorAttributeName: [self colorC10A02],
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
    };
    self.agreeTextView.attributedText = [self agreementAttributedText];
    [self.cardView addSubview:self.agreeTextView];
    [self.agreeTextView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.agreeButton);
        make.left.equalTo(self.agreeButton.mas_right).offset(8);
        make.right.equalTo(self.cardView).offset(-20);
    }];

    self.signInButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *signBg = [self stretchableButtonImageNamed:@"button_bg"];
    if (signBg) {
        [self.signInButton setBackgroundImage:signBg forState:UIControlStateNormal];
    } else {
        self.signInButton.backgroundColor = [self colorC10A02];
    }
    // Sign in: height 44, corner 10
    self.signInButton.layer.cornerRadius = 10;
    self.signInButton.clipsToBounds = YES;
    [self.signInButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self setBoldTitle:@"Sign in" onButton:self.signInButton fontSize:16];
    [self.signInButton addTarget:self action:@selector(onSignInTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.signInButton];
    [self.signInButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.agreeTextView.mas_bottom).offset(28);
        make.left.equalTo(self.cardView).offset(20);
        make.right.equalTo(self.cardView).offset(-20);
        make.height.mas_equalTo(44);
        make.bottom.lessThanOrEqualTo(self.cardView.mas_safeAreaLayoutGuideBottom).offset(-24);
    }];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
}

- (NSAttributedString *)agreementAttributedText {
    NSString *full = @"I have read and accepted Privacy Policy and Service Agreement";
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:full attributes:@{
        NSFontAttributeName: [HQITFontHelper regularFontOfSize:12],
        NSForegroundColorAttributeName: [self color666666],
    }];
    NSRange privacy = [full rangeOfString:@"Privacy Policy"];
    NSRange service = [full rangeOfString:@"Service Agreement"];
    if (privacy.location != NSNotFound) {
        [attr addAttributes:@{
            NSLinkAttributeName: [NSURL URLWithString:kHQITPrivacyLink],
            NSForegroundColorAttributeName: [self colorC10A02],
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        } range:privacy];
    }
    if (service.location != NSNotFound) {
        [attr addAttributes:@{
            NSLinkAttributeName: [NSURL URLWithString:kHQITServiceLink],
            NSForegroundColorAttributeName: [self colorC10A02],
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        } range:service];
    }
    return attr;
}

- (void)updateAgreeIcon {
    NSString *name = self.viewModel.agreementAccepted ? @"read_icon" : @"and_icon";
    [self.agreeButton setImage:[UIImage imageNamed:name] forState:UIControlStateNormal];
}

- (void)refreshGetOTPButton {
    if (self.viewModel.isCountingDown && self.viewModel.countdownSeconds > 0) {
        [self setBoldTitle:[NSString stringWithFormat:@"%lds", (long)self.viewModel.countdownSeconds]
                  onButton:self.getOTPButton
                  fontSize:14];
        self.getOTPButton.enabled = NO;
        self.getOTPButton.alpha = 0.7;
        return;
    }
    if (self.viewModel.isSendingOTP) {
        [self setBoldTitle:self.otpIdleTitle onButton:self.getOTPButton fontSize:14];
        self.getOTPButton.enabled = NO;
        self.getOTPButton.alpha = 0.7;
        return;
    }
    [self setBoldTitle:self.otpIdleTitle onButton:self.getOTPButton fontSize:14];
    self.getOTPButton.enabled = YES;
    self.getOTPButton.alpha = 1.0;
}

#pragma mark - Bind

- (void)bindViewModel {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onToast = ^(NSString *message) {
        [HQITHUDHelper showToast:message];
    };
    self.viewModel.onCountdown = ^(NSInteger secondsLeft, BOOL finished) {
        __strong typeof(weakSelf) self = weakSelf;
        if (finished) {
            self.otpIdleTitle = @"Reacquire";
            [self refreshGetOTPButton];
            return;
        }
        [self setBoldTitle:[NSString stringWithFormat:@"%lds", (long)secondsLeft]
                  onButton:self.getOTPButton
                  fontSize:14];
        self.getOTPButton.enabled = NO;
        self.getOTPButton.alpha = 0.7;
    };
    self.viewModel.onOTPButtonStateChanged = ^{
        [weakSelf refreshGetOTPButton];
    };
    self.viewModel.onLoginSuccess = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self.onLoginSuccess) {
            self.onLoginSuccess();
        } else {
            [[HQITAppShell shared] completeLogin];
        }
    };
}

#pragma mark - Actions

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)onMobileBoxTapped {
    if (![self.mobileField isFirstResponder]) {
        [self.mobileField becomeFirstResponder];
    }
}

- (void)onOTPBoxTapped {
    if (![self.otpField isFirstResponder]) {
        [self.otpField becomeFirstResponder];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *v = touch.view;
    while (v) {
        if ([v isKindOfClass:[UITextField class]] || [v isKindOfClass:[UITextView class]]) return NO;
        v = v.superview;
    }
    if (gestureRecognizer.view == self.view) {
        v = touch.view;
        while (v) {
            if (v == self.mobileBox || v == self.otpBox) return NO;
            v = v.superview;
        }
    }
    return YES;
}

- (void)onAgreeTapped {
    self.viewModel.agreementAccepted = !self.viewModel.agreementAccepted;
    [self updateAgreeIcon];
}

- (void)onGetOTPTapped {
    [self dismissKeyboard];
    self.viewModel.mobileDigits = self.mobileField.text ?: @"";
    [self.viewModel requestOTP];
}

- (void)onSignInTapped {
    [self dismissKeyboard];
    self.viewModel.mobileDigits = self.mobileField.text ?: @"";
    self.viewModel.otpDigits = self.otpField.text ?: @"";
    [self.viewModel signIn];
}

- (void)openAgreementURL:(NSString *)urlString title:(NSString *)title eventCode:(NSInteger)eventCode {
    if (urlString.length == 0) {
        [HQITHUDHelper showToast:HQITSystemBusyMessage];
        return;
    }
    [HQITBuryRecorder recordEventCode:eventCode eventContent:nil remark1:nil remark2:nil remark3:nil];
    HQITAgreementWebViewController *web = [[HQITAgreementWebViewController alloc] initWithURLString:urlString title:title];
    if (self.navigationController) {
        self.navigationController.navigationBarHidden = NO;
        [self.navigationController pushViewController:web animated:YES];
        return;
    }
    HQITBaseNavigationController *wrap = [[HQITBaseNavigationController alloc] initWithRootViewController:web];
    wrap.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:wrap animated:YES completion:nil];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction {
    if ([URL.absoluteString isEqualToString:kHQITPrivacyLink]) {
        [self openAgreementURL:[self.viewModel privacyPolicyURLString] title:@"Privacy Policy" eventCode:2];
        return NO;
    }
    if ([URL.absoluteString isEqualToString:kHQITServiceLink]) {
        [self openAgreementURL:[self.viewModel serviceAgreementURLString] title:@"Service Agreement" eventCode:3];
        return NO;
    }
    return NO;
}

- (void)onMobileEditingChanged:(UITextField *)textField {
    self.viewModel.mobileDigits = textField.text ?: @"";
}

- (void)onOTPEditingChanged:(UITextField *)textField {
    self.viewModel.otpDigits = textField.text ?: @"";
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField != self.mobileField && textField != self.otpField) return YES;

    NSString *current = textField.text ?: @"";
    if (range.location > current.length) return NO;
    if (range.location + range.length > current.length) {
        range = NSMakeRange(range.location, current.length - range.location);
    }

    NSString *prefix = [current substringToIndex:range.location];
    NSString *suffix = [current substringFromIndex:range.location + range.length];
    NSString *prefixDigits = [HQITIndianPhoneValidator digitsOnly:prefix];
    NSString *insertDigits = [HQITIndianPhoneValidator digitsOnly:string ?: @""];
    NSString *suffixDigits = [HQITIndianPhoneValidator digitsOnly:suffix];
    NSString *combined = [NSString stringWithFormat:@"%@%@%@", prefixDigits, insertDigits, suffixDigits];

    NSString *filtered = (textField == self.mobileField)
        ? [self.viewModel filteredMobileInput:combined]
        : [self.viewModel filteredOTPInput:combined];

    NSString *proposed = [current stringByReplacingCharactersInRange:range withString:(string ?: @"")];
    if ([proposed isEqualToString:filtered]) {
        return YES;
    }

    NSInteger cursor = (NSInteger)prefixDigits.length + (NSInteger)insertDigits.length;
    if (cursor > (NSInteger)filtered.length) cursor = (NSInteger)filtered.length;
    if (cursor < 0) cursor = 0;

    textField.text = filtered;
    if (textField == self.mobileField) {
        self.viewModel.mobileDigits = filtered;
    } else {
        self.viewModel.otpDigits = filtered;
    }

    __weak UITextField *weakTF = textField;
    dispatch_async(dispatch_get_main_queue(), ^{
        UITextField *tf = weakTF;
        if (!tf) return;
        NSInteger len = (NSInteger)(tf.text.length);
        NSInteger offset = MIN(MAX(cursor, 0), len);
        UITextPosition *pos = [tf positionFromPosition:tf.beginningOfDocument offset:offset];
        if (pos) {
            tf.selectedTextRange = [tf textRangeFromPosition:pos toPosition:pos];
        }
    });
    return NO;
}

@end
