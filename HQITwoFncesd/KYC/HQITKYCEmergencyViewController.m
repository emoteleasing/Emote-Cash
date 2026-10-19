

#import "HQITKYCEmergencyViewController.h"
#import "HQITKYCEmergencyViewModel.h"
#import "HQITKYCNavigation.h"
#import "HQITFontHelper.h"
#import "HQITDialogs.h"
#import "HQITCategoryText.h"
#import "HQITClickGuard.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import <Masonry/Masonry.h>
#import <ContactsUI/ContactsUI.h>

@interface HQITKYCEmergencyViewController () <UITextFieldDelegate, CNContactPickerDelegate>
@property (nonatomic, copy) NSString *kycId;
@property (nonatomic, copy) NSString *pageTitleText;
@property (nonatomic, assign) BOOL isLastUnfinished;
@property (nonatomic, strong) HQITKYCEmergencyViewModel *viewModel;

@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *formStack;
@property (nonatomic, strong) UIButton *continueButton;
@property (nonatomic, strong, nullable) UITextField *emailField;

@property (nonatomic, assign) NSInteger pickingGroupIndex;
@end

@implementation HQITKYCEmergencyViewController

- (instancetype)initWithKycId:(NSString *)kycId
                    pageTitle:(NSString *)pageTitle
             isLastUnfinished:(BOOL)isLastUnfinished {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _kycId = [kycId copy] ?: @"";
        _pageTitleText = [pageTitle copy] ?: @"Emergency Contact";
        _isLastUnfinished = isLastUnfinished;
        _viewModel = [[HQITKYCEmergencyViewModel alloc] initWithKycId:_kycId];
        _pickingGroupIndex = -1;
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
    CGFloat w = self.view.bounds.size.width;
    if (w <= 0) return;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];
    [self.headerBg mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(h);
    }];
    UIImage *fitted = [HQITNavigationBarStyle loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    if (fitted) self.headerBg.image = fitted;
}

- (void)hqit_setupBackButtonIfNeeded {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:[[UIView alloc] init]];
    self.navigationItem.hidesBackButton = YES;
}

- (BOOL)hqit_shouldPopBack {
    return NO;
}

#pragma mark - Bind

- (void)bindVM {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf reloadForm];
        weakSelf.continueButton.enabled = !weakSelf.viewModel.isSubmitting;
        weakSelf.continueButton.alpha = weakSelf.viewModel.isSubmitting ? 0.5 : 1.0;
        if (!weakSelf.viewModel.isSubmitting) {
            [HQITClickGuard unlockControl:weakSelf.continueButton];
        }
    };
    self.viewModel.onCommitSuccess = ^{
        [HQITKYCNavigation advanceFrom:weakSelf];
    };
    self.viewModel.onErrorMessage = ^(NSString *message) {
        [HQITHUDHelper showToast:message];
        [HQITClickGuard unlockControl:weakSelf.continueButton];
    };
}

#pragma mark - Colors

- (UIColor *)navy {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)placeholderColor {
    return [UIColor colorWithRed:0xC0/255.0 green:0xC4/255.0 blue:0xCC/255.0 alpha:1];
}

- (UIColor *)fieldFill {
    return [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
}

- (UIColor *)contentColor {
    return [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
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
    self.navTitleLabel.text = self.pageTitleText;
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.continueButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.continueButton.clipsToBounds = YES;
    self.continueButton.layer.cornerRadius = 10;
    UIImage *btnBg = [UIImage imageNamed:@"button_bg"];
    if (btnBg) {
        CGFloat bw = MAX(btnBg.size.width, 1), bh = MAX(btnBg.size.height, 1);
        [self.continueButton setBackgroundImage:[btnBg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                       resizingMode:UIImageResizingModeStretch]
                                       forState:UIControlStateNormal];
    } else {
        self.continueButton.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    }
    NSString *btnTitle = self.isLastUnfinished ? @"Apply Now" : @"Continue";
    [self.continueButton setTitle:btnTitle forState:UIControlStateNormal];
    [self.continueButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.continueButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.continueButton addTarget:self action:@selector(onContinue) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.continueButton];
    [self.continueButton mas_makeConstraints:^(MASConstraintMaker *make) {
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
        make.bottom.equalTo(self.continueButton.mas_top).offset(-12);
    }];

    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];

    self.formStack = [[UIStackView alloc] init];
    self.formStack.axis = UILayoutConstraintAxisVertical;
    self.formStack.spacing = 16;
    [self.contentView addSubview:self.formStack];
    [self.formStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(8);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.bottom.equalTo(self.contentView).offset(-16);
    }];
}

