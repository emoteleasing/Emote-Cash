

#import "HQITHomeLoanViewController.h"
#import "HQITHomeLoanViewModel.h"
#import "HQITHomeSessionState.h"
#import "HQITFontHelper.h"
#import "HQITAppShell.h"
#import "HQITClickGuard.h"
#import "HQITDialogs.h"
#import "HQITKYCNavigation.h"
#import "HQITOrderHistoryViewController.h"
#import "HQITWithdrawOrderDetailViewController.h"
#import "HQITBankAccountViewController.h"
#import "HQITConfigWebViewController.h"
#import "HQITRejectH5ViewController.h"
#import "HQITAccurateRecommendationViewController.h"
#import "HQITAccurateRecommendViewModel.h"
#import "HQITVersionUpdatePresenter.h"
#import "HQITAutoOrderCoordinator.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import <Masonry/Masonry.h>

@interface HQITHomeLoanViewController ()
@property (nonatomic, strong) HQITHomeLoanViewModel *viewModel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIImageView *headerBgView;
@property (nonatomic, strong) UIImageView *logoView;
@property (nonatomic, strong) UILabel *brandLabel;
@property (nonatomic, strong) UIImageView *progressImageView;
@property (nonatomic, strong) UIImageView *hintBgView;
@property (nonatomic, strong) UIButton *hintCard;
@property (nonatomic, strong) UIView *hintInner;
@property (nonatomic, strong) UIImageView *hintIcon;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIImageView *hintArrow;
@property (nonatomic, strong) UIButton *contactCard;
@property (nonatomic, strong) UIButton *bankCard;
@property (nonatomic, strong) UIView *loanCard;
@property (nonatomic, strong) UILabel *loanTitleLabel;
@property (nonatomic, strong) UILabel *loanAmountLabel;
@property (nonatomic, strong) UILabel *rateBadgeLabel;
@property (nonatomic, strong) UILabel *termBadgeLabel;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, assign) BOOL didBindRefresh;
@property (nonatomic, assign) BOOL didAppearOnce;
@property (nonatomic, assign) BOOL needsPipelineRefreshOnAppear;
@property (nonatomic, assign) BOOL dialogChainRunning;
@property (nonatomic, strong, nullable) HQITBaseDialog *matchingDialog;
@property (nonatomic, assign) BOOL matchingRequesting;
@property (nonatomic, copy, nullable) void (^matchingCancel)(void);
@property (nonatomic, copy, nullable) dispatch_block_t matchingTimeoutBlock;
@property (nonatomic, assign) BOOL autoOrderKYCRetryScheduled;
@end

@implementation HQITHomeLoanViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = NO;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    self.viewModel = [[HQITHomeLoanViewModel alloc] init];
    [self buildUI];
    [self bindViewModel];
    [self.viewModel reloadForCurrentSession];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSUInteger count = self.navigationController.viewControllers.count;
    if (count == 1 && self.didAppearOnce && self.needsPipelineRefreshOnAppear) {
        self.needsPipelineRefreshOnAppear = NO;
        [self.viewModel reloadForCurrentSession];
    } else if (count == 1 && self.didAppearOnce) {
        [self.viewModel syncUserInfoOnHomeEnter];
    }
    self.didAppearOnce = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.didAppearOnce) {
        self.needsPipelineRefreshOnAppear = YES;
    }
}

#pragma mark - Bind

- (void)bindViewModel {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf refreshUI];
    };
    self.viewModel.onNeedLogin = ^{
        [[HQITAppShell shared] showLogin];
    };
    self.viewModel.onPipelineFinishedForDialogs = ^{
        if ([weakSelf tryStartAutoOrderAfterPipeline]) return;
        [weakSelf runDialogChain];
    };
    self.viewModel.onRoute = ^(NSString *route, NSDictionary *info) {
        [weakSelf handleRoute:route info:info];
    };
    if (!self.didBindRefresh) {
        self.didBindRefresh = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onHomeShouldRefresh)
                                                     name:HQITHomeShouldRefreshNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onKYCCompleted)
                                                     name:HQITKYCCompletedRefreshHomeNotification
                                                   object:nil];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onHomeShouldRefresh {
    self.needsPipelineRefreshOnAppear = NO;
    [self.viewModel reloadForCurrentSession];
}

