

#import "HQITAccurateRecommendationViewController.h"
#import "HQITAccurateRecommendViewModel.h"
#import "HQITAccurateRecommendProductCell.h"
#import "HQITFontHelper.h"
#import "HQITNavigationBarStyle.h"
#import "HQITHUDHelper.h"
#import "HQITClickGuard.h"
#import "HQITDialogs.h"
#import "HQITAppStartupManager.h"
#import "HQITPermissionSecondaryPresenter.h"
#import "HQITBuryRecorder.h"
#import "HQITAppShell.h"
#import "HQITHomeLoanViewController.h"
#import "HQITOrderDataCaptureCoordinator.h"
#import "HQITAccurateRecommendSuccessViewController.h"
#import "HQITOrderHistoryViewController.h"
#import "HQITConfigWebViewController.h"
#import "HQITSigningHelper.h"
#import "HQITStorageKeys.h"
#import <Masonry/Masonry.h>
#import <CoreLocation/CoreLocation.h>

static NSString * const kHQITAccurateRecommendCellId = @"HQITAccurateRecommendProductCell";

@interface HQITRecommendListTableView : UITableView
@end

@implementation HQITRecommendListTableView
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ([view isKindOfClass:[UISlider class]]) return NO;
    return [super touchesShouldCancelInContentView:view];
}
@end

typedef NS_ENUM(NSInteger, HQITAccurateRecommendPageKind) {
    HQITAccurateRecommendPageList = 0,
    HQITAccurateRecommendPageEmptyNoProduct = 1,
    HQITAccurateRecommendPageErrorViewNow = 2,
    HQITAccurateRecommendPageErrorFail = 3,
};

@interface HQITAccurateRecommendationViewController () <UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate>
@property (nonatomic, assign) HQITAccurateRecommendPageKind pageKind;
@property (nonatomic, assign) BOOL emptyState;
@property (nonatomic, assign) NSInteger errorResultCode;
@property (nonatomic, copy, nullable) NSString *errorMessage;
@property (nonatomic, copy, nullable) NSString *homePromptCopy;
@property (nonatomic, assign) NSInteger homeUserStatus;
@property (nonatomic, strong, nullable) id recommendData;
@property (nonatomic, strong, nullable) HQITAccurateRecommendViewModel *viewModel;

@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;

@property (nonatomic, strong, nullable) UIView *messageCard;
@property (nonatomic, strong, nullable) UILabel *messageLabel;
@property (nonatomic, strong, nullable) UIImageView *emptyImageView;
@property (nonatomic, strong, nullable) UIButton *viewNowButton;

@property (nonatomic, strong, nullable) UITableView *tableView;
@property (nonatomic, strong, nullable) UIView *tableFooter;
@property (nonatomic, strong, nullable) UILabel *totalAmountValue;
@property (nonatomic, strong, nullable) UILabel *totalFeeValue;
@property (nonatomic, strong, nullable) UILabel *totalArrivalValue;
@property (nonatomic, strong, nullable) UIView *bankRow;
@property (nonatomic, strong, nullable) UILabel *bankLabel;

@property (nonatomic, strong, nullable) UIView *bottomBar;
@property (nonatomic, strong, nullable) UIButton *agreeCheckButton;
@property (nonatomic, strong, nullable) UILabel *agreeLabel;
@property (nonatomic, strong, nullable) UIButton *applyButton;

@property (nonatomic, strong, nullable) CLLocationManager *locationManager;
@property (nonatomic, copy, nullable) void (^locationCompletion)(NSString *lng, NSString *lat, BOOL cancelled);
@property (nonatomic, assign) BOOL awaitingFirstAuthResult;
@property (nonatomic, strong, nullable) NSTimer *locationTimeoutTimer;
@property (nonatomic, assign) BOOL isLocating;
@end

@implementation HQITAccurateRecommendationViewController

- (instancetype)initWithEmptyState:(BOOL)emptyState {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _emptyState = emptyState;
        _pageKind = emptyState ? HQITAccurateRecommendPageEmptyNoProduct : HQITAccurateRecommendPageList;
    }
    return self;
}

- (instancetype)initWithResultCode:(NSInteger)resultCode message:(NSString *)message {
    return [self initWithResultCode:resultCode message:message homePromptCopy:nil homeUserStatus:0];
}

