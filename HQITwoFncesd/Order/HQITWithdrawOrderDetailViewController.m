

#import "HQITWithdrawOrderDetailViewController.h"
#import "HQITWithdrawOrderDetailViewModel.h"
#import "HQITFontHelper.h"
#import "HQITHUDHelper.h"
#import "HQITClickGuard.h"
#import "HQITNavigationBarStyle.h"
#import "HQITDialogs.h"
#import "HQITAppShell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@interface HQITWithdrawOrderDetailViewController ()
@property (nonatomic, strong) HQITWithdrawOrderDetailViewModel *viewModel;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *formStack;
@property (nonatomic, strong) UIButton *withdrawButton;
@end

@implementation HQITWithdrawOrderDetailViewController

- (instancetype)initWithOrderId:(NSString *)orderId productId:(NSString *)productId {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _viewModel = [[HQITWithdrawOrderDetailViewModel alloc] initWithOrderId:orderId productId:productId];
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
    [HQITClickGuard unlockControl:self.withdrawButton];
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
- (UIColor *)gray { return [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1]; }
- (UIColor *)content { return [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1]; }
- (UIColor *)fieldFill { return [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1]; }

#pragma mark - Bind

- (void)bindVM {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf reloadContent];
        weakSelf.withdrawButton.enabled = !weakSelf.viewModel.isSubmitting;
        weakSelf.withdrawButton.alpha = weakSelf.viewModel.isSubmitting ? 0.6 : 1.0;
    };
    self.viewModel.onErrorMessage = ^(NSString *message) {
        [HQITClickGuard unlockControl:weakSelf.withdrawButton];
        [HQITHUDHelper showToast:message];
    };
    self.viewModel.onWithdrawSuccess = ^{
        [HQITClickGuard unlockControl:weakSelf.withdrawButton];
        [HQITDialogs showWhiteConfirmTitle:@"Success!"
                                      body:@"Withdrawal is successful, the funds will be transferred to your bank account, please check"
                                      icon:[HQITDialogs orangeCheckHeaderIcon]
                             confirmTitle:@"Confirm"
                              cancelTitle:nil
                                   inView:weakSelf.view.window ?: weakSelf.view
                                onConfirm:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
            [weakSelf.navigationController popViewControllerAnimated:YES];
        } onCancel:nil];
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

    self.withdrawButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.withdrawButton.clipsToBounds = YES;
    self.withdrawButton.layer.cornerRadius = 10;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat bw = MAX(bg.size.width, 1), bh = MAX(bg.size.height, 1);
        [self.withdrawButton setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                   resizingMode:UIImageResizingModeStretch]
                                       forState:UIControlStateNormal];
    } else {
        self.withdrawButton.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    }
    [self.withdrawButton setTitle:@"Get loan" forState:UIControlStateNormal];
    [self.withdrawButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.withdrawButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.withdrawButton addTarget:self action:@selector(onWithdraw) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.withdrawButton];
    [self.withdrawButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view).offset(-32);
    }];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.withdrawButton.mas_top).offset(-12);
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
}

#pragma mark - Reload