- (void)onKYCCompleted {
    // Pending flag is set only when KYC truly finishes (HQITKYCNavigation).
    // Do not mark here — finishFlowFrom is also used on mid-flow exit.
    self.autoOrderKYCRetryScheduled = NO;
    NSLog(@"[HQITHome] KYCCompleted notification (pending=%d eligible=%d)",
          (int)[HQITHomeSessionState hasPendingAutoOrderAfterKYC],
          (int)self.viewModel.isAutoOrderEligible);
}

- (BOOL)tryStartAutoOrderAfterPipeline {
    BOOL pending = [HQITHomeSessionState hasPendingAutoOrderAfterKYC];
    BOOL eligible = self.viewModel.isAutoOrderEligible;
    NSLog(@"[HQITHome] tryAutoOrder after pipeline pending=%d eligible=%d",
          (int)pending, (int)eligible);
    if (!eligible) {
        // KYC just done but suphome may still lag (status/line not yet 20/system).
        if (pending && !self.autoOrderKYCRetryScheduled) {
            self.autoOrderKYCRetryScheduled = YES;
            NSLog(@"[HQITHome] pending auto-order but not eligible → retry pipeline in 1.5s");
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                if (![HQITHomeSessionState hasPendingAutoOrderAfterKYC]) return;
                if ([HQITAutoOrderCoordinator isRunning]) return;
                [self.viewModel reloadForCurrentSession];
            });
        }
        return NO;
    }
    if (![HQITHomeSessionState consumePendingAutoOrderAfterKYC]) {
        NSLog(@"[HQITHome] eligible but no KYC pending → skip auto-order (Apply can still trigger)");
        return NO;
    }
    self.autoOrderKYCRetryScheduled = NO;
    return [self startAutoOrderFlow];
}

- (BOOL)startAutoOrderFlow {
    if ([HQITAutoOrderCoordinator isRunning]) {
        NSLog(@"[HQITHome] startAutoOrder skipped: already running");
        return YES;
    }
    if (!self.viewModel.isAutoOrderEligible) {
        NSLog(@"[HQITHome] startAutoOrder skipped: not eligible");
        return NO;
    }
    self.dialogChainRunning = NO;
    NSLog(@"[HQITHome] startAutoOrderFlow");
    __weak typeof(self) weakSelf = self;
    [HQITAutoOrderCoordinator startWithHostViewController:self
                                               onFinished:^(BOOL success) {
        (void)success;
        if (!success && weakSelf.view.window) {
            // no-op
        }
    }];
    return YES;
}

- (void)refreshUI {
    self.hintLabel.text = self.viewModel.promptCopy;
    self.hintArrow.hidden = !self.viewModel.showsHintArrow;
    [self updateProgressImageForActiveIndex:self.viewModel.progressActiveIndex];
    self.loanAmountLabel.text = self.viewModel.maxApplyAmountDisplay.length
        ? self.viewModel.maxApplyAmountDisplay
        : @"₹0";
    [self refreshApplyButtonTitle];
}

- (void)refreshApplyButtonTitle {
    NSString *title = self.viewModel.homeActionButtonTitle ?: @"Apply Now";
    [self.applyButton setTitle:title forState:UIControlStateNormal];
}

#pragma mark - Colors / stretch