- (instancetype)initWithResultCode:(NSInteger)resultCode
                           message:(NSString *)message
                    homePromptCopy:(NSString *)homePromptCopy
                    homeUserStatus:(NSInteger)homeUserStatus {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _emptyState = YES;
        _errorResultCode = resultCode;
        _errorMessage = [message copy];
        _homePromptCopy = [homePromptCopy copy];
        _homeUserStatus = homeUserStatus;
        if (resultCode == 4102007) {
            _pageKind = HQITAccurateRecommendPageEmptyNoProduct;
        } else {
            _pageKind = HQITAccurateRecommendPageErrorViewNow;
        }
    }
    return self;
}

- (instancetype)initWithRecommendData:(id)data {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _emptyState = NO;
        _pageKind = HQITAccurateRecommendPageList;
        _recommendData = data;
        _viewModel = [[HQITAccurateRecommendViewModel alloc] initWithRecommendData:data];
        if (_viewModel.products.count == 0) {
            _emptyState = YES;
            _pageKind = HQITAccurateRecommendPageEmptyNoProduct;
            _viewModel = nil;
        }
    }
    return self;
}

- (instancetype)init {
    return [self initWithEmptyState:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildNav];
    if (self.pageKind == HQITAccurateRecommendPageList) {
        self.navTitleLabel.text = @"Select loan amount";
        [self bindViewModel];
        [self buildListUI];
        [self refreshFooterAndBottom];
    } else {
        self.navTitleLabel.text = @"Accurate Recommendation";
        [self buildEmptyOrErrorContent];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    if (self.pageKind != HQITAccurateRecommendPageList) return;
    if (!self.viewModel.isSubmitting && self.isLocating && !self.locationCompletion) {
        self.isLocating = NO;
        [self clearLocationTimeout];
    }
    if (!self.viewModel.isSubmitting && !self.isLocating) {
        self.applyButton.enabled = YES;
        self.applyButton.alpha = 1.0;
        [self refreshFooterAndBottom];
    }
    if (self.bottomBar) [self.view bringSubviewToFront:self.bottomBar];
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
    if (self.tableFooter) {
        [self.tableFooter setNeedsLayout];
        [self.tableFooter layoutIfNeeded];
        CGSize size = [self.tableFooter systemLayoutSizeFittingSize:CGSizeMake(w, UILayoutFittingCompressedSize.height)];
        CGRect frame = self.tableFooter.frame;
        if (fabs(frame.size.height - size.height) > 0.5) {
            frame.size.height = size.height;
            self.tableFooter.frame = frame;
            self.tableView.tableFooterView = self.tableFooter;
        }
    }
}

#pragma mark - Bind

- (void)bindViewModel {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf refreshVisibleProductCells];
        [weakSelf refreshFooterAndBottom];
    };
    self.viewModel.onErrorMessage = ^(NSString *message) {
        [HQITHUDHelper showToast:message];
        weakSelf.isLocating = NO;
        [HQITClickGuard unlockControl:weakSelf.applyButton];
        [weakSelf refreshFooterAndBottom];
    };
    self.viewModel.onSubmitSuccess = ^(NSArray<NSString *> *orderIds) {
        [weakSelf startCaptureWithOrderIds:orderIds];
    };
}

#pragma mark - Nav

- (void)buildNav {
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
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];
}

#pragma mark - Empty / Error

