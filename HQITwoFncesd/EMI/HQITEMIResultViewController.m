

#import "HQITEMIResultViewController.h"
#import "HQITEMICalculator.h"
#import "HQITFontHelper.h"
#import "HQITHUDHelper.h"
#import "HQITClickGuard.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITSessionManager.h"
#import "HQITAppShell.h"
#import "HQITKYCNavigation.h"
#import "HQITNavigationBarStyle.h"
#import <Masonry/Masonry.h>

@interface HQITEMIDashedBorderView : UIView
@property (nonatomic, strong) CAShapeLayer *dashLayer;
@property (nonatomic, strong) UIColor *dashColor;
@end

@implementation HQITEMIDashedBorderView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _dashColor = [UIColor colorWithRed:0xF0/255.0 green:0x8A/255.0 blue:0x4B/255.0 alpha:1];
        self.backgroundColor = [UIColor colorWithRed:1.0 green:0.97 blue:0.94 alpha:1];
        self.layer.cornerRadius = 12;
        _dashLayer = [CAShapeLayer layer];
        _dashLayer.fillColor = UIColor.clearColor.CGColor;
        _dashLayer.strokeColor = _dashColor.CGColor;
        _dashLayer.lineWidth = 1;
        _dashLayer.lineDashPattern = @[@4, @3];
        [self.layer addSublayer:_dashLayer];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:12];
    self.dashLayer.path = path.CGPath;
    self.dashLayer.frame = self.bounds;
}
@end

@interface HQITEMIResultViewController ()
@property (nonatomic, strong) HQITEMIInputModel *input;
@property (nonatomic, strong) HQITEMIResultModel *result;
@property (nonatomic, assign) NSInteger userStatus;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *applyButton;
@end

@implementation HQITEMIResultViewController

- (instancetype)initWithInput:(HQITEMIInputModel *)input result:(HQITEMIResultModel *)result {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _input = input;
        _result = result;
        _userStatus = 10;
        self.hqit_hidesTabBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [HQITClickGuard unlockControl:self.applyButton];
    [self reloadUserStatus];
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
    if (fitted) {
        self.headerBg.image = fitted;
    }
}

#pragma mark - Colors

- (UIColor *)navy {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)grey {
    return [UIColor colorWithRed:0x8A/255.0 green:0x8F/255.0 blue:0x98/255.0 alpha:1];
}

- (UIColor *)valueRed {
    return [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
}

- (UIColor *)border {
    return [UIColor colorWithRed:0xE8/255.0 green:0xEA/255.0 blue:0xEE/255.0 alpha:1];
}

#pragma mark - UI

- (void)buildUI {
    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];

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
    if (backImg) {
        [self.backButton setImage:backImg forState:UIControlStateNormal];
    }
    [self.backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"EMI Calculator";
    self.titleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentLeft;
    [self.navContent addSubview:self.titleLabel];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.applyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self stylePrimaryButton:self.applyButton title:@"Apply Now"];
    [self.applyButton addTarget:self action:@selector(onApply) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.applyButton];
    [self.applyButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(40);
        make.right.equalTo(self.view).offset(-40);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16);
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

    HQITEMIDashedBorderView *resultsCard = [[HQITEMIDashedBorderView alloc] init];
    [self.contentView addSubview:resultsCard];
    [resultsCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
    }];

    UILabel *resultsTitle = [[UILabel alloc] init];
    resultsTitle.text = @"Calculation Results";
    resultsTitle.font = [HQITFontHelper regularFontOfSize:13];
    resultsTitle.textColor = [self grey];
    [resultsCard addSubview:resultsTitle];
    [resultsTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(resultsCard).offset(14);
        make.left.equalTo(resultsCard).offset(16);
        make.right.equalTo(resultsCard).offset(-16);
    }];

    UIView *row1 = [self resultRowTitle:@"Total payment" value:[HQITEMICalculator formatCurrency:self.result.totalRepayment]];
    UIView *row2 = [self resultRowTitle:@"Monthly EMI" value:[HQITEMICalculator formatCurrency:self.result.monthlyPayment]];
    UIView *row3 = [self resultRowTitle:@"Total interest" value:[HQITEMICalculator formatCurrency:self.result.totalInterest]];
    UIView *line1 = [self thinLine];
    UIView *line2 = [self thinLine];
    [resultsCard addSubview:row1];
    [resultsCard addSubview:line1];
    [resultsCard addSubview:row2];
    [resultsCard addSubview:line2];
    [resultsCard addSubview:row3];

    [row1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(resultsTitle.mas_bottom).offset(12);
        make.left.right.equalTo(resultsCard).insets(UIEdgeInsetsMake(0, 16, 0, 16));
        make.height.mas_equalTo(36);
    }];
    [line1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(row1.mas_bottom);
        make.left.right.equalTo(row1);
        make.height.mas_equalTo(1);
    }];
    [row2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(line1.mas_bottom);
        make.left.right.height.equalTo(row1);
    }];
    [line2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(row2.mas_bottom);
        make.left.right.height.equalTo(line1);
    }];
    [row3 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(line2.mas_bottom);
        make.left.right.height.equalTo(row1);
        make.bottom.equalTo(resultsCard).offset(-10);
    }];

    UIView *inputCard = [[UIView alloc] init];
    inputCard.backgroundColor = [UIColor whiteColor];
    inputCard.layer.cornerRadius = 16;
    [self.contentView addSubview:inputCard];
    [inputCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(resultsCard.mas_bottom).offset(16);
        make.left.right.equalTo(resultsCard);
        make.bottom.equalTo(self.contentView).offset(-24);
    }];

    UIView *a = [self summaryFieldTitle:@"Total Loan Amount" value:[NSString stringWithFormat:@"%ld", (long)self.input.amount] suffix:@"₹"];
    UIView *d = [self summaryFieldTitle:@"Duration" value:[NSString stringWithFormat:@"%ld", (long)self.input.durationYears] suffix:@"year"];
    UIView *r = [self summaryFieldTitle:@"Interest Rate" value:[NSString stringWithFormat:@"%ld", (long)self.input.interestRate] suffix:@"%"];
    [inputCard addSubview:a];
    [inputCard addSubview:d];
    [inputCard addSubview:r];
    [a mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(inputCard).offset(16);
        make.left.equalTo(inputCard).offset(16);
        make.right.equalTo(inputCard).offset(-16);
    }];
    [d mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(a.mas_bottom).offset(14);
        make.left.right.equalTo(a);
    }];
    [r mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(d.mas_bottom).offset(14);
        make.left.right.equalTo(a);
        make.bottom.equalTo(inputCard).offset(-16);
    }];
}