- (UIColor *)color102B4B {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)color333333 {
    return [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
}

- (UIColor *)colorC10A02 {
    return [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
}

- (UIImage *)imageNamed:(NSString *)name stretchBottom:(CGFloat)bottomStretch {
    UIImage *img = [UIImage imageNamed:name];
    if (!img) return nil;
    CGFloat h = MAX(img.size.height, 1);
    CGFloat top = MAX(h - bottomStretch, 0);
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(top, 0, 0, 0) resizingMode:UIImageResizingModeStretch];
}

- (UIImage *)imageNamedStretchFromCenter:(NSString *)name {
    UIImage *img = [UIImage imageNamed:name];
    if (!img) return nil;
    CGFloat w = MAX(img.size.width, 1);
    CGFloat h = MAX(img.size.height, 1);
    UIEdgeInsets insets = UIEdgeInsetsMake(floor(h * 0.5) - 1,
                                           floor(w * 0.5) - 1,
                                           floor(h * 0.5) - 1,
                                           floor(w * 0.5) - 1);
    return [img resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch];
}

#pragma mark - UI

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
    }];

    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];

    self.headerBgView = [[UIImageView alloc] init];
    self.headerBgView.image = [self imageNamed:@"Container _home" stretchBottom:40] ?: [UIImage imageNamed:@"Container _home"];
    self.headerBgView.contentMode = UIViewContentModeScaleToFill;
    self.headerBgView.clipsToBounds = YES;
    [self.contentView addSubview:self.headerBgView];

    self.logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"one_logo"]];
    self.logoView.contentMode = UIViewContentModeScaleAspectFit;
    self.logoView.layer.cornerRadius = 8;
    self.logoView.clipsToBounds = YES;
    [self.contentView addSubview:self.logoView];
    [self.logoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(16);
        make.top.equalTo(self.contentView.mas_safeAreaLayoutGuideTop).offset(6);
        make.width.height.mas_equalTo(53);
    }];

    self.brandLabel = [[UILabel alloc] init];
    NSString *displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
        ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
        ?: @"AKCash";
    self.brandLabel.text = displayName;
    self.brandLabel.textColor = [UIColor whiteColor];
    self.brandLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.contentView addSubview:self.brandLabel];
    [self.brandLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.logoView.mas_right).offset(3);
        make.centerY.equalTo(self.logoView);
    }];

    self.progressImageView = [[UIImageView alloc] init];
    self.progressImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.progressImageView];
    [self.progressImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(2);
        make.right.equalTo(self.contentView).offset(-2);
        make.top.equalTo(self.logoView.mas_bottom).offset(26);
        make.height.mas_equalTo(64);
    }];

    self.hintBgView = [[UIImageView alloc] init];
    self.hintBgView.image = [self imageNamedStretchFromCenter:@"for_bg"] ?: [UIImage imageNamed:@"for_bg"];
    self.hintBgView.contentMode = UIViewContentModeScaleToFill;
    [self.contentView addSubview:self.hintBgView];

    self.hintCard = [UIButton buttonWithType:UIButtonTypeCustom];
    self.hintCard.backgroundColor = [UIColor clearColor];
    [self.hintCard addTarget:self action:@selector(onHintTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.hintCard];
    [self.hintCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.top.equalTo(self.progressImageView.mas_bottom).offset(14);
    }];
    [self.hintBgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.hintCard);
    }];

    [self.headerBgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.contentView);
        make.bottom.equalTo(self.hintCard.mas_bottom);
    }];
    [self.contentView sendSubviewToBack:self.headerBgView];

    self.hintInner = [[UIView alloc] init];
    self.hintInner.backgroundColor = [UIColor whiteColor];
    self.hintInner.layer.cornerRadius = 16;
    self.hintInner.clipsToBounds = YES;
    self.hintInner.userInteractionEnabled = NO;
    [self.hintCard addSubview:self.hintInner];
    [self.hintInner mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.hintCard).insets(UIEdgeInsetsMake(6, 6, 6, 6));
    }];

    self.hintIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"being_icon"]];
    self.hintIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.hintInner addSubview:self.hintIcon];
    [self.hintIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.hintInner).offset(14);
        make.centerY.equalTo(self.hintInner);
        make.width.height.mas_equalTo(36);
    }];

    UIImage *arrowImg = [UIImage imageNamed:@"your_icon"] ?: [UIImage imageNamed:@"into_icon"];
    self.hintArrow = [[UIImageView alloc] initWithImage:arrowImg];
    self.hintArrow.contentMode = UIViewContentModeScaleAspectFit;
    [self.hintInner addSubview:self.hintArrow];
    [self.hintArrow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.hintInner).offset(-14);
        make.centerY.equalTo(self.hintInner);
        make.width.height.mas_equalTo(14);
    }];

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.numberOfLines = 0;
    // Doc §2.3.4 / §2.3.5: hint font 14
    self.hintLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.hintLabel.textColor = [self color333333];
    [self.hintInner addSubview:self.hintLabel];
    [self.hintLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.hintIcon.mas_right).offset(10);
        make.right.equalTo(self.hintArrow.mas_left).offset(-8);
        make.top.equalTo(self.hintInner).offset(14);
        make.bottom.equalTo(self.hintInner).offset(-14);
    }];

    self.contactCard = [self actionCardWithIcon:@"us_icon" title:@"Contact Us" action:@selector(onContactTapped)];
    self.bankCard = [self actionCardWithIcon:@"bank_icon" title:@"Bank Account" action:@selector(onBankTapped)];
    [self.contentView addSubview:self.contactCard];
    [self.contentView addSubview:self.bankCard];
    [self.contactCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(16);
        make.top.equalTo(self.hintCard.mas_bottom).offset(16);
        make.height.mas_equalTo(67);
    }];
    [self.bankCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-16);
        make.top.height.equalTo(self.contactCard);
        make.left.equalTo(self.contactCard.mas_right).offset(12);
        make.width.equalTo(self.contactCard);
    }];

    [self buildLoanCard];
    [self refreshUI];
}

