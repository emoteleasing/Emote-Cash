

#import "HQITLoanApplyViewController.h"
#import "HQITLoanApplyViewModel.h"
#import "HQITFontHelper.h"
#import "HQITDialogs.h"
#import "HQITClickGuard.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import "HQITAppStartupManager.h"
#import "HQITConfigWebViewController.h"
#import "HQITPermissionSecondaryPresenter.h"
#import "HQITBuryRecorder.h"
#import "HQITAppShell.h"
#import "HQITOrderDataCaptureCoordinator.h"
#import "HQITAccurateRecommendSuccessViewController.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITSigningHelper.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>
#import <CoreLocation/CoreLocation.h>

@interface HQITLoanApplyViewController () <CLLocationManagerDelegate>
@property (nonatomic, strong) HQITLoanApplyViewModel *viewModel;

@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *formStack;
@property (nonatomic, strong) UIButton *agreeButton;
@property (nonatomic, strong) UIButton *applyButton;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy, nullable) void (^locationCompletion)(NSString *lng, NSString *lat, BOOL cancelled);
@property (nonatomic, assign) BOOL awaitingFirstAuthResult;
@property (nonatomic, strong, nullable) NSTimer *locationTimeoutTimer;
@property (nonatomic, assign) BOOL isLocating;
@end

@implementation HQITLoanApplyViewController

- (instancetype)initWithProductId:(NSString *)productId
                         termData:(NSDictionary *)termData
               prefillProductName:(NSString *)prefillName
            prefillProductLogoURL:(NSString *)prefillLogo {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _viewModel = [[HQITLoanApplyViewModel alloc] initWithProductId:productId
                                                              termData:termData
                                                    prefillProductName:prefillName
                                                 prefillProductLogoURL:prefillLogo];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildChrome];
    [self bindVM];
    [self reloadContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    if (!self.viewModel.isSubmitting && !self.isLocating) {
        [HQITClickGuard unlockControl:self.applyButton];
    }
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

#pragma mark - Bind

- (void)bindVM {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf reloadContent];
        BOOL busy = weakSelf.viewModel.isSubmitting || weakSelf.isLocating;
        weakSelf.applyButton.enabled = !busy;
        weakSelf.applyButton.alpha = busy ? 0.5 : 1.0;
    };
    self.viewModel.onErrorMessage = ^(NSString *message) {
        [HQITHUDHelper showToast:message];
        weakSelf.isLocating = NO;
        [HQITClickGuard unlockControl:weakSelf.applyButton];
    };
    self.viewModel.onSubmitSuccess = ^(NSString *orderId) {
        [weakSelf startCaptureWithOrderId:orderId];
    };
}

- (void)startCaptureWithOrderId:(NSString *)orderId {
    __weak typeof(self) weakSelf = self;
    [HQITOrderDataCaptureCoordinator startWithOrderId:orderId
                                   hostViewController:self
                                           completion:^(BOOL success) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!success) {
            [self.viewModel resetSubmittingState];
            self.isLocating = NO;
            [HQITClickGuard unlockControl:self.applyButton];
            return;
        }
        [self replaceWithSuccessPageOrderId:orderId];
    }];
}