- (void)buildEmptyOrErrorContent {
    self.messageCard = [[UIView alloc] init];
    self.messageCard.backgroundColor = [UIColor whiteColor];
    self.messageCard.layer.cornerRadius = 14;
    self.messageCard.layer.shadowColor = [UIColor blackColor].CGColor;
    self.messageCard.layer.shadowOpacity = 0.05;
    self.messageCard.layer.shadowRadius = 8;
    self.messageCard.layer.shadowOffset = CGSizeMake(0, 2);
    [self.view addSubview:self.messageCard];
    [self.messageCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(16);
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
    }];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.attributedText = [self attributedTipMessage:[self displayMessageForCurrentPage]];
    [self.messageCard addSubview:self.messageLabel];
    [self.messageLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.messageCard).insets(UIEdgeInsetsMake(16, 16, 16, 16));
    }];

    BOOL isViewNow = (self.pageKind == HQITAccurateRecommendPageErrorViewNow);
    BOOL isFailPage = (self.pageKind == HQITAccurateRecommendPageErrorFail);
    NSString *iconName = @"notuijie_icon";
    CGFloat iconSize = 170;
    CGFloat iconWidth = 200;
    if (isFailPage) {
        iconName = @"jctjsb_icon";
        iconSize = 56;
        iconWidth = 56;
    } else if (isViewNow) {
        iconName = @"dhktb_icon";
        iconSize = 56;
        iconWidth = 56;
    }

    self.emptyImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:iconName]];
    self.emptyImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.emptyImageView];
    [self.emptyImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.width.mas_equalTo(iconWidth);
        make.height.mas_equalTo(iconSize);
        if (isFailPage) {
            make.top.equalTo(self.messageCard.mas_bottom).offset(26);
        } else if (isViewNow) {
            make.top.equalTo(self.messageCard.mas_bottom).offset(40);
        } else {
            make.centerY.equalTo(self.view).offset(24);
        }
    }];

    if (isViewNow) {
        self.viewNowButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.viewNowButton.clipsToBounds = YES;
        self.viewNowButton.layer.cornerRadius = 10;
        UIImage *bg = [UIImage imageNamed:@"button_bg"];
        if (bg) {
            CGFloat bw = MAX(bg.size.width, 1), bh = MAX(bg.size.height, 1);
            [self.viewNowButton setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                      resizingMode:UIImageResizingModeStretch]
                                          forState:UIControlStateNormal];
        } else {
            self.viewNowButton.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
        }
        self.viewNowButton.titleLabel.font = [HQITFontHelper boldFontOfSize:16];
        [self.viewNowButton setTitle:@"View Now" forState:UIControlStateNormal];
        [self.viewNowButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.viewNowButton addTarget:self action:@selector(onViewNowTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.viewNowButton];
        [self.viewNowButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.emptyImageView.mas_bottom).offset(28);
            make.left.equalTo(self.view).offset(48);
            make.right.equalTo(self.view).offset(-48);
            make.height.mas_equalTo(42);
        }];
    }
}

- (NSAttributedString *)attributedTipMessage:(NSString *)text {
    NSString *body = text.length ? text : @"";
    UIFont *font = [HQITFontHelper regularFontOfSize:14];
    UIColor *color = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.minimumLineHeight = 22;
    ps.maximumLineHeight = 22;
    ps.alignment = NSTextAlignmentLeft;
    return [[NSAttributedString alloc] initWithString:body attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: ps,
    }];
}

- (NSString *)displayMessageForCurrentPage {
    static NSString * const kHQITRecommendNoProductMsg =
        @"You do not currently meet the requirements for this product. Once a more suitable loan product becomes available, we will notify you through the app. Please stay tuned.";

    if (self.pageKind == HQITAccurateRecommendPageErrorViewNow) {
        NSString *homeTip = [self.homePromptCopy stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (homeTip.length) return homeTip;
        NSString *fallback = [self.errorMessage stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return fallback.length ? fallback : kHQITRecommendNoProductMsg;
    }

    NSString *msg = [self.errorMessage stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (msg.length) return msg;
    return kHQITRecommendNoProductMsg;
}

- (NSInteger)orderListStatusForHomeUserStatus:(NSInteger)status {
    if (status == 80 || status == 81) return 20;
    if (status == 41 || status == 32 || status == 30) return 10;
    return 30;
}

- (NSInteger)hqit_homeUserStatusForViewNow {
    if (self.homeUserStatus > 0) return self.homeUserStatus;
    NSInteger cached = [[NSUserDefaults standardUserDefaults] integerForKey:HQITStorageKeyUserStatus];
    return cached > 0 ? cached : 0;
}

- (void)onViewNowTapped {
    if (![HQITClickGuard tryLockControl:self.viewNowButton]) return;

    UITabBarController *tab = self.tabBarController;
    if (!tab) {
        UIViewController *root = [HQITAppShell shared].window.rootViewController;
        if ([root isKindOfClass:[UITabBarController class]]) {
            tab = (UITabBarController *)root;
        }
    }
    UINavigationController *homeNav = self.navigationController;

    NSInteger homeStatus = [self hqit_homeUserStatusForViewNow];
    NSInteger orderStatus = [self orderListStatusForHomeUserStatus:homeStatus];
    NSLog(@"[HQITAccurateRecommend] ViewNow homeUserStatus=%ld → orderStatus=%ld",
          (long)homeStatus, (long)orderStatus);

    if (tab && tab.viewControllers.count > 1) {
        UINavigationController *orderNav = tab.viewControllers[1];
        HQITOrderHistoryViewController *orderVC = nil;
        if ([orderNav isKindOfClass:[UINavigationController class]]) {
            UIViewController *root = orderNav.viewControllers.firstObject;
            if ([root isKindOfClass:[HQITOrderHistoryViewController class]]) {
                orderVC = (HQITOrderHistoryViewController *)root;
            }
        }
        [orderVC selectOrderStatus:orderStatus];
        if ([orderNav isKindOfClass:[UINavigationController class]]) {
            [orderNav popToRootViewControllerAnimated:NO];
        }
        [homeNav popToRootViewControllerAnimated:NO];
        tab.tabBar.hidden = NO;
        tab.selectedIndex = 1;
        __weak HQITOrderHistoryViewController *weakOrder = orderVC;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakOrder selectOrderStatus:orderStatus];
        });
    } else {
        [homeNav popViewControllerAnimated:YES];
    }
    [HQITClickGuard unlockControl:self.viewNowButton];
}