- (void)buildLoanCard {
    self.loanCard = [[UIView alloc] init];
    self.loanCard.backgroundColor = [UIColor whiteColor];
    self.loanCard.layer.cornerRadius = 16;
    self.loanCard.layer.shadowColor = [UIColor blackColor].CGColor;
    self.loanCard.layer.shadowOpacity = 0.06;
    self.loanCard.layer.shadowRadius = 10;
    self.loanCard.layer.shadowOffset = CGSizeMake(0, 3);
    [self.contentView addSubview:self.loanCard];
    [self.loanCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contactCard.mas_bottom).offset(16);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.bottom.equalTo(self.contentView).offset(-24);
    }];

    self.loanTitleLabel = [[UILabel alloc] init];
    self.loanTitleLabel.text = @"Maximum Loan Amount";
    self.loanTitleLabel.font = [HQITFontHelper boldFontOfSize:16];
    self.loanTitleLabel.textColor = [self color102B4B];
    self.loanTitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.loanCard addSubview:self.loanTitleLabel];
    [self.loanTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.loanCard).offset(28);
        make.left.equalTo(self.loanCard).offset(16);
        make.right.equalTo(self.loanCard).offset(-16);
    }];

    self.loanAmountLabel = [[UILabel alloc] init];
    self.loanAmountLabel.text = @"₹0";
    self.loanAmountLabel.font = [HQITFontHelper boldFontOfSize:40];
    self.loanAmountLabel.textColor = [self colorC10A02];
    self.loanAmountLabel.textAlignment = NSTextAlignmentCenter;
    self.loanAmountLabel.adjustsFontSizeToFitWidth = YES;
    self.loanAmountLabel.minimumScaleFactor = 0.6;
    [self.loanCard addSubview:self.loanAmountLabel];
    [self.loanAmountLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.loanTitleLabel.mas_bottom).offset(12);
        make.left.equalTo(self.loanCard).offset(16);
        make.right.equalTo(self.loanCard).offset(-16);
    }];

    UIColor *badgeBg = [UIColor colorWithRed:0xFF/255.0 green:0xF0/255.0 blue:0xE6/255.0 alpha:1];
    UIColor *badgeText = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];

    self.rateBadgeLabel = [self loanBadgeLabelWithText:@"0.08%/Day" bg:badgeBg textColor:badgeText];
    self.termBadgeLabel = [self loanBadgeLabelWithText:@"150 Days" bg:badgeBg textColor:badgeText];

    UIStackView *badgeStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.rateBadgeLabel, self.termBadgeLabel]];
    badgeStack.axis = UILayoutConstraintAxisHorizontal;
    badgeStack.spacing = 10;
    badgeStack.alignment = UIStackViewAlignmentFill;
    badgeStack.distribution = UIStackViewDistributionFillEqually;
    [self.loanCard addSubview:badgeStack];
    [badgeStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.loanAmountLabel.mas_bottom).offset(16);
        make.left.equalTo(self.loanCard).offset(16);
        make.right.equalTo(self.loanCard).offset(-16);
        make.height.mas_equalTo(28);
    }];

    self.applyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.applyButton.clipsToBounds = YES;
    self.applyButton.layer.cornerRadius = 22;
    UIImage *bg = [self imageNamedStretchFromCenter:@"button_bg"] ?: [UIImage imageNamed:@"button_bg"];
    if (bg) {
        [self.applyButton setBackgroundImage:bg forState:UIControlStateNormal];
    } else {
        self.applyButton.backgroundColor = [self colorC10A02];
    }
    self.applyButton.titleLabel.font = [HQITFontHelper boldFontOfSize:16];
    [self.applyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.applyButton addTarget:self action:@selector(onApplyTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.loanCard addSubview:self.applyButton];
    [self.applyButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(badgeStack.mas_bottom).offset(28);
        make.left.equalTo(self.loanCard).offset(24);
        make.right.equalTo(self.loanCard).offset(-24);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.loanCard).offset(-28);
    }];
    [self refreshApplyButtonTitle];
}

