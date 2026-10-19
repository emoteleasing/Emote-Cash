

#import "HQITKYCFormViewController.h"
#import "HQITKYCFormViewModel.h"
#import "HQITKYCNavigation.h"
#import "HQITFontHelper.h"
#import "HQITDialogs.h"
#import "HQITCategoryText.h"
#import "HQITClickGuard.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import <Masonry/Masonry.h>

@interface HQITKYCFormViewController () <UITextFieldDelegate>
@property (nonatomic, copy) NSString *kycId;
@property (nonatomic, copy) NSString *pageTitleText;
@property (nonatomic, assign) BOOL isLastUnfinished;
@property (nonatomic, strong) HQITKYCFormViewModel *viewModel;

@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIStackView *formStack;
@property (nonatomic, strong) UIButton *continueButton;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UITextField *> *inputFields;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UILabel *> *valueLabels;
@end

@implementation HQITKYCFormViewController

- (instancetype)initWithKycId:(NSString *)kycId
                    pageTitle:(NSString *)pageTitle
             isLastUnfinished:(BOOL)isLastUnfinished {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _kycId = [kycId copy] ?: @"";
        _pageTitleText = [pageTitle copy] ?: @"KYC";
        _isLastUnfinished = isLastUnfinished;
        _viewModel = [[HQITKYCFormViewModel alloc] initWithKycId:_kycId];
        _inputFields = [NSMutableDictionary dictionary];
        _valueLabels = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    [self buildUI];
    [self bindVM];
    [self.viewModel loadInit];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [HQITClickGuard unlockControl:self.continueButton];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateHeaderLayout];
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

- (void)hqit_setupBackButtonIfNeeded {
    // Custom header back; hide system bar button
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:[[UIView alloc] init]];
    self.navigationItem.hidesBackButton = YES;
}

- (BOOL)hqit_shouldPopBack {
    // Block system / gesture pop; exit only via Confirm dialog from back button.
    return NO;
}

#pragma mark - Bind

- (void)bindVM {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf reloadForm];
        weakSelf.continueButton.enabled = !weakSelf.viewModel.isSubmitting;
        weakSelf.continueButton.alpha = weakSelf.viewModel.isSubmitting ? 0.5 : 1.0;
    };
    self.viewModel.onCommitSuccess = ^{
        [HQITKYCNavigation advanceFrom:weakSelf];
    };
    self.viewModel.onErrorMessage = ^(NSString *message) {
        [HQITHUDHelper showToast:message];
    };
}

#pragma mark - UI

- (UIColor *)color102B4B {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)placeholderColor {
    return [UIColor colorWithRed:0xC0/255.0 green:0xC4/255.0 blue:0xCC/255.0 alpha:1];
}

- (UIColor *)borderColor {
    return [UIColor colorWithRed:0xE6/255.0 green:0xE8/255.0 blue:0xEC/255.0 alpha:1];
}

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

    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *backImg = [[UIImage imageNamed:@"back_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (backImg) {
        [self.backButton setImage:backImg forState:UIControlStateNormal];
    }
    [self.backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];

    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = self.pageTitleText;
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textAlignment = NSTextAlignmentLeft;
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    // Continue button pinned bottom
    self.continueButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *btnBg = [UIImage imageNamed:@"button_bg"];
    if (btnBg) {
        CGFloat w = MAX(btnBg.size.width, 1);
        CGFloat h = MAX(btnBg.size.height, 1);
        UIEdgeInsets insets = UIEdgeInsetsMake(h * 0.45, w * 0.45, h * 0.45, w * 0.45);
        [self.continueButton setBackgroundImage:[btnBg resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch]
                                       forState:UIControlStateNormal];
    } else {
        self.continueButton.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
        self.continueButton.layer.cornerRadius = 22;
        self.continueButton.clipsToBounds = YES;
    }
    NSString *btnTitle = self.isLastUnfinished ? @"Apply Now" : @"Continue";
    [self.continueButton setAttributedTitle:[[NSAttributedString alloc] initWithString:btnTitle attributes:@{
        NSFontAttributeName: [HQITFontHelper boldFontOfSize:15],
        NSForegroundColorAttributeName: [UIColor whiteColor],
    }] forState:UIControlStateNormal];
    [self.continueButton addTarget:self action:@selector(onContinue) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.continueButton];
    [self.continueButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16);
    }];

    // Scroll + white card overlapping header
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.continueButton.mas_top).offset(-12);
    }];

    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor whiteColor];
    self.cardView.layer.cornerRadius = 24;
    self.cardView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
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
    self.formStack.spacing = 20;
    [self.cardView addSubview:self.formStack];
    [self.formStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView).offset(24);
        make.left.equalTo(self.cardView).offset(16);
        make.right.equalTo(self.cardView).offset(-16);
        make.bottom.equalTo(self.cardView).offset(-24);
    }];
}

