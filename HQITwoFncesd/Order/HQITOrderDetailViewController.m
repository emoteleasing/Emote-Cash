

#import "HQITOrderDetailViewController.h"
#import "HQITOrderDetailViewModel.h"
#import "HQITFontHelper.h"
#import "HQITHUDHelper.h"
#import "HQITClickGuard.h"
#import "HQITNavigationBarStyle.h"
#import "HQITPaymentWebViewController.h"
#import "HQITBankAccountEditViewController.h"
#import "HQITOrderDataCaptureCoordinator.h"
#import "HQITAccurateRecommendSuccessViewController.h"
#import "HQITDialogs.h"
#import "HQITAppShell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@interface HQITOrderDetailViewController ()
@property (nonatomic, strong) HQITOrderDetailViewModel *viewModel;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *formStack;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *secondaryButton;
@end

@implementation HQITOrderDetailViewController

- (instancetype)initWithOrderId:(NSString *)orderId productId:(NSString *)productId {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _viewModel = [[HQITOrderDetailViewModel alloc] initWithOrderId:orderId productId:productId];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildChrome];
    [self bindVM];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    [HQITClickGuard unlockControl:self.primaryButton];
    [HQITClickGuard unlockControl:self.secondaryButton];
    [self.viewModel loadDetail];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    if (w <= 0) return;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];
    [self.headerBg mas_updateConstraints:^(MASConstraintMaker *make) { make.height.mas_equalTo(h); }];
    UIImage *fitted = [HQITNavigationBarStyle loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    if (fitted) self.headerBg.image = fitted;
}

- (void)hqit_setupBackButtonIfNeeded {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:[[UIView alloc] init]];
    self.navigationItem.hidesBackButton = YES;
}

#pragma mark - Colors

- (UIColor *)navy { return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1]; }
- (UIColor *)orange { return [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1]; }
- (UIColor *)content { return [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1]; }
- (UIColor *)gray { return [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1]; }
- (UIColor *)labelGray { return [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1]; }

#pragma mark - Bind

- (void)bindVM {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf reloadContent];
        [weakSelf refreshButtons];
    };
    self.viewModel.onErrorMessage = ^(NSString *message) {
        [HQITHUDHelper showToast:message];
    };
}

#pragma mark - Chrome

- (void)buildChrome {
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
    self.navTitleLabel.text = @"Loan information";
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.primaryButton = [self makePrimaryButton];
    self.primaryButton.hidden = YES;
    [self.primaryButton addTarget:self action:@selector(onPrimary) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.primaryButton];

    self.secondaryButton = [self makeOutlineButton];
    self.secondaryButton.hidden = YES;
    [self.secondaryButton addTarget:self action:@selector(onSecondary) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.secondaryButton];

    [self.primaryButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view).offset(-32);
    }];
    [self.secondaryButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view).offset(-32);
        make.width.equalTo(self.primaryButton);
    }];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.primaryButton.mas_top).offset(-12);
    }];
    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];
    self.formStack = [[UIStackView alloc] init];
    self.formStack.axis = UILayoutConstraintAxisVertical;
    self.formStack.spacing = 12;
    [self.contentView addSubview:self.formStack];
    [self.formStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(8);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.bottom.equalTo(self.contentView).offset(-16);
    }];
    [self.view bringSubviewToFront:self.secondaryButton];
    [self.view bringSubviewToFront:self.primaryButton];
}

- (UIButton *)makePrimaryButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.clipsToBounds = YES;
    btn.layer.cornerRadius = 10;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat bw = MAX(bg.size.width, 1), bh = MAX(bg.size.height, 1);
        [btn setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                   resizingMode:UIImageResizingModeStretch]
                       forState:UIControlStateNormal];
    } else {
        btn.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    }
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    return btn;
}

