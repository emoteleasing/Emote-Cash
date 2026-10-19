

#import "HQITMeViewController.h"
#import "HQITMeViewModel.h"
#import "HQITMeMenuCell.h"
#import "HQITFontHelper.h"
#import "HQITDialogs.h"
#import "HQITAppShell.h"
#import "HQITSessionManager.h"
#import "HQITHomeSessionState.h"
#import "HQITConfigWebViewController.h"
#import "HQITFeedbackViewController.h"
#import "HQITRepaymentInstructionsViewController.h"
#import "HQITOfficialWebsiteViewController.h"
#import "HQITAboutViewController.h"
#import <Masonry/Masonry.h>

typedef NS_ENUM(NSInteger, HQITMeMenuAction) {
    HQITMeMenuFeedback = 0,
    HQITMeMenuPrivacy,
    HQITMeMenuTerms,
    HQITMeMenuRepayment,
    HQITMeMenuWebsite,
    HQITMeMenuAbout,
};

static NSString * const kHQITMeCellId = @"HQITMeMenuCell";
static NSString * const kHQITMeHeaderId = @"HQITMeHeader";
static NSString * const kHQITMeFooterId = @"HQITMeFooter";

@interface HQITMeHeaderView : UICollectionReusableView
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *hiLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *mobileLabel;
- (void)applyName:(NSString *)name mobile:(NSString *)mobile;
@end

@implementation HQITMeHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.headerBg = [[UIImageView alloc] init];
        UIImage *bg = [UIImage imageNamed:@"self_bg"];
        if (bg) {
            CGFloat h = MAX(bg.size.height, 1);
            self.headerBg.image = [bg resizableImageWithCapInsets:UIEdgeInsetsMake(MAX(h - 40, 0), 0, 0, 0)
                                                     resizingMode:UIImageResizingModeStretch];
        } else {
            self.headerBg.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
        }
        self.headerBg.contentMode = UIViewContentModeScaleToFill;
        self.headerBg.clipsToBounds = YES;
        self.headerBg.layer.cornerRadius = 28;
        self.headerBg.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
        [self addSubview:self.headerBg];
        [self.headerBg mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];

        self.avatarView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"one_logo"]];
        self.avatarView.contentMode = UIViewContentModeScaleAspectFit;
        self.avatarView.layer.cornerRadius = 14;
        self.avatarView.clipsToBounds = YES;
        [self addSubview:self.avatarView];
        [self.avatarView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).offset(16);
            make.top.equalTo(self.mas_safeAreaLayoutGuideTop).offset(18);
            make.width.height.mas_equalTo(74);
        }];

        UIColor *secondaryWhite = [[UIColor whiteColor] colorWithAlphaComponent:0.85];

        self.hiLabel = [[UILabel alloc] init];
        self.hiLabel.attributedText = [self attributedText:@"Hi~"
                                                      font:[HQITFontHelper regularFontOfSize:13]
                                                     color:secondaryWhite
                                                lineHeight:19];
        [self addSubview:self.hiLabel];

        self.nameLabel = [[UILabel alloc] init];
        [self addSubview:self.nameLabel];

        self.mobileLabel = [[UILabel alloc] init];
        [self addSubview:self.mobileLabel];

        [self.hiLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.avatarView.mas_right).offset(0);
            make.top.equalTo(self.mas_safeAreaLayoutGuideTop).offset(16);
            make.right.equalTo(self).offset(-16);
            make.height.mas_equalTo(19);
        }];
        [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.avatarView.mas_right).offset(0);
            make.top.equalTo(self.hiLabel.mas_bottom);
            make.right.equalTo(self).offset(-16);
            make.height.mas_equalTo(24);
        }];
        [self.mobileLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.avatarView.mas_right).offset(0);
            make.top.equalTo(self.nameLabel.mas_bottom).offset(2);
            make.right.equalTo(self).offset(-16);
            make.height.mas_equalTo(20);
            make.bottom.equalTo(self).offset(-54).priorityLow();
        }];
    }
    return self;
}

- (NSAttributedString *)attributedText:(NSString *)text
                                  font:(UIFont *)font
                                 color:(UIColor *)color
                            lineHeight:(CGFloat)lineHeight {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.minimumLineHeight = lineHeight;
    style.maximumLineHeight = lineHeight;
    return [[NSAttributedString alloc] initWithString:text ?: @""
                                           attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style,
    }];
}