- (void)reloadContent {
    for (UIView *v in self.formStack.arrangedSubviews) {
        [self.formStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    [self.formStack addArrangedSubview:[self cardWrapping:[self productHeaderRow]
                                                   insets:UIEdgeInsetsMake(14, 16, 14, 16)]];
    [self.formStack addArrangedSubview:[self cardWrapping:[self amountSection]
                                                   insets:UIEdgeInsetsMake(16, 16, 16, 16)]];
    if (self.viewModel.isMultiAmount || self.viewModel.isMultiTerm) {
        [self.formStack addArrangedSubview:[self cardWrapping:[self termSelectRow]
                                                       insets:UIEdgeInsetsMake(0, 0, 0, 0)]];
    }
    if (self.viewModel.maskedBankAccount.length) {
        [self.formStack addArrangedSubview:[self bankRow]];
    }
    if (self.viewModel.detailRows.count) {
        [self.formStack addArrangedSubview:[self cardWrapping:[self detailSection]
                                                       insets:UIEdgeInsetsMake(4, 16, 4, 16)]];
    }
    if (self.viewModel.tipText.length) {
        [self.formStack addArrangedSubview:[self tipBanner]];
    }
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

- (UIView *)productHeaderRow {
    UIView *row = [[UIView alloc] init];
    UIImageView *logo = [[UIImageView alloc] init];
    logo.contentMode = UIViewContentModeScaleAspectFill;
    logo.clipsToBounds = YES;
    logo.layer.cornerRadius = 8;
    logo.backgroundColor = [self fieldFill];
    UIImage *ph = [UIImage imageNamed:@"samll_icon"] ?: [UIImage imageNamed:@"amount_icon"];
    logo.image = ph;
    NSString *logoURL = self.viewModel.productLogo;
    if (logoURL.length) {
        NSURL *url = [NSURL URLWithString:logoURL];
        if (!url) {
            NSMutableCharacterSet *allowed = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
            [allowed addCharactersInString:@":/?#[]@!$&'()*+,;="];
            NSString *encoded = [logoURL stringByAddingPercentEncodingWithAllowedCharacters:allowed];
            url = [NSURL URLWithString:encoded ?: @""];
        }
        if (url) {
            [logo sd_setImageWithURL:url placeholderImage:ph];
        }
    }
    [row addSubview:logo];

    UILabel *name = [[UILabel alloc] init];
    NSString *pname = self.viewModel.productName;
    if (pname.length == 0 || [pname isEqualToString:@"—"]) {
        pname = self.viewModel.productId.length ? self.viewModel.productId : @"Product";
    }
    name.text = pname;
    name.font = [HQITFontHelper boldFontOfSize:15];
    name.textColor = [self navy];
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    [row addSubview:name];

    UILabel *badge = [[UILabel alloc] init];
    badge.text = [NSString stringWithFormat:@"  %@  ", self.viewModel.statusTitle.length ? self.viewModel.statusTitle : @"Pending"];
    badge.font = [HQITFontHelper mediumFontOfSize:11];
    badge.textColor = self.viewModel.statusTextColor;
    badge.backgroundColor = self.viewModel.statusBgColor;
    badge.textAlignment = NSTextAlignmentCenter;
    badge.layer.cornerRadius = 4;
    badge.clipsToBounds = YES;
    [badge setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [badge setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [row addSubview:badge];

    [logo mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(row);
        make.width.height.mas_equalTo(36);
    }];
    [badge mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(row);
        make.centerY.equalTo(logo);
        make.height.mas_equalTo(22);
    }];
    [name mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(logo.mas_right).offset(10);
        make.centerY.equalTo(logo);
        make.right.lessThanOrEqualTo(badge.mas_left).offset(-8);
    }];
    return row;
}

- (UIView *)amountSection {
    UIView *wrap = [[UIView alloc] init];
    if (self.viewModel.isMultiAmount) {
        UILabel *title = [[UILabel alloc] init];
        title.text = @"Please select the loan amount you need";
        title.font = [HQITFontHelper boldFontOfSize:14];
        title.textColor = [self navy];
        title.numberOfLines = 0;
        [wrap addSubview:title];
        UIImageView *coin = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bicoin_icon"]];
        coin.contentMode = UIViewContentModeScaleAspectFit;
        [wrap addSubview:coin];
        [title mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.equalTo(wrap);
            make.right.equalTo(coin.mas_left).offset(-8);
        }];
        [coin mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(wrap);
            make.centerY.equalTo(title);
            make.width.height.mas_equalTo(28);
        }];

        UIStackView *vStack = [[UIStackView alloc] init];
        vStack.axis = UILayoutConstraintAxisVertical;
        vStack.spacing = 8;
        [wrap addSubview:vStack];
        [vStack mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(title.mas_bottom).offset(12);
            make.left.right.bottom.equalTo(wrap);
        }];

        NSInteger count = self.viewModel.amountList.count;
        for (NSInteger i = 0; i < count; i += 3) {
            UIStackView *row = [[UIStackView alloc] init];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 8;
            row.distribution = UIStackViewDistributionFillEqually;
            for (NSInteger j = i; j < MIN(i + 3, count); j++) {
                BOOL selected = (j == self.viewModel.selectedAmountIndex);
                UIButton *chip = [UIButton buttonWithType:UIButtonTypeCustom];
                chip.tag = j;
                chip.layer.cornerRadius = 8;
                chip.clipsToBounds = YES;
                if (selected) {
                    UIImage *bg = [UIImage imageNamed:@"button_bg"];
                    if (bg) {
                        CGFloat bw = MAX(bg.size.width, 1), bh = MAX(bg.size.height, 1);
                        [chip setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                    resizingMode:UIImageResizingModeStretch]
                                        forState:UIControlStateNormal];
                    } else {
                        chip.backgroundColor = [self orange];
                    }
                    chip.layer.borderWidth = 0;
                } else {
                    chip.backgroundColor = [self fieldFill];
                    chip.layer.borderWidth = 0;
                }
                [chip setTitle:[self.viewModel displayAmountAtIndex:j] forState:UIControlStateNormal];
                [chip setTitleColor:selected ? [UIColor whiteColor] : [self navy] forState:UIControlStateNormal];
                chip.titleLabel.font = [HQITFontHelper mediumFontOfSize:12];
                chip.titleLabel.adjustsFontSizeToFitWidth = YES;
                chip.titleLabel.minimumScaleFactor = 0.7;
                [chip addTarget:self action:@selector(onAmountChip:) forControlEvents:UIControlEventTouchUpInside];
                [chip mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.height.mas_equalTo(44);
                }];
                [row addArrangedSubview:chip];
            }
            while (row.arrangedSubviews.count < 3) {
                [row addArrangedSubview:[[UIView alloc] init]];
            }
            [vStack addArrangedSubview:row];
        }
    } else {
        BOOL showTermBeside = !self.viewModel.isMultiTerm;

        UILabel *amtTitle = [[UILabel alloc] init];
        amtTitle.text = @"Loan amount";
        amtTitle.font = [HQITFontHelper regularFontOfSize:12];
        amtTitle.textColor = [self gray];
        [wrap addSubview:amtTitle];
        UILabel *amtValue = [[UILabel alloc] init];
        amtValue.text = [self.viewModel displayAmountAtIndex:0];
        amtValue.font = [HQITFontHelper boldFontOfSize:20];
        amtValue.textColor = [self navy];
        [wrap addSubview:amtValue];

        [amtTitle mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.equalTo(wrap);
            if (showTermBeside) {
                make.right.equalTo(wrap.mas_centerX).offset(-8);
            } else {
                make.right.equalTo(wrap);
            }
        }];
        [amtValue mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(amtTitle.mas_bottom).offset(6);
            make.left.right.equalTo(amtTitle);
            make.bottom.equalTo(wrap);
        }];

        if (showTermBeside) {
            UILabel *termTitle = [[UILabel alloc] init];
            termTitle.text = self.viewModel.isEMI ? @"EMIs" : @"Loan term";
            termTitle.font = [HQITFontHelper regularFontOfSize:12];
            termTitle.textColor = [self gray];
            termTitle.textAlignment = NSTextAlignmentRight;
            [wrap addSubview:termTitle];
            UILabel *termValue = [[UILabel alloc] init];
            NSString *td = [self.viewModel currentTermDisplay];
            if (self.viewModel.isEMI) {
                termValue.text = td;
            } else {
                NSString *raw = [self.viewModel currentShowTermRaw];
                NSCharacterSet *nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
                if (raw.length && [raw rangeOfCharacterFromSet:nonDigit].location == NSNotFound) {
                    termValue.text = [NSString stringWithFormat:@"%@ (Days)", raw];
                } else {
                    termValue.text = td;
                }
            }
            termValue.font = [HQITFontHelper boldFontOfSize:20];
            termValue.textColor = [self navy];
            termValue.textAlignment = NSTextAlignmentRight;
            [wrap addSubview:termValue];
            [termTitle mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(amtTitle);
                make.left.equalTo(wrap.mas_centerX).offset(8);
                make.right.equalTo(wrap);
            }];
            [termValue mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(termTitle.mas_bottom).offset(6);
                make.left.right.equalTo(termTitle);
            }];
        }
    }
    return wrap;
}