- (void)reloadForm {
    NSString *emailText = self.emailField.text;
    BOOL emailFocused = self.emailField.isFirstResponder;

    for (UIView *v in self.formStack.arrangedSubviews) {
        [self.formStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    self.emailField = nil;

    NSInteger idx = 0;
    for (HQITKYCEmergencyGroup *g in self.viewModel.groups) {
        [self.formStack addArrangedSubview:[self sectionForGroup:g index:idx]];
        idx++;
    }
    if (self.viewModel.emailRow) {
        [self.formStack addArrangedSubview:[self emailSection]];
        if (emailText.length && self.viewModel.emailRow.displayValue.length == 0) {
            self.emailField.text = emailText;
        }
        if (emailFocused) [self.emailField becomeFirstResponder];
    }
}

#pragma mark - Sections

- (UIView *)sectionForGroup:(HQITKYCEmergencyGroup *)group index:(NSInteger)index {
    UIView *wrap = [[UIView alloc] init];

    UILabel *title = [[UILabel alloc] init];
    title.text = [group sectionTitle];
    title.font = [HQITFontHelper boldFontOfSize:14];
    title.textColor = [self navy];
    [wrap addSubview:title];
    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(wrap);
    }];

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;
    [wrap addSubview:card];
    [card mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(title.mas_bottom).offset(10);
        make.left.right.bottom.equalTo(wrap);
    }];

    UIView *relationBox = [self relationRowForGroup:group index:index];
    [card addSubview:relationBox];
    [relationBox mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(16);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(card).offset(-16);
        make.height.mas_equalTo(44);
    }];

    UIView *contactRow = [self contactPickerRowForGroup:group index:index];
    [card addSubview:contactRow];
    [contactRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(relationBox.mas_bottom).offset(12);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(card).offset(-16);
        make.height.mas_equalTo(64);
        make.bottom.equalTo(card).offset(-16);
    }];

    return wrap;
}

- (UIView *)relationRowForGroup:(HQITKYCEmergencyGroup *)group index:(NSInteger)index {
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [self fieldFill];
    box.layer.cornerRadius = 10;
    box.clipsToBounds = YES;

    BOOL hasValue = [group.relationRow commitValue].length > 0;
    UILabel *left = [[UILabel alloc] init];
    left.font = [HQITFontHelper regularFontOfSize:13];
    left.text = hasValue ? (group.relationRow.displayValue ?: @"") : @"Relationship";
    left.textColor = hasValue ? [self contentColor] : [self placeholderColor];
    [box addSubview:left];

    UILabel *hint = [[UILabel alloc] init];
    hint.font = [HQITFontHelper regularFontOfSize:13];
    hint.text = [HQITCategoryText textForKey:@"m56" defaultText:@"Please choose"];
    hint.textColor = [self placeholderColor];
    hint.textAlignment = NSTextAlignmentRight;
    [box addSubview:hint];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"kycplease_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [box addSubview:chevron];

    [left mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(14);
        make.centerY.equalTo(box);
    }];
    [chevron mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(box).offset(-15);
        make.centerY.equalTo(box);
        make.width.height.mas_equalTo(14);
    }];
    [hint mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(chevron.mas_left).offset(-6);
        make.centerY.equalTo(box);
        make.left.greaterThanOrEqualTo(left.mas_right).offset(8);
    }];
    [left setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
    hit.tag = index;
    [hit addTarget:self action:@selector(onRelationTap:) forControlEvents:UIControlEventTouchUpInside];
    [box addSubview:hit];
    [hit mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(box);
    }];
    return box;
}