- (void)applyName:(NSString *)name mobile:(NSString *)mobile {
    UIColor *secondaryWhite = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    self.hiLabel.attributedText = [self attributedText:@"Hi~"
                                                  font:[HQITFontHelper regularFontOfSize:13]
                                                 color:secondaryWhite
                                            lineHeight:19];
    self.nameLabel.attributedText = [self attributedText:name
                                                    font:[HQITFontHelper boldFontOfSize:16]
                                                   color:[UIColor whiteColor]
                                              lineHeight:24];
    self.mobileLabel.attributedText = [self attributedText:mobile
                                                      font:[HQITFontHelper regularFontOfSize:13]
                                                     color:secondaryWhite
                                                lineHeight:20];
}

@end

@interface HQITMeFooterView : UICollectionReusableView
@property (nonatomic, strong) UIButton *signOutButton;
@property (nonatomic, strong) CAGradientLayer *borderGradient;
@property (nonatomic, copy, nullable) void (^onSignOut)(void);
@end

@implementation HQITMeFooterView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIView *borderHost = [[UIView alloc] init];
        borderHost.layer.cornerRadius = 14;
        borderHost.clipsToBounds = YES;
        [self addSubview:borderHost];
        [borderHost mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self).offset(16);
            make.left.equalTo(self).offset(16);
            make.right.equalTo(self).offset(-16);
            make.height.mas_equalTo(44);
            make.bottom.equalTo(self).offset(-24);
        }];

        self.borderGradient = [CAGradientLayer layer];
        self.borderGradient.colors = @[
            (id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
            (id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
        ];
        self.borderGradient.startPoint = CGPointMake(0.5, 0);
        self.borderGradient.endPoint = CGPointMake(0.5, 1);
        [borderHost.layer addSublayer:self.borderGradient];

        self.signOutButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.signOutButton.backgroundColor = [UIColor whiteColor];
        self.signOutButton.layer.cornerRadius = 14 - 1.25;
        self.signOutButton.clipsToBounds = YES;
        [self.signOutButton setTitle:@"Sign out" forState:UIControlStateNormal];
        [self.signOutButton setTitleColor:[UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1]
                                 forState:UIControlStateNormal];
        self.signOutButton.titleLabel.font = [HQITFontHelper boldFontOfSize:14];
        [self.signOutButton addTarget:self action:@selector(tapSignOut) forControlEvents:UIControlEventTouchUpInside];
        [borderHost addSubview:self.signOutButton];
        [self.signOutButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(borderHost).insets(UIEdgeInsetsMake(1.25, 1.25, 1.25, 1.25));
        }];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    UIView *borderHost = self.signOutButton.superview;
    self.borderGradient.frame = borderHost.bounds;
}

- (void)tapSignOut {
    if (self.onSignOut) self.onSignOut();
}

@end

@interface HQITMeViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) HQITMeViewModel *viewModel;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, copy) NSArray<NSDictionary *> *menuItems;
@property (nonatomic, weak) HQITMeHeaderView *headerView;
@end

@implementation HQITMeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = NO;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    self.viewModel = [[HQITMeViewModel alloc] init];
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf refreshHeader];
    };
    self.menuItems = @[
        @{@"title": @"Feedback", @"icon": @"feedback_icon", @"action": @(HQITMeMenuFeedback)},
        @{@"title": @"Privacy policy", @"icon": @"policy_icon", @"action": @(HQITMeMenuPrivacy)},
        @{@"title": @"Terms of the loan", @"icon": @"why_icon", @"action": @(HQITMeMenuTerms)},
        @{@"title": @"Repayment Instructions", @"icon": @"time_icon", @"action": @(HQITMeMenuRepayment)},
        @{@"title": @"Official Website", @"icon": @"of_icon", @"action": @(HQITMeMenuWebsite)},
        @{@"title": @"About", @"icon": @"about_icon", @"action": @(HQITMeMenuAbout)},
    ];
    [self buildCollectionView];
    [self refreshHeader];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [self.viewModel reloadUserInfo];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[UICollectionViewFlowLayout class]]) return;
    CGFloat headerH = 180;
    CGSize size = CGSizeMake(self.collectionView.bounds.size.width, headerH);
    if (!CGSizeEqualToSize(layout.headerReferenceSize, size)) {
        layout.headerReferenceSize = size;
        [layout invalidateLayout];
    }
}