#pragma mark - List

- (void)buildListUI {
    [self buildBottomBar];

    self.tableView = [[HQITRecommendListTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.estimatedRowHeight = 320;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.delaysContentTouches = NO;
    self.tableView.canCancelContentTouches = YES;
    [self.tableView registerClass:[HQITAccurateRecommendProductCell class] forCellReuseIdentifier:kHQITAccurateRecommendCellId];
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.bottomBar.mas_top);
    }];

    [self buildTableFooter];
    self.tableView.tableFooterView = self.tableFooter;
    [self.view bringSubviewToFront:self.bottomBar];
}

- (void)buildBottomBar {
    self.bottomBar = [[UIView alloc] init];
    self.bottomBar.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    self.bottomBar.userInteractionEnabled = YES;
    [self.view addSubview:self.bottomBar];
    [self.bottomBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.view);
    }];

    self.agreeCheckButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.agreeCheckButton addTarget:self action:@selector(onAgreeCheckTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.agreeCheckButton];
    self.agreeLabel = [[UILabel alloc] init];
    self.agreeLabel.numberOfLines = 0;
    self.agreeLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTermsLinkTapped)];
    [self.agreeLabel addGestureRecognizer:tap];
    [self.bottomBar addSubview:self.agreeLabel];
    [self.agreeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.bottomBar).offset(4);
        make.left.equalTo(self.bottomBar).offset(16 + 24 + 8);
        make.right.equalTo(self.bottomBar).offset(-16);
    }];

    [self.agreeCheckButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomBar).offset(16);
        make.centerY.equalTo(self.agreeLabel);
        make.width.height.mas_equalTo(24);
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
        self.applyButton.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
    }
    self.applyButton.titleLabel.font = [HQITFontHelper boldFontOfSize:16];
    [self.applyButton setTitle:@"Apply Now" forState:UIControlStateNormal];
    [self.applyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.applyButton addTarget:self action:@selector(onApplyTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.applyButton];
    [self.applyButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.agreeLabel.mas_bottom).offset(12);
        make.left.equalTo(self.bottomBar).offset(16);
        make.right.equalTo(self.bottomBar).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.bottomBar.mas_safeAreaLayoutGuideBottom).offset(-12);
    }];

    [self refreshAgreeUI];
}