- (UIView *)resultRowTitle:(NSString *)title value:(NSString *)value {
    UIView *row = [[UIView alloc] init];
    UILabel *t = [[UILabel alloc] init];
    t.text = title;
    t.font = [HQITFontHelper regularFontOfSize:14];
    t.textColor = [self navy];
    UILabel *v = [[UILabel alloc] init];
    v.text = value;
    v.font = [HQITFontHelper boldFontOfSize:14];
    v.textColor = [self valueRed];
    v.textAlignment = NSTextAlignmentRight;
    [row addSubview:t];
    [row addSubview:v];
    [t mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.centerY.equalTo(row);
    }];
    [v mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.centerY.equalTo(row);
        make.left.greaterThanOrEqualTo(t.mas_right).offset(8);
    }];
    return row;
}

- (UIView *)thinLine {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [UIColor colorWithRed:0xEE/255.0 green:0xF0/255.0 blue:0xF3/255.0 alpha:1];
    return line;
}

- (UIView *)summaryFieldTitle:(NSString *)title value:(NSString *)value suffix:(NSString *)suffix {
    UIView *wrap = [[UIView alloc] init];
    UILabel *lab = [[UILabel alloc] init];
    lab.text = title;
    lab.font = [HQITFontHelper boldFontOfSize:14];
    lab.textColor = [self navy];
    [wrap addSubview:lab];
    [lab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(wrap);
    }];

    UIView *box = [[UIView alloc] init];
    box.layer.cornerRadius = 10;
    box.layer.borderWidth = 1;
    box.layer.borderColor = [self border].CGColor;
    [wrap addSubview:box];
    [box mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(lab.mas_bottom).offset(8);
        make.left.right.bottom.equalTo(wrap);
        make.height.mas_equalTo(44);
    }];

    UILabel *suf = [[UILabel alloc] init];
    suf.text = suffix;
    suf.font = [HQITFontHelper regularFontOfSize:14];
    suf.textColor = [self grey];
    [box addSubview:suf];
    [suf mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(box).offset(-12);
        make.centerY.equalTo(box);
    }];

    UILabel *val = [[UILabel alloc] init];
    val.text = value;
    val.font = [HQITFontHelper regularFontOfSize:15];
    val.textColor = [self navy];
    [box addSubview:val];
    [val mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(12);
        make.right.equalTo(suf.mas_left).offset(-8);
        make.centerY.equalTo(box);
    }];
    return wrap;
}

- (void)stylePrimaryButton:(UIButton *)btn title:(NSString *)title {
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat w = MAX(bg.size.width, 1);
        CGFloat h = MAX(bg.size.height, 1);
        UIEdgeInsets insets = UIEdgeInsetsMake(h * 0.45, w * 0.45, h * 0.45, w * 0.45);
        [btn setBackgroundImage:[bg resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch]
                       forState:UIControlStateNormal];
    } else {
        btn.backgroundColor = [self valueRed];
        btn.layer.cornerRadius = 22;
        btn.clipsToBounds = YES;
    }
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
}


- (void)reloadUserStatus {
    if (![HQITSessionManager shared].isLoggedIn) {
        self.userStatus = 10;
        [self updateApplyVisibility];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/user/info"
                                         signedData:@{}
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        NSDictionary *data = [response.data isKindOfClass:[NSDictionary class]] ? response.data : nil;
        NSInteger status = [data[@"userStatus"] integerValue];
        if (status == 0 && data[@"userStatus"] == nil) {
            status = 10;
        }
        weakSelf.userStatus = status;
        [weakSelf updateApplyVisibility];
    } failure:^(NSError *error, NSString *message) {
        [weakSelf updateApplyVisibility];
    }];
}

- (void)updateApplyVisibility {
    self.applyButton.hidden = NO;
    [self.applyButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16);
    }];
}

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onApply {
    if (![HQITClickGuard tryLockControl:self.applyButton]) return;
    if (![HQITSessionManager shared].isLoggedIn) {
        [HQITClickGuard unlockControl:self.applyButton];
        [[HQITAppShell shared] showLogin];
        return;
    }
    if (self.userStatus == 10) {
        [HQITKYCNavigation startFrom:self entry:HQITKYCEntryEMI];
        return;
    }
    UITabBarController *tab = self.tabBarController;
    UINavigationController *nav = self.navigationController;
    if (tab) {
        tab.selectedIndex = 0;
    }
    [nav popToRootViewControllerAnimated:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
}

@end
