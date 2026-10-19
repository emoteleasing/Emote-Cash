

#import "HQITEMIInputViewController.h"
#import "HQITEMIResultViewController.h"
#import "HQITEMICalculator.h"
#import "HQITEMIModels.h"
#import "HQITFontHelper.h"
#import "HQITHUDHelper.h"
#import "HQITClickGuard.h"
#import "HQITNavigationBarStyle.h"
#import <Masonry/Masonry.h>

@interface HQITEMIInputViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UITextField *amountField;
@property (nonatomic, strong) UITextField *durationField;
@property (nonatomic, strong) UITextField *rateField;
@property (nonatomic, strong) UIButton *submitButton;
@end

@implementation HQITEMIInputViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = NO;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildUI];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(endEditing)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [HQITClickGuard unlockControl:self.submitButton];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateHeaderLayout];
}

- (void)endEditing {
    [self.view endEditing:YES];
}

- (void)updateHeaderLayout {
    CGFloat w = self.view.bounds.size.width;
    if (w <= 0) return;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];
    [self.headerBg mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(h);
    }];
    UIImage *fitted = [HQITNavigationBarStyle loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    if (fitted) {
        self.headerBg.image = fitted;
    }
}

#pragma mark - Colors

- (UIColor *)navy {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)grey {
    return [UIColor colorWithRed:0x8A/255.0 green:0x8F/255.0 blue:0x98/255.0 alpha:1];
}

- (UIColor *)border {
    return [UIColor colorWithRed:0xE8/255.0 green:0xEA/255.0 blue:0xEE/255.0 alpha:1];
}

- (UIColor *)placeholder {
    return [UIColor colorWithRed:0xB0/255.0 green:0xB5/255.0 blue:0xBE/255.0 alpha:1];
}

#pragma mark - UI

- (void)buildUI {
    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];

    self.headerBg = [[UIImageView alloc] init];
    self.headerBg.image = [HQITNavigationBarStyle loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    self.headerBg.contentMode = UIViewContentModeScaleToFill;
    self.headerBg.clipsToBounds = YES;
    self.headerBg.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.headerBg];
    [self.headerBg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.height.mas_equalTo(h);
    }];

    self.navContent = [[UIView alloc] init];
    self.navContent.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.navContent];
    [self.navContent mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.headerBg);
    }];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"EMI Calculator";
    self.titleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.navContent addSubview:self.titleLabel];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.navContent);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-10);
        make.left.greaterThanOrEqualTo(self.navContent).offset(16);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
    }];

    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];

    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor whiteColor];
    self.cardView.layer.cornerRadius = 16;
    self.cardView.clipsToBounds = YES;
    [self.contentView addSubview:self.cardView];
    [self.cardView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
    }];

    UITextField *amountTF = nil;
    UITextField *durationTF = nil;
    UITextField *rateTF = nil;
    UIView *amountRow = [self buildFieldRowTitle:@"Total Loan Amount"
                                          suffix:@"₹"
                                        rangeText:[NSString stringWithFormat:@"Range: 0 ~ %@",
                                                   [HQITEMICalculator formatIntegerIndian:[HQITEMICalculator maxAmount]]]
                                            field:&amountTF];
    UIView *durationRow = [self buildFieldRowTitle:@"Duration"
                                            suffix:@"year"
                                          rangeText:[NSString stringWithFormat:@"Range: 0 ~ %ld",
                                                     (long)[HQITEMICalculator maxDuration]]
                                             field:&durationTF];
    UIView *rateRow = [self buildFieldRowTitle:@"Interest Rate"
                                        suffix:@"%"
                                      rangeText:[NSString stringWithFormat:@"Range: 0 ~ %ld",
                                                 (long)[HQITEMICalculator maxInterestRate]]
                                         field:&rateTF];
    self.amountField = amountTF;
    self.durationField = durationTF;
    self.rateField = rateTF;
    self.amountField.text = [NSString stringWithFormat:@"%ld", (long)[HQITEMICalculator defaultAmount]];
    self.durationField.text = [NSString stringWithFormat:@"%ld", (long)[HQITEMICalculator defaultDuration]];
    self.rateField.text = [NSString stringWithFormat:@"%ld", (long)[HQITEMICalculator defaultInterestRate]];

    [self.cardView addSubview:amountRow];
    [self.cardView addSubview:durationRow];
    [self.cardView addSubview:rateRow];

    [amountRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView).offset(20);
        make.left.equalTo(self.cardView).offset(16);
        make.right.equalTo(self.cardView).offset(-16);
    }];
    [durationRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(amountRow.mas_bottom).offset(16);
        make.left.right.equalTo(amountRow);
    }];
    [rateRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(durationRow.mas_bottom).offset(16);
        make.left.right.equalTo(amountRow);
        make.bottom.equalTo(self.cardView).offset(-20);
    }];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self stylePrimaryButton:self.submitButton title:@"Submit"];
    [self.submitButton addTarget:self action:@selector(onSubmit) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.submitButton];
    [self.submitButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView.mas_bottom).offset(24);
        make.left.equalTo(self.contentView).offset(40);
        make.right.equalTo(self.contentView).offset(-40);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.contentView).offset(-24);
    }];
}