- (UIButton *)makeOutlineButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.clipsToBounds = YES;
    btn.layer.cornerRadius = 10;
    btn.backgroundColor = [UIColor whiteColor];
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [self orange].CGColor;
    [btn setTitleColor:[self orange] forState:UIControlStateNormal];
    btn.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    return btn;
}

#pragma mark - Reload

- (void)reloadContent {
    for (UIView *v in self.formStack.arrangedSubviews) {
        [self.formStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.formStack addArrangedSubview:[self productCard]];
    if (self.viewModel.maskedBankAccount.length) {
        [self.formStack addArrangedSubview:[self bankCard]];
    }
    if (self.viewModel.detailRows.count) {
        [self.formStack addArrangedSubview:[self cardWrapping:[self detailSection]
                                                       insets:UIEdgeInsetsMake(4, 16, 4, 16)]];
    }
    if (self.viewModel.tipPrimary.length || self.viewModel.tipSecondary.length) {
        [self.formStack addArrangedSubview:[self tipBanner]];
    }
}

- (void)refreshButtons {
    BOOL hasPrimary = self.viewModel.primaryAction != HQITOrderDetailActionNone;
    BOOL hasSecondary = self.viewModel.secondaryAction != HQITOrderDetailActionNone;
    self.primaryButton.hidden = !hasPrimary;
    self.secondaryButton.hidden = !hasSecondary;
    [self.primaryButton setTitle:self.viewModel.primaryButtonTitle forState:UIControlStateNormal];
    [self.secondaryButton setTitle:self.viewModel.secondaryButtonTitle forState:UIControlStateNormal];

    [self.primaryButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view).offset(-32);
        if (hasSecondary) {
            make.right.equalTo(self.view).offset(-16);
            make.left.equalTo(self.secondaryButton.mas_right).offset(12);
            make.width.equalTo(self.secondaryButton);
        } else {
            make.left.equalTo(self.view).offset(16);
            make.right.equalTo(self.view).offset(-16);
        }
    }];
    [self.secondaryButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view).offset(-32);
        if (hasSecondary) {
            make.right.equalTo(self.primaryButton.mas_left).offset(-12);
            make.width.equalTo(self.primaryButton);
        } else {
            make.width.mas_equalTo(0);
        }
    }];

    [self.scrollView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        if (hasPrimary) {
            make.bottom.equalTo(self.primaryButton.mas_top).offset(-12);
        } else {
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16);
        }
    }];
}

#pragma mark - Cards

- (UIView *)whiteCard {
    UIView *c = [[UIView alloc] init];
    c.backgroundColor = [UIColor whiteColor];
    c.layer.cornerRadius = 16;
    c.clipsToBounds = YES;
    return c;
}

- (UIView *)cardWrapping:(UIView *)content insets:(UIEdgeInsets)insets {
    UIView *card = [self whiteCard];
    [card addSubview:content];
    [content mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(card).insets(insets);
    }];
    return card;
}