- (void)buildTableFooter {
    self.tableFooter = [[UIView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 1)];

    UIView *summaryCard = [[UIView alloc] init];
    summaryCard.backgroundColor = [UIColor whiteColor];
    summaryCard.layer.cornerRadius = 14;
    summaryCard.layer.shadowColor = [UIColor blackColor].CGColor;
    summaryCard.layer.shadowOpacity = 0.05;
    summaryCard.layer.shadowRadius = 8;
    summaryCard.layer.shadowOffset = CGSizeMake(0, 2);
    [self.tableFooter addSubview:summaryCard];
    [summaryCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.tableFooter).offset(8);
        make.left.equalTo(self.tableFooter).offset(16);
        make.right.equalTo(self.tableFooter).offset(-16);
    }];

    UILabel *taTitle = [self summaryTitle:@"Total amount"];
    self.totalAmountValue = [self summaryValueEmphasized:YES];
    UILabel *tfTitle = [self summaryTitle:@"Total fee"];
    self.totalFeeValue = [self summaryValueEmphasized:NO];
    UILabel *arTitle = [self summaryTitle:@"Amount received"];
    self.totalArrivalValue = [self summaryValueEmphasized:NO];
    [summaryCard addSubview:taTitle];
    [summaryCard addSubview:self.totalAmountValue];
    [summaryCard addSubview:tfTitle];
    [summaryCard addSubview:self.totalFeeValue];
    [summaryCard addSubview:arTitle];
    [summaryCard addSubview:self.totalArrivalValue];

    [taTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(summaryCard).offset(16);
        make.left.equalTo(summaryCard).offset(16);
    }];
    [self.totalAmountValue mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(taTitle);
        make.right.equalTo(summaryCard).offset(-16);
    }];
    [tfTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(taTitle.mas_bottom).offset(12);
        make.left.equalTo(summaryCard).offset(16);
    }];
    [self.totalFeeValue mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(tfTitle);
        make.right.equalTo(summaryCard).offset(-16);
    }];
    [arTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(tfTitle.mas_bottom).offset(12);
        make.left.equalTo(summaryCard).offset(16);
        make.bottom.equalTo(summaryCard).offset(-16);
    }];
    [self.totalArrivalValue mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(arTitle);
        make.right.equalTo(summaryCard).offset(-16);
    }];

    self.bankRow = [[UIView alloc] init];
    self.bankRow.backgroundColor = [UIColor whiteColor];
    self.bankRow.layer.cornerRadius = 16;
    self.bankRow.clipsToBounds = YES;
    [self.tableFooter addSubview:self.bankRow];
    [self.bankRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(summaryCard.mas_bottom).offset(12);
        make.left.equalTo(self.tableFooter).offset(16);
        make.right.equalTo(self.tableFooter).offset(-16);
        make.height.mas_equalTo(48);
    }];
    UIImageView *bankIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bank_icon"] ?: [UIImage imageNamed:@"bank_icon_b"]];
    bankIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.bankRow addSubview:bankIcon];
    [bankIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bankRow).offset(14);
        make.centerY.equalTo(self.bankRow);
        make.width.height.mas_equalTo(20);
    }];
    self.bankLabel = [[UILabel alloc] init];
    self.bankLabel.font = [HQITFontHelper regularFontOfSize:13];
    self.bankLabel.textColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
    [self.bankRow addSubview:self.bankLabel];
    [self.bankLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(bankIcon.mas_right).offset(8);
        make.centerY.equalTo(self.bankRow);
        make.right.lessThanOrEqualTo(self.bankRow).offset(-14);
    }];

    UIView *tipBox = [[UIView alloc] init];
    tipBox.backgroundColor = [UIColor colorWithRed:0xFF/255.0 green:0xF8/255.0 blue:0xEE/255.0 alpha:1];
    tipBox.layer.cornerRadius = 10;
    [self.tableFooter addSubview:tipBox];
    [tipBox mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.bankRow.mas_bottom).offset(12);
        make.left.equalTo(self.tableFooter).offset(16);
        make.right.equalTo(self.tableFooter).offset(-16);
        make.bottom.equalTo(self.tableFooter).offset(-16);
    }];

    UIImageView *infoIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"with_icon"]];
    infoIcon.contentMode = UIViewContentModeScaleAspectFit;
    [tipBox addSubview:infoIcon];
    [infoIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tipBox).offset(12);
        make.top.equalTo(tipBox).offset(12);
        make.width.height.mas_equalTo(16);
    }];

    UILabel *tip = [[UILabel alloc] init];
    tip.numberOfLines = 0;
    tip.font = [HQITFontHelper regularFontOfSize:12];
    tip.textColor = [UIColor colorWithRed:0xB8/255.0 green:0x7A/255.0 blue:0x3A/255.0 alpha:1];
    tip.text = @"These loan details are based on the information you provided and may be updated based on your final loan eligibility.";
    [tipBox addSubview:tip];
    [tip mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(tipBox).offset(10);
        make.left.equalTo(infoIcon.mas_right).offset(8);
        make.right.equalTo(tipBox).offset(-12);
        make.bottom.equalTo(tipBox).offset(-10);
    }];
}