#pragma mark - UI

- (void)buildCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumLineSpacing = 10;
    layout.minimumInteritemSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(16, 15, 0, 15);
    layout.headerReferenceSize = CGSizeMake(UIScreen.mainScreen.bounds.size.width, 180);
    layout.footerReferenceSize = CGSizeMake(UIScreen.mainScreen.bounds.size.width, 16 + 44 + 24);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.collectionView registerClass:[HQITMeMenuCell class] forCellWithReuseIdentifier:kHQITMeCellId];
    [self.collectionView registerClass:[HQITMeHeaderView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:kHQITMeHeaderId];
    [self.collectionView registerClass:[HQITMeFooterView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                   withReuseIdentifier:kHQITMeFooterId];
    [self.view addSubview:self.collectionView];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
    }];
}

- (void)refreshHeader {
    [self.headerView applyName:self.viewModel.displayName mobile:self.viewModel.maskedMobile];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return (NSInteger)self.menuItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    HQITMeMenuCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kHQITMeCellId forIndexPath:indexPath];
    NSDictionary *item = self.menuItems[indexPath.item];
    [cell configureWithTitle:item[@"title"] iconName:item[@"icon"]];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath {
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        HQITMeHeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                      withReuseIdentifier:kHQITMeHeaderId
                                                                             forIndexPath:indexPath];
        self.headerView = header;
        [header applyName:self.viewModel.displayName mobile:self.viewModel.maskedMobile];
        return header;
    }
    HQITMeFooterView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                  withReuseIdentifier:kHQITMeFooterId
                                                                         forIndexPath:indexPath];
    __weak typeof(self) weakSelf = self;
    footer.onSignOut = ^{
        [weakSelf onSignOut];
    };
    return footer;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat spacing = 10;
    CGFloat inset = 15;
    CGFloat width = floor((collectionView.bounds.size.width - inset * 2 - spacing) / 2.0);
    return CGSizeMake(width, 64);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.menuItems[indexPath.item];
    HQITMeMenuAction action = [item[@"action"] integerValue];
    [self handleMenuAction:action];
}

#pragma mark - Actions

- (void)handleMenuAction:(HQITMeMenuAction)action {
    switch (action) {
        case HQITMeMenuFeedback:
            [self.navigationController pushViewController:[[HQITFeedbackViewController alloc] init] animated:YES];
            break;
        case HQITMeMenuPrivacy:
            [self pushWebConfigKey:@"policyHref" title:@"Privacy Policy"];
            break;
        case HQITMeMenuTerms:
            [self pushWebConfigKey:@"conditionsHref" title:@"Terms of the Loan"];
            break;
        case HQITMeMenuRepayment:
            [self.navigationController pushViewController:[[HQITRepaymentInstructionsViewController alloc] init] animated:YES];
            break;
        case HQITMeMenuWebsite:
            [self.navigationController pushViewController:[[HQITOfficialWebsiteViewController alloc] init] animated:YES];
            break;
        case HQITMeMenuAbout:
            [self.navigationController pushViewController:[[HQITAboutViewController alloc] init] animated:YES];
            break;
    }
}

- (void)pushWebConfigKey:(NSString *)key title:(NSString *)title {
    HQITConfigWebViewController *vc = [HQITConfigWebViewController controllerWithHrefConfigKey:key pageTitle:title];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onSignOut {
    UIView *host = self.view.window ?: self.view;
    [HQITDialogs showWhiteConfirmTitle:@"Sign Out"
                                  body:@"Are you sure to sign out your account?"
                                  icon:[UIImage imageNamed:@"sure_icon"]
                         confirmTitle:@"Confirm"
                          cancelTitle:@"Cancel"
                        cancelPrimary:YES
                               inView:host
                            onConfirm:^{
        [self.viewModel clearCachedProfile];
        [[HQITSessionManager shared] clearSession];
        [HQITHomeSessionState resetForLogout];
        [[HQITAppShell shared] showLogin];
    } onCancel:nil];
}

@end