- (UIView *)productCard {
    UIView *card = [self whiteCard];

    UIImageView *logo = [[UIImageView alloc] init];
    logo.contentMode = UIViewContentModeScaleAspectFill;
    logo.clipsToBounds = YES;
    logo.layer.cornerRadius = 8;
    logo.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    UIImage *ph = [UIImage imageNamed:@"samll_icon"] ?: [UIImage imageNamed:@"amount_icon"];
    if (self.viewModel.productLogo.length) {
        [logo sd_setImageWithURL:[NSURL URLWithString:self.viewModel.productLogo] placeholderImage:ph];
    } else {
        logo.image = ph;
    }
    [card addSubview:logo];

    UILabel *name = [[UILabel alloc] init];
    name.text = self.viewModel.productName;
    name.font = [HQITFontHelper boldFontOfSize:15];
    name.textColor = [self navy];
    [card addSubview:name];

    UILabel *badge = [[UILabel alloc] init];
    badge.text = self.viewModel.statusTitle;
    badge.font = [HQITFontHelper mediumFontOfSize:11];
    badge.textColor = self.viewModel.statusTextColor;
    badge.backgroundColor = self.viewModel.statusBgColor;
    badge.textAlignment = NSTextAlignmentCenter;
    badge.layer.cornerRadius = 4;
    badge.clipsToBounds = YES;
    [card addSubview:badge];

    UILabel *loanTitle = [[UILabel alloc] init];
    loanTitle.text = @"Loan amount";
    loanTitle.font = [HQITFontHelper regularFontOfSize:12];
    loanTitle.textColor = [self gray];
    [card addSubview:loanTitle];
    UILabel *loanValue = [[UILabel alloc] init];
    loanValue.text = self.viewModel.loanAmountDisplay;
    loanValue.font = [HQITFontHelper boldFontOfSize:20];
    loanValue.textColor = [self navy];
    [card addSubview:loanValue];

    UILabel *emiTitle = nil;
    UILabel *emiValue = nil;
    BOOL showEMI = self.viewModel.emisDisplay.length > 0;
    if (showEMI) {
        emiTitle = [[UILabel alloc] init];
        emiTitle.text = @"EMIs";
        emiTitle.font = [HQITFontHelper regularFontOfSize:12];
        emiTitle.textColor = [self gray];
        emiTitle.textAlignment = NSTextAlignmentRight;
        [card addSubview:emiTitle];
        emiValue = [[UILabel alloc] init];
        emiValue.text = self.viewModel.emisDisplay;
        emiValue.font = [HQITFontHelper boldFontOfSize:20];
        emiValue.textColor = [self navy];
        emiValue.textAlignment = NSTextAlignmentRight;
        [card addSubview:emiValue];
    }

    [logo mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(card).offset(16);
        make.top.equalTo(card).offset(16);
        make.width.height.mas_equalTo(36);
    }];
    [badge setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [badge mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(card).offset(-16);
        make.centerY.equalTo(logo);
        make.height.mas_equalTo(22);
    }];
    [name mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(logo.mas_right).offset(10);
        make.centerY.equalTo(logo);
        make.right.lessThanOrEqualTo(badge.mas_left).offset(-8);
    }];

    CGFloat badgeW = [badge.text sizeWithAttributes:@{NSFontAttributeName: badge.font}].width + 16;
    [badge mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(MAX(badgeW, 60));
    }];

    [loanTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(card).offset(16);
        make.top.equalTo(logo.mas_bottom).offset(16);
        if (showEMI) {
            make.right.equalTo(card.mas_centerX).offset(-8);
        } else {
            make.right.equalTo(card).offset(-16);
        }
    }];
    [loanValue mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(loanTitle);
        make.top.equalTo(loanTitle.mas_bottom).offset(6);
        make.bottom.equalTo(card).offset(-16);
    }];
    if (showEMI) {
        [emiTitle mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(loanTitle);
            make.left.equalTo(card.mas_centerX).offset(8);
            make.right.equalTo(card).offset(-16);
        }];
        [emiValue mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(emiTitle);
            make.top.equalTo(emiTitle.mas_bottom).offset(6);
        }];
    }
    return card;
}

- (UIView *)bankCard {
    UIView *row = [self whiteCard];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bank_icon"] ?: [UIImage imageNamed:@"bank_icon_b"]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:icon];
    UILabel *acc = [[UILabel alloc] init];
    acc.text = self.viewModel.maskedBankAccount;
    acc.font = [HQITFontHelper mediumFontOfSize:14];
    acc.textColor = [self navy];
    [row addSubview:acc];
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(row).offset(16);
        make.centerY.equalTo(row);
        make.width.height.mas_equalTo(32);
        make.top.equalTo(row).offset(14);
        make.bottom.equalTo(row).offset(-14);
    }];
    [acc mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(icon.mas_right).offset(12);
        make.centerY.equalTo(icon);
        make.right.equalTo(row).offset(-16);
    }];
    return row;
}

