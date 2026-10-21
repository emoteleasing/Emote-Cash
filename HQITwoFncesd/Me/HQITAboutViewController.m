

#import "HQITAboutViewController.h"
#import "HQITFontHelper.h"
#import "HQITDialogs.h"
#import "HQITNetworkClient.h"
#import "HQITSessionManager.h"
#import "HQITAppShell.h"
#import "HQITHomeSessionState.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import "HQITClickGuard.h"
#import <Masonry/Masonry.h>

@interface HQITAboutViewController ()
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, assign) BOOL isClosing;
@end

@implementation HQITAboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [HQITClickGuard unlockControl:self.deleteButton];
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

#pragma mark - Data

- (NSString *)appDisplayName {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
        ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
        ?: @"APP NAME";
}

- (NSString *)normalizedVersion {
    NSString *raw = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed.lowercaseString hasPrefix:@"v"]) {
        trimmed = [[trimmed substringFromIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (trimmed.length == 0) return @"1.0.0";
    NSArray *parts = [trimmed componentsSeparatedByString:@"."];
    if (parts.count == 1) return [NSString stringWithFormat:@"%@.0.0", parts[0]];
    if (parts.count == 2) return [NSString stringWithFormat:@"%@.%@.0", parts[0], parts[1]];
    return [[parts subarrayWithRange:NSMakeRange(0, MIN(3, parts.count))] componentsJoinedByString:@"."];
}

- (NSString *)aboutDescription:(NSString *)appName {
    (void)appName;
    return @"Emote Cash makes financial planning more flexible and accessible. We aim to remove complexity from financial decision-making.";
}

- (UIImage *)loadAppIconImage {
    UIImage *named = [UIImage imageNamed:@"one_logo"];
    if (named) return named;
    NSDictionary *icons = [[NSBundle mainBundle] infoDictionary][@"CFBundleIcons"];
    if (![icons isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *primary = icons[@"CFBundlePrimaryIcon"];
    if (![primary isKindOfClass:[NSDictionary class]]) return nil;
    NSArray *files = primary[@"CFBundleIconFiles"];
    if (![files isKindOfClass:[NSArray class]] || files.count == 0) return nil;
    return [UIImage imageNamed:files.lastObject];
}

#pragma mark - Colors

- (UIColor *)navy {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)muted {
    return [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1];
}

- (UIColor *)descColor {
    return [UIColor colorWithRed:0x6D/255.0 green:0x74/255.0 blue:0x7A/255.0 alpha:1];
}

- (UIColor *)deleteRed {
    return [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
}

#pragma mark - UI

- (void)buildUI {
    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];
    NSString *appName = @"Emote Cash";

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
    if (backImg) [self.backButton setImage:backImg forState:UIControlStateNormal];
    [self.backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];

    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = @"About";
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.deleteButton.backgroundColor = [UIColor whiteColor];
    self.deleteButton.layer.cornerRadius = 10;
    self.deleteButton.layer.borderWidth = 1;
    self.deleteButton.layer.borderColor = [self deleteRed].CGColor;
    self.deleteButton.clipsToBounds = YES;
    [self.deleteButton setTitle:@"Delete Account" forState:UIControlStateNormal];
    [self.deleteButton setTitleColor:[self deleteRed] forState:UIControlStateNormal];
    self.deleteButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.deleteButton addTarget:self action:@selector(onDelete) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.deleteButton];
    [self.deleteButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16);
    }];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.deleteButton.mas_top).offset(-12);
    }];

    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];

    UIView *infoCard = [self whiteCard];
    [self.contentView addSubview:infoCard];
    [infoCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(4);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
    }];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.contentMode = UIViewContentModeScaleAspectFill;
    iconView.clipsToBounds = YES;
    iconView.layer.cornerRadius = 16;
    UIImage *appIcon = [self loadAppIconImage];
    if (appIcon) {
        iconView.image = appIcon;
    } else {
        iconView.backgroundColor = [self deleteRed];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightMedium];
        iconView.image = [[UIImage systemImageNamed:@"indianrupeesign" withConfiguration:cfg]
                          imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        iconView.tintColor = [UIColor whiteColor];
        iconView.contentMode = UIViewContentModeCenter;
    }
    [infoCard addSubview:iconView];
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(infoCard).offset(28);
        make.centerX.equalTo(infoCard);
        make.width.height.mas_equalTo(97);
    }];

    UILabel *nameLab = [[UILabel alloc] init];
    nameLab.text = appName;
    nameLab.font = [HQITFontHelper boldFontOfSize:18];
    nameLab.textColor = [self navy];
    nameLab.textAlignment = NSTextAlignmentCenter;
    nameLab.numberOfLines = 2;
    [infoCard addSubview:nameLab];
    [nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(iconView.mas_bottom).offset(0);
        make.left.equalTo(infoCard).offset(16);
        make.right.equalTo(infoCard).offset(-16);
    }];

    UILabel *verLab = [[UILabel alloc] init];
    verLab.text = [NSString stringWithFormat:@"Version V %@", [self normalizedVersion]];
    verLab.font = [HQITFontHelper regularFontOfSize:13];
    verLab.textColor = [self muted];
    verLab.textAlignment = NSTextAlignmentCenter;
    [infoCard addSubview:verLab];
    [verLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(nameLab.mas_bottom).offset(8);
        make.left.right.equalTo(nameLab);
        make.bottom.equalTo(infoCard).offset(-28);
    }];

    UIView *descCard = [self whiteCard];
    [self.contentView addSubview:descCard];
    [descCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(infoCard.mas_bottom).offset(12);
        make.left.right.equalTo(infoCard);
        make.bottom.equalTo(self.contentView).offset(-20);
    }];

    UILabel *descLab = [[UILabel alloc] init];
    descLab.numberOfLines = 0;
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.minimumLineHeight = 22;
    style.maximumLineHeight = 22;
    style.lineBreakMode = NSLineBreakByWordWrapping;
    descLab.attributedText = [[NSAttributedString alloc] initWithString:[self aboutDescription:appName]
                                                             attributes:@{
        NSFontAttributeName: [HQITFontHelper regularFontOfSize:13],
        NSForegroundColorAttributeName: [self descColor],
        NSParagraphStyleAttributeName: style,
    }];
    [descCard addSubview:descLab];
    [descLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(descCard).insets(UIEdgeInsetsMake(16, 16, 16, 16));
    }];
}