- (UIView *)termSelectRow {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [UIColor clearColor];

    UILabel *title = [[UILabel alloc] init];
    title.text = [self.viewModel termSelectTitle];
    title.font = [HQITFontHelper boldFontOfSize:14];
    title.textColor = [self navy];
    [row addSubview:title];

    UILabel *value = [[UILabel alloc] init];
    value.text = [self.viewModel currentTermDisplay];
    value.font = [HQITFontHelper mediumFontOfSize:13];
    value.textColor = [self orange];
    value.textAlignment = NSTextAlignmentRight;
    [row addSubview:value];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.tintColor = [self orange];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.hidden = !self.viewModel.isMultiTerm;
    [row addSubview:chevron];

    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(row).offset(16);
        make.top.equalTo(row).offset(16);
        make.bottom.equalTo(row).offset(-16);
    }];
    [chevron mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(row).offset(-16);
        make.centerY.equalTo(row);
        make.width.height.mas_equalTo(14);
    }];
    [value mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.viewModel.isMultiTerm ? chevron.mas_left : row).offset(self.viewModel.isMultiTerm ? -6 : -16);
        make.centerY.equalTo(row);
        make.left.greaterThanOrEqualTo(title.mas_right).offset(8);
    }];

    if (self.viewModel.isMultiTerm) {
        UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
        [hit addTarget:self action:@selector(onTermSelect) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:hit];
        [hit mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(row); }];
    }
    return row;
}

