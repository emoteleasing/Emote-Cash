

#import "HQITBankAccountEditViewController.h"
#import "HQITBankAccountEditViewModel.h"
#import "HQITKYCIFSCViewController.h"
#import "HQITFontHelper.h"
#import "HQITCategoryText.h"
#import "HQITClickGuard.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import <Masonry/Masonry.h>

@interface HQITBankAccountEditViewController () <UITextFieldDelegate>
@property (nonatomic, strong) HQITBankAccountEditViewModel *viewModel;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIStackView *formStack;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UITextField *> *inputFields;
@end

@implementation HQITBankAccountEditViewController

- (instancetype)initWithAccount:(HQITBankAccountItem *)account {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _viewModel = [[HQITBankAccountEditViewModel alloc] initWithAccount:account];
        _inputFields = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildUI];
    [self bindVM];
    [self.viewModel loadInit];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [HQITClickGuard unlockControl:self.submitButton];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    if (w <= 0) return;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];
    [self.headerBg mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(h);
    }];
    UIImage *fitted = [HQITNavigationBarStyle loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    if (fitted) self.headerBg.image = fitted;
}

#pragma mark - Bind

- (void)bindVM {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf reloadForm];
        weakSelf.submitButton.enabled = !weakSelf.viewModel.isSubmitting;
        weakSelf.submitButton.alpha = weakSelf.viewModel.isSubmitting ? 0.5 : 1.0;
        if (!weakSelf.viewModel.isSubmitting) {
            [HQITClickGuard unlockControl:weakSelf.submitButton];
        }
    };
    self.viewModel.onCommitSuccess = ^{
        [weakSelf.navigationController popViewControllerAnimated:YES];
    };
    self.viewModel.onErrorMessage = ^(NSString *message) {
        [HQITHUDHelper showToast:message];
        [HQITClickGuard unlockControl:weakSelf.submitButton];
    };
}

#pragma mark - Colors

- (UIColor *)color102B4B {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)placeholderColor {
    return [UIColor colorWithRed:0xC0/255.0 green:0xC4/255.0 blue:0xCC/255.0 alpha:1];
}

- (UIColor *)fieldFillColor {
    return [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
}

#pragma mark - UI

- (void)buildUI {
    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];

    self.headerBg = [[UIImageView alloc] init];
    self.headerBg.image = [HQITNavigationBarStyle loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    self.headerBg.contentMode = UIViewContentModeScaleToFill;
    self.headerBg.clipsToBounds = YES;
    [self.view addSubview:self.headerBg];
    [self.headerBg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.height.mas_equalTo(h);
    }];

    self.navContent = [[UIView alloc] init];
    [self.view addSubview:self.navContent];
    [self.navContent mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.headerBg);
    }];

    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.backButton setImage:[[UIImage imageNamed:@"back_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                     forState:UIControlStateNormal];
    [self.backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];

    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = [HQITCategoryText textForKey:@"36" defaultText:@"Change bank account"];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.submitButton.clipsToBounds = YES;
    self.submitButton.layer.cornerRadius = 10;
    UIImage *btnBg = [UIImage imageNamed:@"button_bg"];
    if (btnBg) {
        CGFloat bw = MAX(btnBg.size.width, 1), bh = MAX(btnBg.size.height, 1);
        [self.submitButton setBackgroundImage:[btnBg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                     resizingMode:UIImageResizingModeStretch]
                                     forState:UIControlStateNormal];
    } else {
        self.submitButton.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    }
    [self.submitButton setTitle:[HQITCategoryText textForKey:@"m62" defaultText:@"Submit"]
                       forState:UIControlStateNormal];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.submitButton addTarget:self action:@selector(onSubmit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.submitButton];
    [self.submitButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16);
    }];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.submitButton.mas_top).offset(-12);
    }];

    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor whiteColor];
    self.cardView.layer.cornerRadius = 16;
    self.cardView.clipsToBounds = YES;
    [self.scrollView addSubview:self.cardView];
    [self.cardView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.scrollView).offset(8);
        make.left.equalTo(self.scrollView).offset(16);
        make.right.equalTo(self.scrollView).offset(-16);
        make.width.equalTo(self.scrollView).offset(-32);
        make.bottom.equalTo(self.scrollView).offset(-16);
    }];

    self.formStack = [[UIStackView alloc] init];
    self.formStack.axis = UILayoutConstraintAxisVertical;
    self.formStack.spacing = 16;
    [self.cardView addSubview:self.formStack];
    [self.formStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView).offset(20);
        make.left.equalTo(self.cardView).offset(16);
        make.right.equalTo(self.cardView).offset(-16);
        make.bottom.equalTo(self.cardView).offset(-20);
    }];
}