- (void)reloadForm {
    for (UIView *v in self.formStack.arrangedSubviews) {
        [self.formStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.inputFields removeAllObjects];
    [self.valueLabels removeAllObjects];

    NSInteger idx = 0;
    for (HQITKYCFormRow *row in self.viewModel.rows) {
        UIView *block = [self fieldBlockForRow:row index:idx];
        [self.formStack addArrangedSubview:block];
        idx++;
    }
}

- (UIView *)fieldBlockForRow:(HQITKYCFormRow *)row index:(NSInteger)index {
    UIView *wrap = [[UIView alloc] init];

    UILabel *title = [[UILabel alloc] init];
    title.text = row.itemName;
    title.font = [HQITFontHelper boldFontOfSize:14];
    title.textColor = [self color102B4B];
    [wrap addSubview:title];
    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(wrap);
    }];

    UIView *box = [[UIView alloc] init];
    box.layer.cornerRadius = 10;
    box.layer.borderWidth = 1;
    box.layer.borderColor = [self borderColor].CGColor;
    box.backgroundColor = [UIColor whiteColor];
    [wrap addSubview:box];
    [box mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(title.mas_bottom).offset(8);
        make.left.right.bottom.equalTo(wrap);
        make.height.mas_equalTo(48);
    }];

    BOOL isSelect = (row.itemType == HQITKYCItemTypeLocalSelect || row.itemType == HQITKYCItemTypeAPISelect);
    if (isSelect) {
        UILabel *value = [[UILabel alloc] init];
        value.font = [HQITFontHelper regularFontOfSize:13];
        BOOL empty = row.displayValue.length == 0;
        value.text = empty ? @"Please choose" : row.displayValue;
        value.textColor = empty ? [self placeholderColor] : [self color102B4B];
        [box addSubview:value];
        self.valueLabels[@(index)] = value;

        UIImageView *chevron = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"kycplease_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        chevron.contentMode = UIViewContentModeScaleAspectFit;
        [box addSubview:chevron];

        [value mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(box).offset(14);
            make.centerY.equalTo(box);
            make.right.equalTo(chevron.mas_left).offset(-8);
        }];
        [chevron mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(box).offset(-15);
            make.centerY.equalTo(box);
            make.width.height.mas_equalTo(14);
        }];

        UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
        hit.tag = index;
        [hit addTarget:self action:@selector(onSelectRow:) forControlEvents:UIControlEventTouchUpInside];
        [box addSubview:hit];
        [hit mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(box);
        }];
    } else {
        UITextField *tf = [[UITextField alloc] init];
        tf.delegate = self;
        tf.tag = index;
        tf.font = [HQITFontHelper regularFontOfSize:13];
        tf.textColor = [self color102B4B];
        tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Please enter"
                                                                   attributes:@{NSForegroundColorAttributeName: [self placeholderColor]}];
        tf.text = row.displayValue ?: @"";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        if ([row isEmailField]) {
            tf.keyboardType = UIKeyboardTypeEmailAddress;
            tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        } else if ([row isIndianMobileField] || [row.itemCode.lowercaseString isEqualToString:@"child_count"]) {
            tf.keyboardType = UIKeyboardTypeNumberPad;
        }
        [tf addTarget:self action:@selector(onTextChanged:) forControlEvents:UIControlEventEditingChanged];
        self.inputFields[@(index)] = tf;

        [box addSubview:tf];
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
    [self presentExitConfirm];
}

