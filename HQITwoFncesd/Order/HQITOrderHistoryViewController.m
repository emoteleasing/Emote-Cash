

#import "HQITOrderHistoryViewController.h"
#import "HQITOrderHistoryViewModel.h"
#import "HQITOrderHistoryCell.h"
#import "HQITOrderDetailViewController.h"
#import "HQITWithdrawOrderDetailViewController.h"
#import "HQITRejectH5ViewController.h"
#import "HQITFontHelper.h"
#import "HQITNavigationBarStyle.h"
#import "HQITHUDHelper.h"
#import <Masonry/Masonry.h>

@interface HQITOrderHistoryViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) HQITOrderHistoryViewModel *viewModel;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) CAGradientLayer *headerGradient;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *tabBar;
@property (nonatomic, strong) UIStackView *tabStack;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, strong) UIView *contentArea;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIImageView *emptyImageView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, assign) NSInteger pendingOrderStatus;
@property (nonatomic, assign) BOOL hasPendingOrderStatus;
@end

@implementation HQITOrderHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = NO;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    self.viewModel = [[HQITOrderHistoryViewModel alloc] init];
    if (self.hasPendingOrderStatus) {
        [self.viewModel selectTab:[[HQITOrderHistoryViewModel class] tabForOrderStatus:self.pendingOrderStatus]
                           reload:NO];
    }
    [self buildUI];
    [self bindViewModel];
    [self applySelectedTab];
    [self refreshContent];
    [self.viewModel reloadCurrentSection];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    if (self.viewModel.hasLoadedOnce) {
        [self.viewModel reloadCurrentSection];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = MAX(self.headerView.bounds.size.height, 1);
    UIImage *fitted = [HQITNavigationBarStyle loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    if (fitted) {
        self.headerBg.image = fitted;
        self.headerGradient.hidden = YES;
    } else {
        self.headerGradient.hidden = NO;
        self.headerGradient.frame = self.headerBg.bounds;
    }
}

#pragma mark - Public

- (void)selectOrderStatus:(NSInteger)orderStatus {
    self.pendingOrderStatus = orderStatus;
    self.hasPendingOrderStatus = YES;
    if (!self.viewModel) return;
    (void)self.view;
    HQITOrderHistoryTab tab = [[HQITOrderHistoryViewModel class] tabForOrderStatus:orderStatus];
    if (self.viewModel.selectedTab == tab) {
        [self.viewModel reloadCurrentSection];
    } else {
        [self.viewModel selectOrderStatus:orderStatus];
    }
    [self applySelectedTab];
    [self refreshContent];
}

#pragma mark - Bind

- (void)bindViewModel {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self refreshContent];
    };
}

- (void)refreshContent {
    BOOL empty = self.viewModel.currentItems.count == 0;
    BOOL showEmpty = empty && self.viewModel.hasLoadedOnce && !self.viewModel.isLoading;
    self.emptyView.hidden = !showEmpty;
    self.tableView.hidden = showEmpty;
    [self.tableView reloadData];
    [self applySelectedTab];
}

#pragma mark - UI