- (UILabel *)loanBadgeLabelWithText:(NSString *)text bg:(UIColor *)bg textColor:(UIColor *)textColor {
    UILabel *lab = [[UILabel alloc] init];
    lab.text = [NSString stringWithFormat:@"  %@  ", text];
    lab.font = [HQITFontHelper mediumFontOfSize:12];
    lab.textColor = textColor;
    lab.backgroundColor = bg;
    lab.textAlignment = NSTextAlignmentCenter;
    lab.layer.cornerRadius = 6;
    lab.clipsToBounds = YES;
    return lab;
}

- (void)updateProgressImageForActiveIndex:(NSInteger)active {
    NSString *name = (active >= 2) ? @"pass_bg_1" : @"pass_bg_0";
    self.progressImageView.image = [UIImage imageNamed:name];
}

- (UIButton *)actionCardWithIcon:(NSString *)icon title:(NSString *)title action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.backgroundColor = [UIColor whiteColor];
    btn.layer.cornerRadius = 14;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.05;
    btn.layer.shadowRadius = 6;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:icon]];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.userInteractionEnabled = NO;
    [btn addSubview:iconView];
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(btn).offset(14);
        make.centerY.equalTo(btn);
        make.width.height.mas_equalTo(36);
    }];

    UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"into_icon"]];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    arrow.userInteractionEnabled = NO;
    [btn addSubview:arrow];
    [arrow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(btn).offset(-14);
        make.centerY.equalTo(btn);
        make.width.height.mas_equalTo(14);
    }];

    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = title;
    titleLab.font = [HQITFontHelper mediumFontOfSize:13];
    titleLab.textColor = [self color102B4B];
    titleLab.userInteractionEnabled = NO;
    titleLab.adjustsFontSizeToFitWidth = YES;
    titleLab.minimumScaleFactor = 0.85;
    [btn addSubview:titleLab];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(iconView.mas_right).offset(10);
        make.right.equalTo(arrow.mas_left).offset(-12);
        make.centerY.equalTo(btn);
    }];
    return btn;
}

#pragma mark - Dialog chain §2.4.1

- (void)runDialogChain {
    if (self.dialogChainRunning) return;
    if (![self isViewLoaded] || self.view.window == nil) {
        // Defer until visible
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.view.window) [self runDialogChain];
        });
        return;
    }
    self.dialogChainRunning = YES;
    [self stepVersionDialog];
}

- (void)stepVersionDialog {
    HQITHomeVersionInfo *ver = self.viewModel.versionInfo;
    if ([[HQITVersionUpdatePresenter shared] isForceUpdateShowing]) {
        [self stepWithdrawalDialog];
        return;
    }
    if (ver.needUpdate && ![HQITHomeSessionState hasShownVersionDialogThisLaunch]) {
        [HQITHomeSessionState markVersionDialogShownThisLaunch];
        __weak typeof(self) weakSelf = self;
        [[HQITVersionUpdatePresenter shared] showWithVersion:ver.latestVersion
                                                 forceUpdate:NO
                                                   updateURL:ver.updateURL
                                                      inView:self.view.window ?: self.view
                                                  onContinue:^{
            [weakSelf stepWithdrawalDialog];
        }];
        return;
    }
    [self stepWithdrawalDialog];
}