- (UIView *)buildFieldRowTitle:(NSString *)title
                        suffix:(NSString *)suffix
                      rangeText:(NSString *)rangeText
                         field:(UITextField * __strong *)outField {
    UIView *wrap = [[UIView alloc] init];

    UILabel *lab = [[UILabel alloc] init];
    lab.text = title;
    lab.font = [HQITFontHelper boldFontOfSize:14];
    lab.textColor = [self navy];
    [wrap addSubview:lab];
    [lab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(wrap);
    }];

    UIView *box = [[UIView alloc] init];
    box.layer.cornerRadius = 10;
    box.layer.borderWidth = 1;
    box.layer.borderColor = [self border].CGColor;
    box.backgroundColor = [UIColor whiteColor];
    [wrap addSubview:box];
    [box mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(lab.mas_bottom).offset(8);
        make.left.right.equalTo(wrap);
        make.height.mas_equalTo(44);
    }];

    UILabel *suf = [[UILabel alloc] init];
    suf.text = suffix;
    suf.font = [HQITFontHelper regularFontOfSize:14];
    suf.textColor = [self grey];
    suf.textAlignment = NSTextAlignmentRight;
    [box addSubview:suf];
    [suf mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(box).offset(-12);
        make.centerY.equalTo(box);
        make.width.mas_greaterThanOrEqualTo(18);
    }];

    UITextField *tf = [[UITextField alloc] init];
    tf.font = [HQITFontHelper regularFontOfSize:15];
    tf.textColor = [self navy];
    tf.keyboardType = UIKeyboardTypeNumberPad;
    tf.delegate = self;
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Please enter"
                                                                attributes:@{
        NSForegroundColorAttributeName: [self placeholder],
        NSFontAttributeName: [HQITFontHelper regularFontOfSize:15],
    }];
    [box addSubview:tf];
    [tf mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(12);
        make.right.equalTo(suf.mas_left).offset(-8);
        make.top.bottom.equalTo(box);
    }];
    *outField = tf;

    UILabel *range = [[UILabel alloc] init];
    range.text = rangeText;
    range.font = [HQITFontHelper regularFontOfSize:12];
    range.textColor = [self grey];
    [wrap addSubview:range];
    [range mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(box.mas_bottom).offset(6);
        make.left.right.bottom.equalTo(wrap);
    }];
    return wrap;
}

- (void)stylePrimaryButton:(UIButton *)btn title:(NSString *)title {
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat iw = MAX(bg.size.width, 1);
        CGFloat ih = MAX(bg.size.height, 1);
        UIEdgeInsets insets = UIEdgeInsetsMake(ih * 0.45, iw * 0.45, ih * 0.45, iw * 0.45);
        [btn setBackgroundImage:[bg resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch]
                       forState:UIControlStateNormal];
    } else {
        btn.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
        btn.layer.cornerRadius = 22;
        btn.clipsToBounds = YES;
    }
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
}

#pragma mark - Actions

- (void)onSubmit {
    if (![HQITClickGuard tryLockControl:self.submitButton]) return;
    [self.view endEditing:YES];

    NSString *a = [self.amountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *d = [self.durationField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *r = [self.rateField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (a.length == 0 || d.length == 0 || r.length == 0) {
        [HQITHUDHelper showToast:@"Please enter"];
        [HQITClickGuard unlockControl:self.submitButton];
        return;
    }

    HQITEMIInputModel *input = [[HQITEMIInputModel alloc] init];
    input.amount = a.integerValue;
    input.durationYears = d.integerValue;
    input.interestRate = r.integerValue;

    NSString *err = [HQITEMICalculator validateInput:input];
    if (err.length > 0) {
        [HQITHUDHelper showToast:err];
        [HQITClickGuard unlockControl:self.submitButton];
        return;
    }

    HQITEMIResultModel *result = [HQITEMICalculator calculateWithInput:input];
    HQITEMIResultViewController *vc = [[HQITEMIResultViewController alloc] initWithInput:input result:result];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.text.length == 0) return;
    NSInteger v = textField.text.integerValue;
    if (textField == self.amountField) {
        v = MAX(0, MIN(v, [HQITEMICalculator maxAmount]));
        textField.text = [NSString stringWithFormat:@"%ld", (long)v];
    } else if (textField == self.durationField) {
        v = MAX(0, MIN(v, [HQITEMICalculator maxDuration]));
        textField.text = [NSString stringWithFormat:@"%ld", (long)v];
    } else if (textField == self.rateField) {
        v = MAX(0, MIN(v, [HQITEMICalculator maxInterestRate]));
        textField.text = [NSString stringWithFormat:@"%ld", (long)v];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (string.length == 0) return YES;
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [string rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

@end