- (void)reloadForm {
    for (UIView *v in self.formStack.arrangedSubviews) {
        [self.formStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.inputFields removeAllObjects];

    NSInteger idx = 0;
    for (HQITKYCFormRow *row in self.viewModel.rows) {
        UIView *block = [self fieldBlockForRow:row index:idx];
        [self.formStack addArrangedSubview:block];
        idx++;
    }
}

- (NSString *)titleForRow:(HQITKYCFormRow *)row {
    NSString *name = row.itemName.length ? row.itemName : row.itemCode;
    if ([row.itemCode.lowercaseString isEqualToString:@"credit_card"]) {
        NSString *opt = [HQITCategoryText textForKey:@"m64" defaultText:@"(Optional)"];
        if (![name.lowercaseString containsString:@"optional"]) {
            return [NSString stringWithFormat:@"%@ %@", name, opt];
        }
    }
    return name;
}

- (NSString *)placeholderForRow:(HQITKYCFormRow *)row {
    if ([row.itemCode.lowercaseString isEqualToString:@"ifsc"] ||
        [row.itemCode.lowercaseString isEqualToString:@"bank_code"]) {
        return [HQITCategoryText textForKey:@"m63" defaultText:@"Please enter or choose"];
    }
    return [HQITCategoryText textForKey:@"m34" defaultText:@"Please enter"];
}

- (UIView *)fieldBlockForRow:(HQITKYCFormRow *)row index:(NSInteger)index {
    UIView *wrap = [[UIView alloc] init];

    UILabel *title = [[UILabel alloc] init];
    title.text = [self titleForRow:row];
    title.font = [HQITFontHelper boldFontOfSize:14];
    title.textColor = [self color102B4B];
    [wrap addSubview:title];
    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(wrap);
    }];

    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [self fieldFillColor];
    box.layer.cornerRadius = 10;
    box.clipsToBounds = YES;
    [wrap addSubview:box];
    [box mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(title.mas_bottom).offset(8);
        make.left.right.bottom.equalTo(wrap);
        make.height.mas_equalTo(44);
    }];

    BOOL isName = [self.viewModel isAccountNameRow:row];
    NSString *code = row.itemCode.lowercaseString;
    BOOL isIFSC = [code isEqualToString:@"ifsc"] || [code isEqualToString:@"bank_code"];

    UITextField *tf = [[UITextField alloc] init];
    tf.delegate = self;
    tf.tag = index;
    tf.font = [HQITFontHelper regularFontOfSize:13];
    tf.textColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:[self placeholderForRow:row]
                                                               attributes:@{NSForegroundColorAttributeName: [self placeholderColor]}];
    tf.text = row.displayValue ?: @"";
    tf.enabled = !isName;
    if (isName) {
        tf.textColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    }
    if ([code isEqualToString:@"account_no"] || [code isEqualToString:@"account_no_verify"] ||
        [code isEqualToString:@"credit_card"]) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
    } else if (isIFSC) {
        tf.keyboardType = UIKeyboardTypeASCIICapable;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }
    [tf addTarget:self action:@selector(onTextChanged:) forControlEvents:UIControlEventEditingChanged];
    self.inputFields[@(index)] = tf;
    [box addSubview:tf];

    if (isIFSC) {
        UIButton *findBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        findBtn.clipsToBounds = YES;
        findBtn.layer.cornerRadius = 8;
        UIImage *bg = [UIImage imageNamed:@"button_bg"];
        if (bg) {
            CGFloat bw = MAX(bg.size.width, 1), bh = MAX(bg.size.height, 1);
            [findBtn setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                           resizingMode:UIImageResizingModeStretch]
                               forState:UIControlStateNormal];
        } else {
            findBtn.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
        }
        [findBtn setTitle:[HQITCategoryText textForKey:@"m54" defaultText:@"Find IFSC"] forState:UIControlStateNormal];
        [findBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        findBtn.titleLabel.font = [HQITFontHelper boldFontOfSize:12];
        [findBtn addTarget:self action:@selector(onFindIFSC) forControlEvents:UIControlEventTouchUpInside];
        [box addSubview:findBtn];
        [findBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(box).offset(-6);
            make.centerY.equalTo(box);
            make.height.mas_equalTo(32);
            make.width.mas_equalTo(88);
        }];
        [tf mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(box).offset(14);
            make.right.equalTo(findBtn.mas_left).offset(-8);
            make.top.bottom.equalTo(box);
        }];
    } else {
        [tf mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(box).offset(14);
            make.right.equalTo(box).offset(-14);
            make.top.bottom.equalTo(box);
        }];
    }
    return wrap;
}

#pragma mark - Actions

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onSubmit {
    if (![HQITClickGuard tryLockControl:self.submitButton]) return;
    [self.view endEditing:YES];
    [self.viewModel commit];
}

- (void)onTextChanged:(UITextField *)tf {
    NSInteger idx = tf.tag;
    if (idx < 0 || idx >= (NSInteger)self.viewModel.rows.count) return;
    HQITKYCFormRow *row = self.viewModel.rows[idx];
    NSString *filtered = [self.viewModel filterInput:tf.text forRow:row];
    if (![filtered isEqualToString:tf.text ?: @""]) {
        tf.text = filtered;
    }
    [self.viewModel applyInputForRow:row text:filtered];
}

- (void)onFindIFSC {
    [self.view endEditing:YES];
    __weak typeof(self) weakSelf = self;
    HQITKYCIFSCViewController *vc = [[HQITKYCIFSCViewController alloc] initWithOnPicked:^(NSString *ifscCode) {
        [weakSelf.viewModel applyIFSCCode:ifscCode];
    }];
    [self.navigationController pushViewController:vc animated:YES];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    return YES;
}

@end