- (UILabel *)summaryTitle:(NSString *)text {
    UILabel *lab = [[UILabel alloc] init];
    lab.text = text;
    BOOL total = [text isEqualToString:@"Total amount"];
    lab.font = total ? [HQITFontHelper boldFontOfSize:14] : [HQITFontHelper regularFontOfSize:14];
    lab.textColor = total
        ? [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1]
        : [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    return lab;
}

- (UILabel *)summaryValueEmphasized:(BOOL)emphasized {
    UILabel *lab = [[UILabel alloc] init];
    lab.font = emphasized
        ? [HQITFontHelper fontWithSize:20 weight:HQITFontWeightBold italic:YES]
        : [HQITFontHelper regularFontOfSize:14];
    lab.textColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    lab.textAlignment = NSTextAlignmentRight;
    return lab;
}

- (void)refreshFooterAndBottom {
    self.totalAmountValue.text = self.viewModel.totalAmountDisplay;
    self.totalFeeValue.text = self.viewModel.totalFeeDisplay;
    self.totalArrivalValue.text = self.viewModel.totalArrivalDisplay;
    BOOL showBank = self.viewModel.hasBankCard;
    self.bankRow.hidden = !showBank;
    self.bankLabel.text = self.viewModel.maskedBankAccount ?: @"";
    [self.bankRow mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(showBank ? 48 : 0);
    }];
    [self refreshAgreeUI];
    BOOL busy = self.viewModel.isSubmitting || self.isLocating;
    BOOL can = [self.viewModel canApply] && !busy;
    self.applyButton.enabled = can;
    self.applyButton.alpha = can ? 1.0 : 0.5;
    [self.view setNeedsLayout];
}

- (void)refreshAgreeUI {
    BOOL on = self.viewModel.agreed;
    UIImage *icon = [UIImage imageNamed:on ? @"read_icon" : @"and_icon"];
    [self.agreeCheckButton setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                           forState:UIControlStateNormal];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"I have read and agreed with the " attributes:@{
        NSFontAttributeName: [HQITFontHelper regularFontOfSize:12],
        NSForegroundColorAttributeName: [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1],
    }];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"'Terms Of The Loan'" attributes:@{
        NSFontAttributeName: [HQITFontHelper regularFontOfSize:12],
        NSForegroundColorAttributeName: [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1],
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
    }]];
    self.agreeLabel.attributedText = text;
}

#pragma mark - UITableView

- (void)refreshVisibleProductCells {
    for (NSIndexPath *ip in self.tableView.indexPathsForVisibleRows) {
        if (ip.row < 0 || ip.row >= (NSInteger)self.viewModel.products.count) continue;
        HQITAccurateRecommendProductCell *cell = [self.tableView cellForRowAtIndexPath:ip];
        if (![cell isKindOfClass:[HQITAccurateRecommendProductCell class]]) continue;
        [cell configureWithItem:self.viewModel.products[ip.row]];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.viewModel.products.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HQITAccurateRecommendProductCell *cell = [tableView dequeueReusableCellWithIdentifier:kHQITAccurateRecommendCellId forIndexPath:indexPath];
    HQITAccurateRecommendProductItem *item = self.viewModel.products[indexPath.row];
    [cell configureWithItem:item];
    __weak typeof(self) weakSelf = self;
    NSInteger idx = indexPath.row;
    cell.onToggleSelect = ^{
        [weakSelf.viewModel toggleProductSelectedAtIndex:idx];
    };
    cell.onAmountStepChanged = ^(NSInteger stepIndex) {
        [weakSelf.viewModel setAmountStepIndex:stepIndex forProductAtIndex:idx];
    };
    cell.onTermSelect = ^{
        [weakSelf showTermSelectForProductAtIndex:idx];
    };
    cell.onLoanDetails = ^{
        [weakSelf showLoanDetailsForProductAtIndex:idx];
    };
    return cell;
}

- (void)showTermSelectForProductAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.viewModel.products.count) return;
    HQITAccurateRecommendProductItem *item = self.viewModel.products[index];
    if (!item.isMultiTerm) return;
    NSArray *labels = [item termOptionLabels];
    if (labels.count == 0) return;
    NSMutableArray *opts = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)labels.count; i++) {
        [opts addObject:[HQITSelectionOption optionWithKey:[NSString stringWithFormat:@"%ld", (long)i] label:labels[i]]];
    }
    NSString *selected = [NSString stringWithFormat:@"%ld", (long)item.selectedTermIndex];
    __weak typeof(self) weakSelf = self;
    [HQITDialogs showSelectionTitle:[item termSelectTitle]
                            options:opts
                        selectedKey:selected
                             inView:self.view.window ?: self.view
                         onConfirm:^(HQITSelectionOption *option) {
        [weakSelf.viewModel selectTermAtIndex:option.key.integerValue forProductAtIndex:index];
    } onCancel:nil];
}

- (void)showLoanDetailsForProductAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.viewModel.products.count) return;
    HQITAccurateRecommendProductItem *item = self.viewModel.products[index];
    NSArray *rows = [item loanDetailRows];
    UIView *host = self.view.window ?: self.view;
    [HQITDialogs showLoanDetailsRows:rows inView:host onCancel:nil];
}