- (UIView *)detailSection {
    UIView *wrap = [[UIView alloc] init];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    [wrap addSubview:stack];
    [stack mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(wrap); }];
    NSArray *rows = self.viewModel.detailRows;
    for (NSInteger i = 0; i < (NSInteger)rows.count; i++) {
        [stack addArrangedSubview:[self detailRowView:rows[i]]];
        if (i < (NSInteger)rows.count - 1) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = [UIColor colorWithRed:0xF0/255.0 green:0xF0/255.0 blue:0xF0/255.0 alpha:1];
            [line mas_makeConstraints:^(MASConstraintMaker *make) {
                make.height.mas_equalTo(1.0 / UIScreen.mainScreen.scale);
            }];
            [stack addArrangedSubview:line];
        }
    }
    return wrap;
}

- (UIView *)detailRowView:(HQITOrderDetailRow *)row {
    UIView *wrap = [[UIView alloc] init];
    UILabel *title = [[UILabel alloc] init];
    title.text = row.title;
    title.font = [HQITFontHelper regularFontOfSize:13];
    title.textColor = [self gray];
    [wrap addSubview:title];

    UIButton *info = nil;
    if (row.infoKey.length) {
        info = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *img = [[UIImage systemImageNamed:@"questionmark.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [info setImage:img forState:UIControlStateNormal];
        info.tintColor = [self gray];
        info.accessibilityIdentifier = row.infoKey;
        [info addTarget:self action:@selector(onInfo:) forControlEvents:UIControlEventTouchUpInside];
        [wrap addSubview:info];
    }

    UILabel *value = [[UILabel alloc] init];
    value.text = row.value;
    value.font = [HQITFontHelper mediumFontOfSize:13];
    value.textColor = [self content];
    value.textAlignment = NSTextAlignmentRight;
    [wrap addSubview:value];

    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(wrap);
        make.top.equalTo(wrap).offset(12);
        make.bottom.equalTo(wrap).offset(-12);
    }];
    if (info) {
        [info mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(title.mas_right).offset(4);
            make.centerY.equalTo(title);
            make.width.height.mas_equalTo(14);
        }];
    }
    [value mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(wrap);
        make.centerY.equalTo(wrap);
        make.left.greaterThanOrEqualTo(info ? info.mas_right : title.mas_right).offset(8);
    }];
    return wrap;
}

- (UIView *)tipBanner {
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [UIColor colorWithRed:0xFF/255.0 green:0xF6/255.0 blue:0xE8/255.0 alpha:1];
    box.layer.cornerRadius = 10;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"with_icon"]
                                                            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    if (!icon.image) {
        icon.image = [[UIImage systemImageNamed:@"exclamationmark.circle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        icon.tintColor = [self orange];
    }
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [box addSubview:icon];

    UILabel *lab = [[UILabel alloc] init];
    lab.numberOfLines = 0;
    lab.font = [HQITFontHelper regularFontOfSize:12];
    lab.textColor = [self labelGray];
    NSMutableString *text = [NSMutableString stringWithString:self.viewModel.tipPrimary ?: @""];
    if (self.viewModel.tipSecondary.length) {
        if (text.length) [text appendString:@"\n"];
        [text appendString:self.viewModel.tipSecondary];
    }
    lab.text = text;
    [box addSubview:lab];

    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(12);
        make.top.equalTo(box).offset(12);
        make.width.height.mas_equalTo(14);
    }];
    [lab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(icon.mas_right).offset(8);
        make.right.equalTo(box).offset(-12);
        make.top.equalTo(box).offset(12);
        make.bottom.equalTo(box).offset(-12);
    }];
    return box;
}

#pragma mark - Actions

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onInfo:(UIButton *)sender {
    NSString *key = sender.accessibilityIdentifier;
    NSString *msg = nil;
    if ([key isEqualToString:@"received"]) {
        msg = @"The actual amount you receive is calculated by deducting the service fee from the loan amount.";
    } else if ([key isEqualToString:@"fee"]) {
        msg = @"Service fee covers the administrative costs of processing your loan application.";
    } else if ([key isEqualToString:@"interest"]) {
        msg = @"Interest is the cost of borrowing money, calculated based on the loan amount and term.";
    }
    if (msg.length) [HQITHUDHelper showToast:msg];
}

