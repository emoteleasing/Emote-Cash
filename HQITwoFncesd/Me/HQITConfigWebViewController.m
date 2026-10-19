

#import "HQITConfigWebViewController.h"
#import "HQITAppConfigHelper.h"
#import "HQITFontHelper.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import <WebKit/WebKit.h>
#import <Masonry/Masonry.h>

@interface HQITConfigWebViewController () <WKNavigationDelegate>
@property (nonatomic, copy) NSString *configKey;
@property (nonatomic, copy) NSString *pageTitleText;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) WKWebView *webView;
@end

@implementation HQITConfigWebViewController

+ (instancetype)controllerWithHrefConfigKey:(NSString *)configKey pageTitle:(NSString *)pageTitle {
    HQITConfigWebViewController *vc = [[HQITConfigWebViewController alloc] init];
    vc.configKey = configKey;
    vc.pageTitleText = pageTitle;
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.hqit_hidesTabBarWhenPushed = YES;
    [self buildNav];
    [self buildWeb];

    NSString *url = [HQITAppConfigHelper stringForHrefConfigKey:self.configKey];
    if (url.length == 0) return;
    [HQITHUDHelper showLoadingInView:self.view];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
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

- (void)buildNav {
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

    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = self.pageTitleText.length ? self.pageTitleText : @"";
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textAlignment = NSTextAlignmentLeft;
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];
}

- (void)buildWeb {
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero];
    self.webView.navigationDelegate = self;
    [self.view addSubview:self.webView];
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];
}

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [HQITHUDHelper hideLoadingInView:self.view];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [HQITHUDHelper hideLoadingInView:self.view];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [HQITHUDHelper hideLoadingInView:self.view];
}

@end