#pragma mark - Actions

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onAgreeCheckTapped {
    self.viewModel.agreed = !self.viewModel.agreed;
    [self refreshFooterAndBottom];
}

- (void)onTermsLinkTapped {
    HQITConfigWebViewController *web =
        [HQITConfigWebViewController controllerWithHrefConfigKey:@"conditionsHref"
                                                       pageTitle:@"Terms Of The Loan"];
    [self.navigationController pushViewController:web animated:YES];
}

- (void)onApplyTapped {
    NSLog(@"[HQITAccurateRecommend] onApplyTapped locating=%d submitting=%d selected=%ld agreed=%d force=%d",
          self.isLocating, self.viewModel.isSubmitting,
          (long)[self.viewModel selectedProductCount], self.viewModel.agreed, [self isForceLocation]);
    if (self.viewModel.isSubmitting || self.isLocating) return;
    if ([self.viewModel selectedProductCount] == 0) {
        [HQITHUDHelper showToast:@"Please select at least one product"];
        return;
    }
    if (!self.viewModel.agreed) {
        [HQITHUDHelper showToast:@"Please agree to the Terms Of The Loan before applying."];
        return;
    }
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
            [self.locationManager stopUpdatingLocation];
            BOOL force = [self isForceLocation];
            BOOL placeholder = [lng isEqualToString:@"-360.000000"] || [lat isEqualToString:@"-360.000000"];
            if (cancelled || (force && (lng.length == 0 || lat.length == 0 || placeholder))) {
                NSLog(@"[HQITAccurateRecommend] apply aborted cancelled=%d force=%d lng=%@ lat=%@",
                      cancelled, force, lng, lat);
                [self.viewModel resetSubmittingState];
                self.applyButton.enabled = YES;
                self.applyButton.alpha = 1.0;
                [self refreshFooterAndBottom];
                return;
            }
            [self.viewModel submitWithLongitude:lng latitude:lat];
        }];
    }];
}

- (void)startCaptureWithOrderIds:(NSArray<NSString *> *)orderIds {
    NSString *firstOrderId = orderIds.firstObject ?: @"";
    NSArray<NSString *> *allIds = [orderIds copy] ?: @[];
    __weak typeof(self) weakSelf = self;
    [HQITOrderDataCaptureCoordinator startWithOrderId:firstOrderId
                                   hostViewController:self
                                           completion:^(BOOL success) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!success) {
            [self.viewModel resetSubmittingState];
            self.isLocating = NO;
            [HQITClickGuard unlockControl:self.applyButton];
            [self refreshFooterAndBottom];
            return;
        }
        [self replaceWithSuccessPageOrderIds:allIds];
    }];
}

- (void)replaceWithSuccessPageOrderIds:(NSArray<NSString *> *)orderIds {
    HQITAccurateRecommendSuccessViewController *success =
        [[HQITAccurateRecommendSuccessViewController alloc] initWithOrderIds:orderIds ?: @[]];
    NSMutableArray *stack = [self.navigationController.viewControllers mutableCopy] ?: [NSMutableArray array];
    if (stack.count > 0) {
        [stack removeLastObject];
    }
    [stack addObject:success];
    [self.navigationController setViewControllers:stack animated:YES];
}

#pragma mark - Location

- (BOOL)isForceLocation {
    HQITAppStartupManager *mgr = [HQITAppStartupManager shared];
    BOOL force = [mgr isForceContactMode];
    NSLog(@"[HQITAccurateRecommend] retrieveMobileContact=%@ → force=%d",
          [mgr configValueForKey:@"retrieveMobileContact"], force);
    return force;
}

- (void)resolveLocationThen:(void (^)(NSString *lng, NSString *lat, BOOL cancelled))completion {
    self.locationCompletion = [completion copy];
    self.awaitingFirstAuthResult = NO;
    BOOL force = [self isForceLocation];
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        self.locationManager.distanceFilter = kCLDistanceFilterNone;
    }
    status = self.locationManager.authorizationStatus;
    NSLog(@"[HQITAccurateRecommend] resolveLocation force=%d status=%d", force, (int)status);
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        [HQITBuryRecorder recordLocationPermissionGranted:YES]; // 15
        [self startLocationUpdates];
        return;
    }
    if (status == kCLAuthorizationStatusNotDetermined) {
        self.awaitingFirstAuthResult = YES;
        [self startLocationTimeoutWithSeconds:20.0];
        [self.locationManager requestWhenInUseAuthorization];
        return;
    }
    [HQITBuryRecorder recordLocationPermissionGranted:NO]; // 16
    if (force) {
        NSLog(@"[HQITAccurateRecommend] force already denied → secondary location dialog");
        [self presentForceLocationGuideThenCancel];
    } else {
        if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
        self.locationCompletion = nil;
    }
}