- (void)buildUI {
    self.headerView = [[UIView alloc] init];
    self.headerView.clipsToBounds = YES;
    self.headerView.layer.cornerRadius = 24;
    self.headerView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    [self.view addSubview:self.headerView];
    [self.headerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
    }];

    self.headerBg = [[UIImageView alloc] init];
    self.headerBg.contentMode = UIViewContentModeScaleToFill;
    self.headerBg.clipsToBounds = YES;
    [self.headerView addSubview:self.headerBg];
    [self.headerBg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.headerView);
    }];

    self.headerGradient = [CAGradientLayer layer];
    self.headerGradient.colors = @[
        (id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0xFF/255.0 green:0x8A/255.0 blue:0x1A/255.0 alpha:1].CGColor,
    ];
    self.headerGradient.locations = @[@0, @0.45, @1];
    self.headerGradient.startPoint = CGPointMake(0, 0.5);
    self.headerGradient.endPoint = CGPointMake(1, 0.5);
    [self.headerBg.layer insertSublayer:self.headerGradient atIndex:0];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"Order history";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [HQITFontHelper boldFontOfSize:17];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.headerView addSubview:self.titleLabel];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerView.mas_safeAreaLayoutGuideTop).offset(8);
        make.left.equalTo(self.headerView).offset(16);
        make.right.equalTo(self.headerView).offset(-16);
        make.height.mas_equalTo(28);
    }];

    self.tabBar = [[UIView alloc] init];
    [self.headerView addSubview:self.tabBar];
    [self.tabBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.titleLabel.mas_bottom).offset(14);
        make.left.equalTo(self.headerView).offset(12);
        make.right.equalTo(self.headerView).offset(-12);
        make.height.mas_equalTo(32);
        make.bottom.equalTo(self.headerView).offset(-16);
    }];

    self.tabStack = [[UIStackView alloc] init];
    self.tabStack.axis = UILayoutConstraintAxisHorizontal;
    self.tabStack.spacing = 6;
    self.tabStack.alignment = UIStackViewAlignmentFill;
    self.tabStack.distribution = UIStackViewDistributionFillEqually;
    [self.tabBar addSubview:self.tabStack];
    [self.tabStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.tabBar);
    }];

    UIColor *accent = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    NSArray<NSString *> *titles = @[
        @"Repayment\nDue",
        @"Submit\nApplication",
        @"Processing",
        @"Completed",
    ];
    NSMutableArray<UIButton *> *btns = [NSMutableArray array];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        btn.titleLabel.font = [HQITFontHelper regularFontOfSize:11];
        btn.titleLabel.numberOfLines = 2;
        btn.titleLabel.textAlignment = NSTextAlignmentCenter;
        btn.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn setTitleColor:accent forState:UIControlStateSelected];
        btn.layer.cornerRadius = 16;
        btn.clipsToBounds = YES;
        [btn addTarget:self action:@selector(onTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabStack addArrangedSubview:btn];
        [btns addObject:btn];
    }
    self.tabButtons = btns;

    self.contentArea = [[UIView alloc] init];
    [self.view addSubview:self.contentArea];
    [self.contentArea mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerView.mas_bottom);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
    }];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsMake(10, 0, 16, 0);
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = [HQITOrderHistoryCell itemHeight] + [HQITOrderHistoryCell itemSpacing];
    self.tableView.estimatedRowHeight = [HQITOrderHistoryCell itemHeight] + [HQITOrderHistoryCell itemSpacing];
    [self.tableView registerClass:[HQITOrderHistoryCell class] forCellReuseIdentifier:[HQITOrderHistoryCell reuseId]];
    [self.contentArea addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentArea);
    }];

    self.emptyView = [[UIView alloc] init];
    self.emptyView.hidden = YES;
    [self.contentArea addSubview:self.emptyView];
    [self.emptyView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentArea);
        make.centerY.equalTo(self.contentArea).offset(-20);
        make.left.greaterThanOrEqualTo(self.contentArea).offset(24);
        make.right.lessThanOrEqualTo(self.contentArea).offset(-24);
    }];

    self.emptyImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"no_image"]];
    self.emptyImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyView addSubview:self.emptyImageView];
    [self.emptyImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.centerX.equalTo(self.emptyView);
        make.width.mas_equalTo(200);
        make.height.mas_equalTo(173);
    }];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"No Order";
    self.emptyLabel.textColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    self.emptyLabel.font = [HQITFontHelper boldFontOfSize:18];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:self.emptyLabel];
    [self.emptyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.emptyImageView.mas_bottom).offset(16);
        make.left.right.bottom.equalTo(self.emptyView);
    }];
}

#pragma mark - Tabs

- (void)onTabTapped:(UIButton *)sender {
    [self.viewModel selectTab:(HQITOrderHistoryTab)sender.tag];
    [self applySelectedTab];
    [self refreshContent];
}

- (void)applySelectedTab {
    UIColor *accent = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    for (UIButton *btn in self.tabButtons) {
        BOOL on = (btn.tag == self.viewModel.selectedTab);
        btn.selected = on;
        if (on) {
            btn.backgroundColor = [UIColor whiteColor];
            [btn setTitleColor:accent forState:UIControlStateNormal];
            btn.titleLabel.font = [HQITFontHelper boldFontOfSize:11];
        } else {
            btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.titleLabel.font = [HQITFontHelper regularFontOfSize:11];
        }
    }
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.viewModel.currentItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HQITOrderHistoryCell *cell = [tableView dequeueReusableCellWithIdentifier:[HQITOrderHistoryCell reuseId] forIndexPath:indexPath];
    NSArray *items = self.viewModel.currentItems;
    if (indexPath.row < (NSInteger)items.count) {
        [cell applyItem:items[indexPath.row]];
    }
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [HQITOrderHistoryCell itemHeight] + [HQITOrderHistoryCell itemSpacing];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [HQITOrderHistoryCell itemHeight] + [HQITOrderHistoryCell itemSpacing];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *items = self.viewModel.currentItems;
    if (indexPath.row >= (NSInteger)items.count) return;
    HQITOrderHistoryItem *item = items[indexPath.row];
    if (item.statusCode == 31 && [HQITRejectH5ViewController isRejectH5Configured]) {
        HQITRejectH5ViewController *vc =
            [[HQITRejectH5ViewController alloc] initWithPageURLString:[HQITRejectH5ViewController configuredPageURLString]];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if (item.statusCode == 32) {
        HQITWithdrawOrderDetailViewController *vc =
            [[HQITWithdrawOrderDetailViewController alloc] initWithOrderId:item.orderId productId:item.productId];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    HQITOrderDetailViewController *vc =
        [[HQITOrderDetailViewController alloc] initWithOrderId:item.orderId productId:item.productId];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