- (void)replaceWithSuccessPageOrderId:(NSString *)orderId {
    NSArray<NSString *> *ids = (orderId.length > 0) ? @[orderId] : @[];
    HQITAccurateRecommendSuccessViewController *success =
        [[HQITAccurateRecommendSuccessViewController alloc] initWithOrderIds:ids];
    NSMutableArray *stack = [self.navigationController.viewControllers mutableCopy] ?: [NSMutableArray array];
    if (stack.count > 0) {
        [stack removeLastObject];
    }
    [stack addObject:success];
    [self.navigationController setViewControllers:stack animated:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
}

#pragma mark - Colors

- (UIColor *)navy { return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1]; }
- (UIColor *)orange { return [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1]; }
- (UIColor *)content { return [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1]; }
- (UIColor *)gray { return [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1]; }
- (UIColor *)fieldFill { return [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1]; }

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
    self.navTitleLabel.text = @"Loan confirmation";
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.applyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.applyButton.clipsToBounds = YES;
    self.applyButton.layer.cornerRadius = 10;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat bw = MAX(bg.size.width, 1), bh = MAX(bg.size.height, 1);
        [self.applyButton setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                resizingMode:UIImageResizingModeStretch]
                                    forState:UIControlStateNormal];
    } else {
        self.applyButton.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    }
    [self.applyButton setTitle:@"Apply Now" forState:UIControlStateNormal];
    [self.applyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.applyButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.applyButton addTarget:self action:@selector(onApply) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.applyButton];
    [self.applyButton mas_makeConstraints:^(MASConstraintMaker *make) {
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
        make.bottom.equalTo(self.applyButton.mas_top).offset(-12);
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
    [self.view bringSubviewToFront:self.applyButton];
}

- (void)refreshAgreeUI {
    UIImage *img = [UIImage imageNamed:self.viewModel.agreed ? @"read_icon" : @"and_icon"];
    if (img) {
        [self.agreeButton setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                          forState:UIControlStateNormal];
        self.agreeButton.tintColor = nil;
    } else {
        UIImage *sf = self.viewModel.agreed
            ? [UIImage systemImageNamed:@"checkmark.square.fill"]
            : [UIImage systemImageNamed:@"square"];
        [self.agreeButton setImage:[sf imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                          forState:UIControlStateNormal];
        self.agreeButton.tintColor = [self orange];
    }
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

    [self.formStack addArrangedSubview:[self bankRow]];

    [self.formStack addArrangedSubview:[self cardWrapping:[self detailSection]
                                                   insets:UIEdgeInsetsMake(4, 16, 4, 16)]];

    [self.formStack addArrangedSubview:[self tipBanner]];
    [self.formStack addArrangedSubview:[self agreeSection]];
    [self refreshAgreeUI];
}

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
    if (self.viewModel.productLogo.length) {
        [logo sd_setImageWithURL:[NSURL URLWithString:self.viewModel.productLogo] placeholderImage:ph];
    } else {
        logo.image = ph;
    }
    [row addSubview:logo];
    UILabel *name = [[UILabel alloc] init];
    name.text = self.viewModel.productName;
    name.font = [HQITFontHelper boldFontOfSize:15];
    name.textColor = [self navy];
    [row addSubview:name];
    [logo mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(row);
        make.width.height.mas_equalTo(36);
    }];
    [name mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(logo.mas_right).offset(10);
        make.centerY.equalTo(logo);
        make.right.equalTo(row);
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
    [stack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(wrap);
    }];
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
    lab.textColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    lab.text = @"Your credit status directly affects your loan limit, and a good credit history helps you secure better loan terms.";
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

- (UIView *)agreeSection {
    UIView *row = [[UIView alloc] init];

    self.agreeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.agreeButton addTarget:self action:@selector(onToggleAgree) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:self.agreeButton];

    UILabel *agreeLab = [[UILabel alloc] init];
    agreeLab.numberOfLines = 0;
    agreeLab.userInteractionEnabled = YES;
    NSString *full = @"I have read and agreed with the 'Terms Of The Loan'";
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:full attributes:@{
        NSFontAttributeName: [HQITFontHelper regularFontOfSize:12],
        NSForegroundColorAttributeName: [self content],
    }];
    NSRange link = [full rangeOfString:@"Terms Of The Loan"];
    if (link.location != NSNotFound) {
        [attr addAttributes:@{
            NSForegroundColorAttributeName: [self orange],
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        } range:link];
    }
    agreeLab.attributedText = attr;
    [row addSubview:agreeLab];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTermsTap)];
    [agreeLab addGestureRecognizer:tap];

    [self.agreeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(row);
        make.top.equalTo(row).offset(4);
        make.width.height.mas_equalTo(20);
        make.bottom.lessThanOrEqualTo(row).offset(-4);
    }];
    [agreeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.agreeButton.mas_right).offset(8);
        make.centerY.equalTo(self.agreeButton);
        make.right.equalTo(row);
        make.bottom.equalTo(row).offset(-4);
    }];
    return row;
}

#pragma mark - Actions

- (void)onBack {
    if (self.viewModel.isSubmitting || self.isLocating) return;
    [self showLeaveConfirm];
}

- (void)showLeaveConfirm {
    __weak typeof(self) weakSelf = self;
    [HQITDialogs showWhiteConfirmTitle:@"Confirm to return?"
                                  body:@"Are you sure you want to leave this page? Your loan application has not been submitted."
                                  icon:nil
                         confirmTitle:@"Confirm"
                          cancelTitle:@"Cancel"
                               inView:self.view.window ?: self.view
                            onConfirm:^{
        [weakSelf leaveApplyPageToRoot];
    } onCancel:nil];
}