- (void)startLocationUpdates {
    [self startLocationTimeoutWithSeconds:20.0];
    CLLocation *cached = self.locationManager.location;
    if (cached && cached.horizontalAccuracy > 0 && cached.horizontalAccuracy < 5000) {
        NSTimeInterval age = -[cached.timestamp timeIntervalSinceNow];
        if (age >= 0 && age < 600) {
            NSString *lng = [HQITSigningHelper coordinateSignValue:cached.coordinate.longitude];
            NSString *lat = [HQITSigningHelper coordinateSignValue:cached.coordinate.latitude];
            NSLog(@"[HQITAccurateRecommend] use cached location lng=%@ lat=%@ acc=%.0f age=%.0fs",
                  lng, lat, cached.horizontalAccuracy, age);
            [self clearLocationTimeout];
            if (self.locationCompletion) self.locationCompletion(lng, lat, NO);
            self.locationCompletion = nil;
            return;
        }
    }
    NSLog(@"[HQITAccurateRecommend] startUpdatingLocation (no usable cache)");
    [self.locationManager stopUpdatingLocation];
    [self.locationManager startUpdatingLocation];
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

- (void)startLocationTimeoutWithSeconds:(NSTimeInterval)seconds {
    [self clearLocationTimeout];
    __weak typeof(self) weakSelf = self;
    self.locationTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:seconds repeats:NO block:^(NSTimer *timer) {
        NSLog(@"[HQITAccurateRecommend] location timeout %.0fs", seconds);
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
    if (!self.awaitingFirstAuthResult) return;
    BOOL force = [self isForceLocation];
    NSLog(@"[HQITAccurateRecommend] auth changed status=%d force=%d", (int)status, force);
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        self.awaitingFirstAuthResult = NO;
        [HQITBuryRecorder recordLocationPermissionGranted:YES]; // 15
        [self startLocationUpdates];
        return;
    }
    [self clearLocationTimeout];
    self.awaitingFirstAuthResult = NO;
    [HQITBuryRecorder recordLocationPermissionGranted:NO]; // 16
    if (force) {
        NSLog(@"[HQITAccurateRecommend] force first system deny → stay on page, end round");
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        self.locationCompletion = nil;
        return;
    }
    NSLog(@"[HQITAccurateRecommend] non-force first system deny → -360 continue");
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
    [manager stopUpdatingLocation];
    NSString *lng = [HQITSigningHelper coordinateSignValue:loc.coordinate.longitude];
    NSString *lat = [HQITSigningHelper coordinateSignValue:loc.coordinate.latitude];
    NSLog(@"[HQITAccurateRecommend] didUpdateLocations lng=%@ lat=%@", lng, lat);
    if (self.locationCompletion) self.locationCompletion(lng, lat, NO);
    self.locationCompletion = nil;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"[HQITAccurateRecommend] location fail code=%ld %@", (long)error.code, error.localizedDescription);
    if (error.code == kCLErrorLocationUnknown) return;
    [self clearLocationTimeout];
    [self locationFailedForceAware];
}

- (void)locationFailedForceAware {
    if (!self.locationCompletion) return;
    [self clearLocationTimeout];
    [self.locationManager stopUpdatingLocation];
    self.awaitingFirstAuthResult = NO;
    if (![self isForceLocation]) {
        NSLog(@"[HQITAccurateRecommend] non-force location failed → -360");
        if (self.locationCompletion) self.locationCompletion(@"-360.000000", @"-360.000000", NO);
        self.locationCompletion = nil;
        return;
    }
    CLAuthorizationStatus status = self.locationManager.authorizationStatus;
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        NSLog(@"[HQITAccurateRecommend] force location permission denied mid-flow → end (no secondary dialog)");
        if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
        self.locationCompletion = nil;
        return;
    }
    NSLog(@"[HQITAccurateRecommend] force location GPS failed → cancel");
    if (self.locationCompletion) self.locationCompletion(nil, nil, YES);
    self.locationCompletion = nil;
}

@end
