

#import "HQITAccurateRecommendSuccessViewController.h"
#import "HQITAccurateRecommendSuccessViewModel.h"
#import "HQITAccurateRecommendSuccessOrderCell.h"
#import "HQITFontHelper.h"
#import "HQITNavigationBarStyle.h"
#import "HQITClickGuard.h"
#import "HQITHUDHelper.h"
#import "HQITRatingGuidePresenter.h"
#import "HQITFeedbackViewController.h"
#import "HQITAppShell.h"
#import "HQITAppConfigHelper.h"
#import <Masonry/Masonry.h>

static NSString * const kHQITAccurateRecommendSuccessOrderCellId = @"HQITAccurateRecommendSuccessOrderCell";

@interface HQITAccurateRecommendSuccessViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) HQITAccurateRecommendSuccessViewModel *viewModel;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *feedbackButton;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, assign) BOOL finishing;
@property (nonatomic, assign) BOOL ratingFlowStarted;
@property (nonatomic, assign) CFTimeInterval ignoreNavActionsUntil;
@end

@implementation HQITAccurateRecommendSuccessViewController

- (instancetype)initWithOrderIds:(NSArray<NSString *> *)orderIds {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _viewModel = [[HQITAccurateRecommendSuccessViewModel alloc] initWithOrderIds:orderIds];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildUI];
    [self bindViewModel];
    [self.viewModel loadAllOrderDetails];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    [self hqit_armNavActionGuardForChildPop];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSTimeInterval delay = MAX(0.05, self.ignoreNavActionsUntil - CACurrentMediaTime() + 0.05);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.finishing) return;
        self.backButton.enabled = YES;
        self.backButton.userInteractionEnabled = YES;
        self.feedbackButton.enabled = YES;
        self.confirmButton.enabled = YES;
        [HQITClickGuard unlockControl:self.feedbackButton];
        [HQITClickGuard unlockControl:self.confirmButton];
    });
}

- (void)hqit_armNavActionGuardForChildPop {
    self.ignoreNavActionsUntil = CACurrentMediaTime() + 1.0;
    self.backButton.enabled = NO;
    self.backButton.userInteractionEnabled = NO;
    self.feedbackButton.enabled = NO;
    self.confirmButton.enabled = NO;
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
    [self layoutTableHeaderIfNeeded];
}

- (void)hqit_setupBackButtonIfNeeded {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:[[UIView alloc] init]];
    self.navigationItem.hidesBackButton = YES;
}

- (UIColor *)navy { return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1]; }
- (UIColor *)orange { return [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1]; }
- (UIColor *)gray { return [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1]; }

#pragma mark - Bind

- (void)bindViewModel {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf.tableView reloadData];
    };
    self.viewModel.onErrorMessage = ^(NSString *message) {
        [HQITHUDHelper showToast:message];
    };
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
    [self.backButton addTarget:self action:@selector(onConfirm) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];
    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = @"Success!";
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
    }];

    self.feedbackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.feedbackButton.backgroundColor = [UIColor whiteColor];
    self.feedbackButton.layer.cornerRadius = 10;
    self.feedbackButton.layer.borderWidth = 1;
    self.feedbackButton.layer.borderColor = [self orange].CGColor;
    [self.feedbackButton setTitle:@"Feedback" forState:UIControlStateNormal];
    [self.feedbackButton setTitleColor:[self orange] forState:UIControlStateNormal];
    self.feedbackButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.feedbackButton addTarget:self action:@selector(onFeedback) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.feedbackButton];

    self.confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.confirmButton.clipsToBounds = YES;
    self.confirmButton.layer.cornerRadius = 10;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat bw = MAX(bg.size.width, 1), bh = MAX(bg.size.height, 1);
        [self.confirmButton setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                  resizingMode:UIImageResizingModeStretch]
                                      forState:UIControlStateNormal];
    } else {
        self.confirmButton.backgroundColor = [self orange];
    }
    [self.confirmButton setTitle:@"Confirm" forState:UIControlStateNormal];
    [self.confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.confirmButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.confirmButton addTarget:self action:@selector(onConfirm) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.confirmButton];

    [self.feedbackButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view).offset(-32);
    }];
    [self.confirmButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.feedbackButton.mas_right).offset(12);
        make.right.equalTo(self.view).offset(-16);
        make.height.bottom.width.equalTo(self.feedbackButton);
    }];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.estimatedRowHeight = 280;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    [self.tableView registerClass:[HQITAccurateRecommendSuccessOrderCell class]
           forCellReuseIdentifier:kHQITAccurateRecommendSuccessOrderCellId];
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.confirmButton.mas_top).offset(-12);
    }];
    self.tableView.tableHeaderView = [self buildSuccessHeader];
    [self.view bringSubviewToFront:self.navContent];
    [self.view bringSubviewToFront:self.feedbackButton];
    [self.view bringSubviewToFront:self.confirmButton];
}