- (UIView *)whiteCard {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;
    return card;
}

#pragma mark - Actions

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onDelete {
    if (![HQITClickGuard tryLockControl:self.deleteButton]) return;
    [HQITClickGuard unlockControl:self.deleteButton];
    NSString *body =
    @"When your loan order is under review and loan processing, you cannot cancel your account. "
     "When your loan order has not been settled, you cannot cancel your account. "
     "After confirming the cancellation, the account will not be restored. Please operate with caution.";
    UIView *host = self.view.window ?: self.view;
    [HQITDialogs showWhiteConfirmTitle:@"Delete Account"
                                  body:body
                                  icon:[UIImage imageNamed:@"delete_icon"]
                         confirmTitle:@"Confirm"
                          cancelTitle:@"Cancel"
                        cancelPrimary:NO
                               inView:host
                            onConfirm:^{
        [self requestCloseAccount];
    } onCancel:nil];
}

- (void)requestCloseAccount {
    if (self.isClosing) return;
    self.isClosing = YES;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/auth/close"
                                         signedData:@{}
                                       unsignedData:nil
                                        showLoading:@YES
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isClosing = NO;
        UIView *host = self.view.window ?: self.view;
        [HQITDialogs showWhiteConfirmTitle:@"Success"
                                      body:@"Account cancelled successfully."
                                      icon:[UIImage imageNamed:@"can_icon"]
                             confirmTitle:@"Confirm"
                              cancelTitle:nil
                            cancelPrimary:NO
                                   inView:host
                                onConfirm:^{
            [[HQITSessionManager shared] clearSession];
            [HQITHomeSessionState resetForLogout];
            [[HQITAppShell shared] showLogin];
        } onCancel:nil];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isClosing = NO;
        UIView *host = self.view.window ?: self.view;
        NSString *body = message.length
            ? message
            : @"Account cancellation failed, please check your order.";
        [HQITDialogs showWhiteConfirmTitle:@"Failed"
                                      body:body
                                      icon:[UIImage imageNamed:@"please_icon"]
                             confirmTitle:@"Confirm"
                              cancelTitle:nil
                            cancelPrimary:NO
                                   inView:host
                                onConfirm:nil
                                 onCancel:nil];
    }];
}

@end