- (UIView *)bankRow {
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
    NSArray *rows = [self.viewModel detailRows];
    for (NSInteger i = 0; i < (NSInteger)rows.count; i++) {
        HQITLoanApplyDetailRow *r = rows[i];
        [stack addArrangedSubview:[self detailRowView:r]];
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

- (UIView *)detailRowView:(HQITLoanApplyDetailRow *)row {
    UIView *wrap = [[UIView alloc] init];
    UILabel *title = [[UILabel alloc] init];
    title.text = row.title;
    title.font = [HQITFontHelper regularFontOfSize:13];
    title.textColor = [self gray];
    [wrap addSubview:title];

    UIButton *info = nil;
    if (row.infoKey.length) {
        info = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *img = [[UIImage systemImageNamed:@"info.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [info setImage:img forState:UIControlStateNormal];
        info.tintColor = [self gray];
        info.accessibilityIdentifier = row.infoKey;
        [info addTarget:self action:@selector(onInfo:) forControlEvents:UIControlEventTouchUpInside];
        [wrap addSubview:info];
    }

    UILabel *value = [[UILabel alloc] init];
    value.text = row.value;
    value.font = row.emphasized ? [HQITFontHelper boldFontOfSize:13] : [HQITFontHelper regularFontOfSize:13];
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
    box.backgroundColor = [UIColor colorWithRed:0xFF/255.0 green:0xF6/255.0 blue:0xEC/255.0 alpha:1];
    box.layer.cornerRadius = 12;
    box.layer.borderWidth = 1;
    box.layer.borderColor = [UIColor colorWithRed:0xFF/255.0 green:0xD9/255.0 blue:0xB8/255.0 alpha:1].CGColor;
    box.clipsToBounds = YES;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"with_icon"]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [box addSubview:icon];
    UILabel *lab = [[UILabel alloc] init];
    lab.text = self.viewModel.tipText;
    lab.font = [HQITFontHelper regularFontOfSize:12];
    lab.textColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    lab.numberOfLines = 0;
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

- (void)onAmountChip:(UIButton *)sender {
    [self.viewModel selectAmountAtIndex:sender.tag];
}

- (void)onTermSelect {
    NSArray *labels = [self.viewModel termOptionLabels];
    if (labels.count == 0) return;
    NSMutableArray *opts = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)labels.count; i++) {
        [opts addObject:[HQITSelectionOption optionWithKey:[NSString stringWithFormat:@"%ld", (long)i] label:labels[i]]];
    }
    NSString *selected = [NSString stringWithFormat:@"%ld", (long)self.viewModel.selectedTermIndex];
    __weak typeof(self) weakSelf = self;
    [HQITDialogs showSelectionTitle:[self.viewModel termSelectTitle]
                            options:opts
                        selectedKey:selected
                             inView:self.view.window ?: self.view
                         onConfirm:^(HQITSelectionOption *option) {
        [weakSelf.viewModel selectTermAtIndex:option.key.integerValue];
    } onCancel:nil];
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

- (void)onWithdraw {
    if (self.viewModel.isSubmitting) return;
    if (![HQITClickGuard tryLockControl:self.withdrawButton]) return;
    [self.viewModel submitWithdrawal];
}

@end