- (void)leaveApplyPagePop {
    [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)leaveApplyPageToRoot {
    [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)onToggleAgree {
    self.viewModel.agreed = !self.viewModel.agreed;
    [self refreshAgreeUI];
}

- (void)onTermsTap {
    HQITConfigWebViewController *web = [HQITConfigWebViewController controllerWithHrefConfigKey:@"conditionsHref"
                                                                                      pageTitle:@"Terms Of The Loan"];
    [self.navigationController pushViewController:web animated:YES];
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

- (void)onApply {
    if (self.viewModel.isSubmitting || self.isLocating) return;
    if (!self.viewModel.agreed) {
        [HQITHUDHelper showToast:@"Please agree to the Terms Of The Loan before applying."];
        return;
    }
    [HQITClickGuard lockControl:self.applyButton];
    self.isLocating = YES;
    self.applyButton.enabled = NO;
    self.applyButton.alpha = 0.5;
    __weak typeof(self) weakSelf = self;
    [[HQITAppStartupManager shared] ensureAppConfigThen:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self resolveLocationThen:^(NSString *lng, NSString *lat, BOOL cancelled) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.isLocating = NO;
            BOOL force = [self isForceLocation];
            BOOL placeholder = [lng isEqualToString:@"-360.000000"] || [lat isEqualToString:@"-360.000000"];
            if (cancelled || (force && (lng.length == 0 || lat.length == 0 || placeholder))) {
                NSLog(@"[HQITLoanApply] apply aborted cancelled=%d force=%d lng=%@ lat=%@",
                      cancelled, force, lng, lat);
                [self.viewModel resetSubmittingState];
                [HQITClickGuard unlockControl:self.applyButton];
                return;
            }
            [self.viewModel submitWithLongitude:lng latitude:lat];
        }];
    }];
}

#pragma mark - Location

- (BOOL)isForceLocation {
    return [[HQITAppStartupManager shared] isForceContactMode];
}

- (void)resolveLocationThen:(void (^)(NSString *lng, NSString *lat, BOOL cancelled))completion {
    self.locationCompletion = [completion copy];
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }
    CLAuthorizationStatus status = self.locationManager.authorizationStatus;
    BOOL force = [self isForceLocation];
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        [HQITBuryRecorder recordLocationPermissionGranted:YES]; // 15
        [self startLocationTimeout];
        [self.locationManager requestLocation];
        return;
    }
    if (status == kCLAuthorizationStatusNotDetermined) {
        self.awaitingFirstAuthResult = YES;
        [self.locationManager requestWhenInUseAuthorization];
        return;
    }
    // Denied / restricted
    [HQITBuryRecorder recordLocationPermissionGranted:NO]; // 16
    if (force) {
        [self presentForceLocationGuideThenCancel];
    } else {
        if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
        self.locationCompletion = nil;
    }
}

- (UIView *)permissionHostView {
    return [HQITAppShell shared].window ?: self.view.window ?: self.view;
}

- (void)presentForceLocationGuideThenCancel {
    __weak typeof(self) weakSelf = self;
    [HQITPermissionSecondaryPresenter showLocationSettingsGuideInView:[self permissionHostView]
                                                            onConfirm:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        self.locationCompletion = nil;
    } onCancel:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        self.locationCompletion = nil;
    }];
}

- (void)startLocationTimeout {
    [self clearLocationTimeout];
    __weak typeof(self) weakSelf = self;
    self.locationTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:4.0 repeats:NO block:^(NSTimer *timer) {
        [weakSelf locationFailedForceAware];
    }];
}

- (void)clearLocationTimeout {
    [self.locationTimeoutTimer invalidate];
    self.locationTimeoutTimer = nil;
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    CLAuthorizationStatus status = manager.authorizationStatus;
    if (status == kCLAuthorizationStatusNotDetermined) return;
    if (!self.locationCompletion) return;
    BOOL force = [self isForceLocation];
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        self.awaitingFirstAuthResult = NO;
        [HQITBuryRecorder recordLocationPermissionGranted:YES]; // 15
        [self startLocationTimeout];
        [manager requestLocation];
        return;
    }
    // denied
    [self clearLocationTimeout];
    [HQITBuryRecorder recordLocationPermissionGranted:NO]; // 16
    if (self.awaitingFirstAuthResult) {
        self.awaitingFirstAuthResult = NO;
        if (force) {
            if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        } else {
            if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
        }
        self.locationCompletion = nil;
        return;
    }
    if (force) {
        [self presentForceLocationGuideThenCancel];
        return;
    }
    if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
    self.locationCompletion = nil;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    [self clearLocationTimeout];
    CLLocation *loc = locations.lastObject;
    if (!loc) {
        [self locationFailedForceAware];
        return;
    }
    NSString *lng = [HQITSigningHelper coordinateSignValue:loc.coordinate.longitude];
    NSString *lat = [HQITSigningHelper coordinateSignValue:loc.coordinate.latitude];
    if (self.locationCompletion) self.locationCompletion(lng, lat, NO);
    self.locationCompletion = nil;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (error.code == kCLErrorLocationUnknown) return;
    [self clearLocationTimeout];
    [self locationFailedForceAware];
}

- (void)locationFailedForceAware {
    if (!self.locationCompletion) return;
    [self clearLocationTimeout];
    if ([self isForceLocation]) {
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
    } else {
        if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
    }
    self.locationCompletion = nil;
}

@end