- (UIView *)contactPickerRowForGroup:(HQITKYCEmergencyGroup *)group index:(NSInteger)index {
    UIView *wrap = [[UIView alloc] init];

    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [self fieldFill];
    box.layer.cornerRadius = 10;
    box.clipsToBounds = YES;
    [wrap addSubview:box];

    UIButton *iconBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    iconBtn.tag = index;
    UIImage *person = [[UIImage imageNamed:@"cintactsel_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [iconBtn setImage:person forState:UIControlStateNormal];
    iconBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [iconBtn addTarget:self action:@selector(onContactTap:) forControlEvents:UIControlEventTouchUpInside];
    [wrap addSubview:iconBtn];

    [iconBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(wrap);
        make.centerY.equalTo(wrap);
        make.width.height.mas_equalTo(32);
    }];
    [box mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(wrap);
        make.right.equalTo(iconBtn.mas_left).offset(-10);
    }];

    NSString *name = [group.nameRow commitValue];
    NSString *phoneDisp = [self.viewModel displayPhoneForRow:group.phoneRow];
    BOOL filled = name.length > 0 || phoneDisp.length > 0;

    UILabel *nameLab = [[UILabel alloc] init];
    nameLab.font = [HQITFontHelper regularFontOfSize:13];
    nameLab.text = filled && name.length ? name : @"Name";
    nameLab.textColor = filled && name.length ? [self contentColor] : [self placeholderColor];
    [box addSubview:nameLab];

    UILabel *phoneLab = [[UILabel alloc] init];
    phoneLab.font = [HQITFontHelper regularFontOfSize:13];
    phoneLab.text = filled && phoneDisp.length ? phoneDisp : @"Phone number";
    phoneLab.textColor = filled && phoneDisp.length ? [self contentColor] : [self placeholderColor];
    [box addSubview:phoneLab];

    [nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(14);
        make.top.equalTo(box).offset(12);
        make.right.lessThanOrEqualTo(box).offset(-14);
    }];
    [phoneLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(nameLab);
        make.top.equalTo(nameLab.mas_bottom).offset(4);
        make.right.lessThanOrEqualTo(box).offset(-14);
        make.bottom.lessThanOrEqualTo(box).offset(-12);
    }];

    if (!filled) {
        UILabel *hint = [[UILabel alloc] init];
        hint.font = [HQITFontHelper regularFontOfSize:13];
        hint.text = [HQITCategoryText textForKey:@"m56" defaultText:@"Please choose"];
        hint.textColor = [self placeholderColor];
        hint.textAlignment = NSTextAlignmentRight;
        [box addSubview:hint];
        [hint mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(box).offset(-14);
            make.centerY.equalTo(box);
            make.left.greaterThanOrEqualTo(nameLab.mas_right).offset(8);
        }];
    }

    UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
    hit.tag = index;
    [hit addTarget:self action:@selector(onContactTap:) forControlEvents:UIControlEventTouchUpInside];
    [box addSubview:hit];
    [hit mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(box);
    }];

    return wrap;
}

- (UIView *)emailSection {
    UIView *wrap = [[UIView alloc] init];

    UILabel *title = [[UILabel alloc] init];
    title.text = self.viewModel.emailRow.itemName.length ? self.viewModel.emailRow.itemName : @"E-mail";
    title.font = [HQITFontHelper boldFontOfSize:14];
    title.textColor = [self navy];
    [wrap addSubview:title];
    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(wrap);
    }];

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;
    [wrap addSubview:card];
    [card mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(title.mas_bottom).offset(10);
        make.left.right.bottom.equalTo(wrap);
    }];

    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [self fieldFill];
    box.layer.cornerRadius = 10;
    [card addSubview:box];
    [box mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(16);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(card).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(card).offset(-16);
    }];

    UITextField *tf = [[UITextField alloc] init];
    tf.delegate = self;
    tf.font = [HQITFontHelper regularFontOfSize:13];
    tf.textColor = [self contentColor];
    tf.keyboardType = UIKeyboardTypeEmailAddress;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.attributedPlaceholder = [[NSAttributedString alloc]
                                initWithString:[HQITCategoryText textForKey:@"m34" defaultText:@"Please enter"]
                                attributes:@{NSForegroundColorAttributeName: [self placeholderColor]}];
    tf.text = self.viewModel.emailRow.displayValue ?: @"";
    [tf addTarget:self action:@selector(onEmailChanged:) forControlEvents:UIControlEventEditingChanged];
    self.emailField = tf;
    [box addSubview:tf];
    [tf mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(14);
        make.right.equalTo(box).offset(-14);
        make.top.bottom.equalTo(box);
    }];
    return wrap;
}

#pragma mark - Actions

- (void)onBack {
    NSString *body = [HQITCategoryText textForKey:@"a40"
                                     defaultText:@"Do you want to pause the authentication and return to the homepage?"];
    [HQITDialogs showWhiteConfirmTitle:@"Confirm to return?"
                                  body:body
                                  icon:nil
                         confirmTitle:@"Confirm"
                          cancelTitle:@"Cancel"
                               inView:self.view.window ?: self.view
                            onConfirm:^{
        [HQITKYCNavigation confirmExitFrom:self];
    } onCancel:nil];
}