- (UIView *)buildSuccessHeader {
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 1)];
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;
    [wrap addSubview:card];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"can_icon"]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:icon];
    UILabel *title = [[UILabel alloc] init];
    title.text = @"Success!";
    title.font = [HQITFontHelper boldFontOfSize:18];
    title.textColor = [self navy];
    title.textAlignment = NSTextAlignmentCenter;
    [card addSubview:title];
    UILabel *body = [[UILabel alloc] init];
    body.numberOfLines = 0;
    body.textAlignment = NSTextAlignmentCenter;
    body.font = [HQITFontHelper regularFontOfSize:13];
    body.textColor = [self gray];
    body.text = @"Congratulations! Your application is now under review. Once approved, the loan will be disbursed to your bank account. Please check accordingly.";
    [card addSubview:body];

    [card mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(wrap).offset(4);
        make.left.equalTo(wrap).offset(16);
        make.right.equalTo(wrap).offset(-16);
        make.bottom.equalTo(wrap).offset(-6);
    }];
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(24);
        make.centerX.equalTo(card);
        make.width.height.mas_equalTo(56);
    }];
    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(icon.mas_bottom).offset(12);
        make.left.equalTo(card).offset(20);
        make.right.equalTo(card).offset(-20);
    }];
    [body mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(title.mas_bottom).offset(8);
        make.left.right.equalTo(title);
        make.bottom.equalTo(card).offset(-24);
    }];
    [wrap setNeedsLayout];
    [wrap layoutIfNeeded];
    CGSize size = [wrap systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                      withHorizontalFittingPriority:UILayoutPriorityRequired
                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    wrap.frame = CGRectMake(0, 0, width, size.height);
    return wrap;
}

- (void)layoutTableHeaderIfNeeded {
    UIView *header = self.tableView.tableHeaderView;
    if (!header) return;
    CGFloat width = self.tableView.bounds.size.width;
    if (width <= 0) return;
    header.frame = CGRectMake(0, 0, width, header.bounds.size.height);
    [header setNeedsLayout];
    [header layoutIfNeeded];
    CGSize size = [header systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                        withHorizontalFittingPriority:UILayoutPriorityRequired
                              verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    if (fabs(header.frame.size.height - size.height) > 0.5) {
        header.frame = CGRectMake(0, 0, width, size.height);
        self.tableView.tableHeaderView = header;
    }
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.viewModel.orders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HQITAccurateRecommendSuccessOrderCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kHQITAccurateRecommendSuccessOrderCellId forIndexPath:indexPath];
    HQITAccurateRecommendSuccessOrderItem *item = self.viewModel.orders[indexPath.row];
    [cell configureWithItem:item];
    __weak typeof(self) weakSelf = self;
    cell.onInfoTap = ^(NSString *infoKey) {
        [weakSelf showInfoForKey:infoKey];
    };
    return cell;
}

- (void)showInfoForKey:(NSString *)key {
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

#pragma mark - Actions

- (BOOL)hqit_shouldIgnoreNavAction {
    return CACurrentMediaTime() < self.ignoreNavActionsUntil;
}

- (void)onFeedback {
    if (self.finishing || [self hqit_shouldIgnoreNavAction]) return;
    if (![HQITClickGuard tryLockControl:self.feedbackButton]) return;
    HQITFeedbackViewController *vc =
        [[HQITFeedbackViewController alloc] initWithExitStyle:HQITFeedbackExitPopToNavRoot];
    vc.presentRatingGuideOnEnter = YES;
    [self.navigationController pushViewController:vc animated:YES];
    [HQITClickGuard unlockControl:self.feedbackButton];
}

- (void)onConfirm {
    if (self.finishing || self.ratingFlowStarted || [self hqit_shouldIgnoreNavAction]) return;
    self.ratingFlowStarted = YES;
    [HQITClickGuard lockControl:self.confirmButton];
    [HQITClickGuard lockControl:self.feedbackButton];
    self.backButton.enabled = NO;
    self.backButton.userInteractionEnabled = NO;

    __weak typeof(self) weakSelf = self;
    UIView *host = [HQITAppShell shared].window ?: self.view.window ?: self.view;
    NSInteger guidance = [HQITAppConfigHelper feedbackGuidanceMode];
    NSLog(@"[HQITAccurateRecommendSuccess] Confirm → rating guide feedbackGuidance=%ld",
          (long)guidance);
    [HQITRatingGuidePresenter presentIfNeededForced:NO
                                           userType:0
                                             inView:host
                                         completion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self finishFlow];
    }];
}

- (void)finishFlow {
    if (self.finishing) return;
    self.finishing = YES;
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
