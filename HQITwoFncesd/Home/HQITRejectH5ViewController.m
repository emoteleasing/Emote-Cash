

#import "HQITRejectH5ViewController.h"
#import "HQITAppConfigHelper.h"
#import "HQITBuryRecorder.h"
#import "HQITDomainManager.h"
#import "HQITFontHelper.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import "HQITNetworkConstants.h"
#import "HQITSessionManager.h"
#import "HQITStorageKeys.h"
#import <Masonry/Masonry.h>
#import <WebKit/WebKit.h>

@interface HQITRejectH5WeakScriptHandler : NSObject <WKScriptMessageHandler>
@property (nonatomic, weak) id<WKScriptMessageHandler> target;
- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target;
@end

@implementation HQITRejectH5WeakScriptHandler
- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target {
    self = [super init];
    if (self) {
        _target = target;
    }
    return self;
}
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.target userContentController:userContentController didReceiveScriptMessage:message];
}
@end

@interface HQITRejectH5ViewController () <WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, copy) NSString *pageURLString;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, assign) BOOL hasInjectedRejectData;
@property (nonatomic, strong) HQITRejectH5WeakScriptHandler *scriptHandler;
@end

@implementation HQITRejectH5ViewController

+ (BOOL)isRejectH5Configured {
    return [HQITAppConfigHelper isRejectH5Configured];
}

+ (NSString *)configuredPageURLString {
    return [HQITAppConfigHelper rejectH5URLString];
}

- (instancetype)initWithPageURLString:(NSString *)urlString {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _pageURLString = [urlString copy];
    }
    return self;
}

- (void)dealloc {
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"iosHandler"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor whiteColor];
    [self buildNav];
    [self buildWeb];

    NSString *href = self.pageURLString.length > 0 ? self.pageURLString : [[self class] configuredPageURLString];
    NSURL *url = [self buildLoadURLFromHref:href];
    if (!url) {
        return;
    }
    [HQITHUDHelper showLoadingInView:self.view];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
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

#pragma mark - UI

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
    self.navTitleLabel.text = @"Accurate Recommendation";
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];
}

- (void)buildWeb {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.scriptHandler = [[HQITRejectH5WeakScriptHandler alloc] initWithTarget:self];
    [config.userContentController addScriptMessageHandler:self.scriptHandler name:@"iosHandler"];

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    [self.view addSubview:self.webView];
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];
}

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - URL / inject

- (NSURL *)buildLoadURLFromHref:(NSString *)href {
    NSString *normalized = [HQITAppConfigHelper normalizeURLString:href];
    if (normalized.length == 0) return nil;

    NSURLComponents *components = [NSURLComponents componentsWithString:normalized];
    if (!components) return nil;

    NSString *mobile = [[NSUserDefaults standardUserDefaults] stringForKey:HQITStorageKeyUserMobile] ?: @"";
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    if (components.queryItems.count > 0) {
        [items addObjectsFromArray:components.queryItems];
    }
    [items addObject:[NSURLQueryItem queryItemWithName:@"appId" value:HQITAppId]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"mobile" value:mobile]];
    components.queryItems = items;
    return components.URL;
}

- (void)injectRejectDataScriptIfNeeded {
    if (self.hasInjectedRejectData) return;

    HQITSessionManager *session = [HQITSessionManager shared];
    NSString *mobile = [[NSUserDefaults standardUserDefaults] stringForKey:HQITStorageKeyUserMobile] ?: @"";
    NSString *baseUrl = [HQITDomainManager shared].currentBaseURL ?: @"";
    NSDictionary *payload = @{
        @"appId": HQITAppId ?: @"",
        @"salt": HQITSalt ?: @"",
        @"mobile": mobile,
        @"baseUrl": baseUrl,
        @"userId": session.userId ?: @"",
        @"token": session.token ?: @"",
    };

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (!data || error) return;
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json.length == 0) return;

    NSString *escaped = [self sanitizeJSONString:json];
    NSString *js = [NSString stringWithFormat:@"rejectData('%@')", escaped];
    __weak typeof(self) weakSelf = self;
    [self.webView evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable jsError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!jsError) {
            self.hasInjectedRejectData = YES;
        }
    }];
}

- (NSString *)sanitizeJSONString:(NSString *)json {
    NSString *s = json ?: @"";
    s = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    s = [s stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    s = [s stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    return s;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.hasInjectedRejectData = NO;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [HQITHUDHelper hideLoadingInView:self.view];
    [self injectRejectDataScriptIfNeeded];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [HQITHUDHelper hideLoadingInView:self.view];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [HQITHUDHelper hideLoadingInView:self.view];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"iosHandler"]) return;
    if (![message.body isKindOfClass:[NSString class]]) return;
    NSString *body = (NSString *)message.body;
    if (![body hasPrefix:@"thirdUrl"]) return;
    [self handleThirdUrlMessage:body];
}

- (void)handleThirdUrlMessage:(NSString *)raw {
    NSString *s = [raw stringByReplacingOccurrencesOfString:@"thirdUrl=" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"type=" withString:@""];
    NSArray<NSString *> *parts = [s componentsSeparatedByString:@"&"];
    if (parts.count == 0) return;

    NSString *urlString = parts.firstObject;
    NSString *type = parts.count > 1 ? parts[1] : @"";
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    NSString *remark1 = type.length > 0 ? type : nil;
    [HQITBuryRecorder recordEventCode:502
                         eventContent:nil
                              remark1:remark1
                              remark2:nil
                              remark3:nil];

    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