- (void)onPrimary {
    [self handleAction:self.viewModel.primaryAction button:self.primaryButton title:self.viewModel.primaryButtonTitle];
}

- (void)onSecondary {
    [self handleAction:self.viewModel.secondaryAction button:self.secondaryButton title:self.viewModel.secondaryButtonTitle];
}

- (void)handleAction:(HQITOrderDetailAction)action button:(UIButton *)button title:(NSString *)title {
    if (action == HQITOrderDetailActionNone) return;
    if (self.viewModel.isActionBusy) return;
    if (![HQITClickGuard tryLockControl:button]) return;

    if (action == HQITOrderDetailActionRepay || action == HQITOrderDetailActionDefer) {
        __weak typeof(self) weakSelf = self;
        [self.viewModel requestPaymentLinkForAction:action
                                          onSuccess:^(NSString *urlString) {
            __strong typeof(weakSelf) self = weakSelf;
            [HQITClickGuard unlockControl:button];
            NSString *webTitle = (action == HQITOrderDetailActionDefer) ? @"Deferment" : @"Repayment";
            HQITPaymentWebViewController *web = [[HQITPaymentWebViewController alloc] initWithURLString:urlString title:webTitle];
            [self.navigationController pushViewController:web animated:YES];
        } onFailure:^(NSString *message) {
            [HQITClickGuard unlockControl:button];
            [HQITHUDHelper showToast:message];
        }];
        return;
    }

    if (action == HQITOrderDetailActionChangeBank) {
        [HQITClickGuard unlockControl:button];
        HQITBankAccountItem *item = self.viewModel.bankAccountItem;
        if (!item) {
            [HQITHUDHelper showToast:@"Bank account not available"];
            return;
        }
        HQITBankAccountEditViewController *vc = [[HQITBankAccountEditViewController alloc] initWithAccount:item];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if (action == HQITOrderDetailActionWithdraw) {
        __weak typeof(self) weakSelf = self;
        [self.viewModel requestWithdrawalOnSuccess:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [HQITClickGuard unlockControl:button];
            [HQITDialogs showWhiteConfirmTitle:@"Success"
                                          body:@"Your loan has been confirmed successfully. The funds will be transferred to your bank account. Please check your bank account."
                                          icon:[HQITDialogs orangeCheckHeaderIcon]
                                 confirmTitle:@"Confirm"
                                  cancelTitle:nil
                                       inView:self.view.window ?: self.view
                                    onConfirm:^{
                [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
                [weakSelf.navigationController popViewControllerAnimated:YES];
            } onCancel:nil];
        } onFailure:^(NSString *message) {
            [HQITClickGuard unlockControl:button];
            [HQITHUDHelper showToast:message];
        }];
        return;
    }

    if (action == HQITOrderDetailActionContinueSubmitting) {
        NSString *oid = self.viewModel.resolvedOrderId;
        if (oid.length == 0) {
            [HQITClickGuard unlockControl:button];
            [HQITHUDHelper showToast:@"Invalid order"];
            return;
        }
        __weak typeof(self) weakSelf = self;
        [HQITOrderDataCaptureCoordinator startWithOrderId:oid
                                       hostViewController:self
                                               completion:^(BOOL success) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [HQITClickGuard unlockControl:button];
            if (!success) return;
            HQITAccurateRecommendSuccessViewController *successVC =
                [[HQITAccurateRecommendSuccessViewController alloc] initWithOrderIds:@[oid]];
            [self.navigationController pushViewController:successVC animated:YES];
        }];
        return;
    }

    [HQITClickGuard unlockControl:button];
    (void)title;
}

@end