- (void)stepWithdrawalDialog {
    if (self.viewModel.userStatus == 32) {
        NSString *body = self.viewModel.promptCopy.length
            ? self.viewModel.promptCopy
            : @"You have a loan order pending confirmation. After entering the page to confirm, the funds will be transferred to your bank account immediately.";
        __weak typeof(self) weakSelf = self;
        [HQITDialogs showWhiteConfirmTitle:@"Pending"
                                      body:body
                                      icon:[UIImage imageNamed:@"have_icon"]
                             confirmTitle:@"Get loan"
                              cancelTitle:@"Cancel"
                                   inView:self.view.window ?: self.view
                                onConfirm:^{
            [weakSelf.viewModel handleWithdrawalConfirm];
        } onCancel:^{
            weakSelf.dialogChainRunning = NO;
        }];
        return;
    }
    self.dialogChainRunning = NO;
}

#pragma mark - Routes

- (void)handleRoute:(NSString *)route info:(NSDictionary *)info {
    if ([route isEqualToString:@"kyc_start"]) {
        [HQITKYCNavigation startFrom:self entry:HQITKYCEntryHome];
        return;
    }
    if ([route isEqualToString:@"kyc_step"]) {
        [HQITKYCNavigation startFrom:self entry:HQITKYCEntryHome];
        return;
    }
    if ([route isEqualToString:@"order_list"]) {
        NSInteger orderStatus = [info[@"orderStatus"] integerValue];
        UINavigationController *nav = self.tabBarController.viewControllers[1];
        HQITOrderHistoryViewController *orderVC = nil;
        if ([nav isKindOfClass:[UINavigationController class]]) {
            UIViewController *root = nav.viewControllers.firstObject;
            if ([root isKindOfClass:[HQITOrderHistoryViewController class]]) {
                orderVC = (HQITOrderHistoryViewController *)root;
            }
        }
        [orderVC selectOrderStatus:orderStatus];
        if ([nav isKindOfClass:[UINavigationController class]]) {
            [nav popToRootViewControllerAnimated:NO];
        }
        self.tabBarController.tabBar.hidden = NO;
        self.tabBarController.selectedIndex = 1;
        __weak HQITOrderHistoryViewController *weakOrder = orderVC;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakOrder selectOrderStatus:orderStatus];
        });
        return;
    }
    if ([route isEqualToString:@"accurate_recommendation"]) {
        [self beginAccurateRecommendationFlow];
        return;
    }
    if ([route isEqualToString:@"reject_h5"]) {
        if (![HQITRejectH5ViewController isRejectH5Configured]) return;
        NSString *url = info[@"url"];
        HQITRejectH5ViewController *vc =
            [[HQITRejectH5ViewController alloc] initWithPageURLString:url.length ? url : nil];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([route isEqualToString:@"contact_us"]) {
        HQITConfigWebViewController *vc =
            [HQITConfigWebViewController controllerWithHrefConfigKey:@"contactHref"
                                                           pageTitle:@"Contact Us"];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([route isEqualToString:@"bank_account"]) {
        HQITBankAccountViewController *vc = [[HQITBankAccountViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([route isEqualToString:@"withdrawal_detail"]) {
        NSString *orderId = info[@"orderId"] ?: @"1";
        NSString *productId = info[@"productId"];
        HQITWithdrawOrderDetailViewController *vc =
            [[HQITWithdrawOrderDetailViewController alloc] initWithOrderId:orderId productId:productId];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([route isEqualToString:@"auto_order"]) {
        [self startAutoOrderFlow];
        return;
    }
}

#pragma mark - Accurate recommendation

- (void)beginAccurateRecommendationFlow {
    if (self.matchingRequesting) return;
    self.matchingRequesting = YES;
    UIView *host = self.view.window ?: self.view;
    [self.matchingDialog dismissAnimated:NO];
    self.matchingDialog = [HQITDialogs showMatchingProgressInView:host];
    [self cancelMatchingTimeout];

    __weak typeof(self) weakSelf = self;
    self.matchingCancel = [[HQITNetworkClient shared]
                           requestCancellableWithEndpoint:@"/app/v3/product/dcRecommend"
                           signedData:@{}
                           unsignedData:nil
                           showLoading:@NO
                           showErrorToast:@NO
                           success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.matchingRequesting) return;
        [self finishMatchingWithRecommendData:response.data error:nil];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.matchingRequesting) return;
        [self finishMatchingWithRecommendData:nil error:error ?: [NSError errorWithDomain:@"HQITNetwork" code:0 userInfo:@{NSLocalizedDescriptionKey: message ?: @""}]];
    }];

    dispatch_block_t timeout = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.matchingRequesting) return;
        NSError *timeoutErr = [NSError errorWithDomain:@"HQITNetwork"
                                                  code:4102007
                                              userInfo:@{NSLocalizedDescriptionKey: @""}];
        [self finishMatchingWithRecommendData:nil error:timeoutErr];
    });
    self.matchingTimeoutBlock = timeout;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeout);
}