- (void)presentExitConfirm {
    NSString *body = [HQITCategoryText textForKey:@"a40"
                                     defaultText:@"Do you want to pause the authentication and return to the homepage?"];
    UIView *host = self.view.window ?: self.view;
    [HQITDialogs showWhiteConfirmTitle:@"Confirm to return?"
                                  body:body
                                  icon:nil
                         confirmTitle:@"Confirm"
                          cancelTitle:@"Cancel"
                               inView:host
                            onConfirm:^{
        [HQITKYCNavigation confirmExitFrom:self];
    } onCancel:nil];
}

- (void)onContinue {
    if (![HQITClickGuard tryLockControl:self.continueButton]) return;
    [self.view endEditing:YES];
    [self.viewModel commit];
}

- (void)onTextChanged:(UITextField *)tf {
    NSInteger idx = tf.tag;
    if (idx < 0 || idx >= (NSInteger)self.viewModel.rows.count) return;
    HQITKYCFormRow *row = self.viewModel.rows[idx];
    NSString *filtered = [self.viewModel filterInput:tf.text forRow:row];
    if (![filtered isEqualToString:tf.text]) {
        tf.text = filtered;
    }
    [self.viewModel applyInputForRow:row text:filtered];
}

- (void)onSelectRow:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.viewModel.rows.count) return;
    HQITKYCFormRow *row = self.viewModel.rows[idx];
    [self.view endEditing:YES];

    if (row.itemType == HQITKYCItemTypeLocalSelect) {
        [self presentSelectionForRow:row options:row.buttonList title:row.itemName];
        return;
    }
    if (row.itemType == HQITKYCItemTypeAPISelect) {
        if ([row isCityField]) {
            HQITKYCFormRow *prov = [self.viewModel provinceRow];
            NSString *pid = prov.provinceId.length ? prov.provinceId : prov.valueKey;
            if (pid.length == 0) {
                [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k22" defaultText:@"Please select province first."]];
                return;
            }
            __weak typeof(self) weakSelf = self;
            [HQITHUDHelper showLoading];
            [self.viewModel loadCityOptionsForProvinceId:pid then:^(NSArray<HQITKYCButtonOption *> *opts) {
                [HQITHUDHelper hideLoading];
                [weakSelf presentSelectionForRow:row options:opts title:row.itemName];
            }];
            return;
        }
        if ([row isProvinceField]) {
            __weak typeof(self) weakSelf = self;
            [HQITHUDHelper showLoading];
            [self.viewModel loadProvinceOptionsThen:^(NSArray<HQITKYCButtonOption *> *opts) {
                [HQITHUDHelper hideLoading];
                [weakSelf presentSelectionForRow:row options:opts title:row.itemName];
            }];
            return;
        }
        // generic API select fallback: use buttonList if any
        [self presentSelectionForRow:row options:row.buttonList title:row.itemName];
    }
}

- (void)presentSelectionForRow:(HQITKYCFormRow *)row
                       options:(NSArray<HQITKYCButtonOption *> *)options
                         title:(NSString *)title {
    if (options.count == 0) {
        [HQITHUDHelper showToast:@"No options available"];
        return;
    }
    NSMutableArray<HQITSelectionOption *> *sel = [NSMutableArray array];
    for (HQITKYCButtonOption *o in options) {
        [sel addObject:[HQITSelectionOption optionWithKey:o.buttonKey label:o.buttonLabel]];
    }
    NSString *sheetTitle = title.length ? [NSString stringWithFormat:@"Select %@", title] : @"Please choose";
    // Relationship fields often use "Select Relationship"
    if ([row.itemCode.lowercaseString containsString:@"relation"]) {
        sheetTitle = @"Select Relationship";
    }
    UIView *host = self.view.window ?: self.view;
    __weak typeof(self) weakSelf = self;
    [HQITDialogs showSelectionTitle:sheetTitle
                            options:sel
                        selectedKey:row.valueKey
                             inView:host
                         onConfirm:^(HQITSelectionOption *option) {
        [weakSelf.viewModel applySelectionForRow:row key:option.key label:option.label];
    } onCancel:nil];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    return YES; // filtering in EditingChanged
}

@end