- (void)onContinue {
    if (![HQITClickGuard tryLockControl:self.continueButton]) return;
    [self.view endEditing:YES];
    [self.viewModel commit];
}

- (void)onEmailChanged:(UITextField *)tf {
    [self.viewModel applyEmail:tf.text];
    NSString *capped = self.viewModel.emailRow.displayValue ?: @"";
    if (![tf.text isEqualToString:capped]) {
        tf.text = capped;
    }
}

- (NSInteger)hqit_emailMaxLength {
    NSInteger maxL = self.viewModel.emailRow.maxLength;
    if (maxL <= 0 || maxL > 128) return 128;
    return maxL;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField != self.emailField) return YES;
    NSInteger maxL = [self hqit_emailMaxLength];
    NSString *current = textField.text ?: @"";
    if (range.location > current.length) return NO;
    NSString *proposed = [current stringByReplacingCharactersInRange:range withString:string ?: @""];
    if ((NSInteger)proposed.length <= maxL) return YES;
    if (string.length == 0) return YES;
    NSInteger keep = maxL - (NSInteger)(current.length - range.length);
    if (keep <= 0) return NO;
    NSString *clipped = [string substringToIndex:MIN((NSUInteger)keep, string.length)];
    NSString *next = [current stringByReplacingCharactersInRange:range withString:clipped];
    textField.text = next;
    [self.viewModel applyEmail:next];
    UITextPosition *end = textField.endOfDocument;
    textField.selectedTextRange = [textField textRangeFromPosition:end toPosition:end];
    return NO;
}

- (void)onRelationTap:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.viewModel.groups.count) return;
    HQITKYCEmergencyGroup *g = self.viewModel.groups[idx];
    HQITKYCFormRow *row = g.relationRow;
    if (!row) return;
    if (row.buttonList.count == 0) {
        [HQITHUDHelper showToast:@"No options available"];
        return;
    }
    NSMutableArray *opts = [NSMutableArray array];
    for (HQITKYCButtonOption *o in row.buttonList) {
        [opts addObject:[HQITSelectionOption optionWithKey:o.buttonKey label:o.buttonLabel]];
    }
    NSString *title = row.itemName.length ? [NSString stringWithFormat:@"Select %@", row.itemName] : @"Select Relationship";
    __weak typeof(self) weakSelf = self;
    [HQITDialogs showSelectionTitle:title
                            options:opts
                        selectedKey:row.valueKey
                             inView:self.view.window ?: self.view
                         onConfirm:^(HQITSelectionOption *option) {
        [weakSelf.viewModel applyRelation:row key:option.key label:option.label];
    } onCancel:nil];
}

- (void)onContactTap:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.viewModel.groups.count) return;
    [self presentContactPickerForGroupIndex:idx];
}

- (void)presentContactPickerForGroupIndex:(NSInteger)index {
    self.pickingGroupIndex = index;
    CNContactPickerViewController *picker = [[CNContactPickerViewController alloc] init];
    picker.delegate = self;
    picker.displayedPropertyKeys = @[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey];
    picker.predicateForSelectionOfContact = [NSPredicate predicateWithValue:NO];
    picker.predicateForSelectionOfProperty = [NSPredicate predicateWithFormat:@"key == 'phoneNumbers'"];
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - CNContactPickerDelegate

- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
    self.pickingGroupIndex = -1;
}

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty {
    NSInteger idx = self.pickingGroupIndex;
    self.pickingGroupIndex = -1;
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (idx < 0 || idx >= (NSInteger)self.viewModel.groups.count) return;
    if (![contactProperty.key isEqualToString:CNContactPhoneNumbersKey]) return;

    CNContact *c = contactProperty.contact;
    NSString *given = c.givenName ?: @"";
    NSString *family = c.familyName ?: @"";
    NSString *name = [[NSString stringWithFormat:@"%@ %@", given, family]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    CNPhoneNumber *phoneNum = (CNPhoneNumber *)contactProperty.value;
    NSString *phone = phoneNum.stringValue ?: @"";
    if (name.length == 0 || phone.length == 0) {
        [HQITHUDHelper showToast:@"Invalid contact"];
        return;
    }
    HQITKYCEmergencyGroup *g = self.viewModel.groups[idx];
    NSString *err = [self.viewModel validateAndApplyContactName:name phone:phone forGroup:g];
    if (err.length) {
        [HQITHUDHelper showToast:err];
    }
}

@end