- (NSString *)hqit_currentPromptCopy {
    return self.viewModel.promptCopy ?: @"";
}

- (NSInteger)hqit_currentUserStatus {
    return self.viewModel.userStatus;
}

- (void)finishMatchingWithRecommendData:(id)data error:(NSError *)error {
    // Claim once: prevents timeout(4102007 empty) + late failure(other code → View Now) double-push.
    if (!self.matchingRequesting) {
        NSLog(@"[HQITHome] finishMatching ignored (already finished) err=%ld", (long)error.code);
        return;
    }
    self.matchingRequesting = NO;
    [self dismissMatchingDialog];
    if ([self hqit_currentUserStatus] == 51 && [HQITRejectH5ViewController isRejectH5Configured]) {
        NSString *url = [HQITRejectH5ViewController configuredPageURLString] ?: @"";
        HQITRejectH5ViewController *rejectVC =
            [[HQITRejectH5ViewController alloc] initWithPageURLString:url.length ? url : nil];
        [self.navigationController pushViewController:rejectVC animated:YES];
        [HQITClickGuard unlockControl:self.applyButton];
        [HQITClickGuard unlockControl:self.hintCard];
        return;
    }
    HQITAccurateRecommendationViewController *vc = nil;
    if (error) {
        NSString *msg = error.localizedDescription ?: @"";
        NSLog(@"[HQITHome] finishMatching error code=%ld → %@",
              (long)error.code, (error.code == 4102007) ? @"empty" : @"viewNow");
        vc = [[HQITAccurateRecommendationViewController alloc] initWithResultCode:error.code
                                                                         message:msg
                                                                  homePromptCopy:[self hqit_currentPromptCopy]
                                                                  homeUserStatus:[self hqit_currentUserStatus]];
    } else if (data != nil && [HQITAccurateRecommendViewModel hasProductsInRecommendData:data]) {
        vc = [[HQITAccurateRecommendationViewController alloc] initWithRecommendData:data];
    } else {
        NSLog(@"[HQITHome] finishMatching empty products");
        vc = [[HQITAccurateRecommendationViewController alloc] initWithEmptyState:YES];
    }
    [self.navigationController pushViewController:vc animated:YES];
    [HQITClickGuard unlockControl:self.applyButton];
    [HQITClickGuard unlockControl:self.hintCard];
}

- (void)cancelMatchingTimeout {
    if (self.matchingTimeoutBlock) {
        dispatch_block_cancel(self.matchingTimeoutBlock);
        self.matchingTimeoutBlock = nil;
    }
}

- (void)dismissMatchingDialog {
    [self cancelMatchingTimeout];
    void (^cancel)(void) = self.matchingCancel;
    self.matchingCancel = nil;
    if (cancel) cancel();
    HQITBaseDialog *dialog = self.matchingDialog;
    self.matchingDialog = nil;
    [dialog dismissAnimated:YES];
}

#pragma mark - Actions

- (void)onHintTapped {
    if (![HQITClickGuard tryLockControl:self.hintCard]) return;
    [self.viewModel handleHintTapped];
    [HQITClickGuard unlockControl:self.hintCard];
}

- (void)onContactTapped {
    if (![HQITClickGuard tryLockControl:self.contactCard]) return;
    [self.viewModel handleContactUsTapped];
}

- (void)onBankTapped {
    if (![HQITClickGuard tryLockControl:self.bankCard]) return;
    [self.viewModel handleBankAccountTapped];
}

- (void)onApplyTapped {
    if (![HQITClickGuard tryLockControl:self.applyButton]) return;
    [self.viewModel handleApplyTapped];
    [HQITClickGuard unlockControl:self.applyButton];
}

@end
