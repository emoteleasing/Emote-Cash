

#import "HQITOfficialWebsiteViewController.h"
#import "HQITFontHelper.h"
#import "HQITAppConfigHelper.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import <Masonry/Masonry.h>

static NSString * const kHQITOfficialWebsiteTip =
@"If you run into problems with the app, applications and repayments can also be completed on the official website. Saving the official website address is advised - tap to copy.";

@interface HQITOfficialWebsiteViewController ()
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UILabel *urlLabel;
@property (nonatomic, copy) NSString *urlRaw;
@end

@implementation HQITOfficialWebsiteViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [self refreshURL];
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

#pragma mark - Colors

- (UIColor *)urlColor {
    return [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
}

- (UIColor *)tipText {
    return [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
}

- (UIColor *)tipBg {
    return [UIColor colorWithRed:0xFF/255.0 green:0xF6/255.0 blue:0xE8/255.0 alpha:1];
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
    if (backImg) [self.backButton setImage:backImg forState:UIControlStateNormal];
    [self.backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];

    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = @"Official Website";
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    UIView *tipCard = [self tipCard];
    [self.view addSubview:tipCard];
    [tipCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(16);
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
    }];

    UIView *urlCard = [self urlCard];
    [self.view addSubview:urlCard];
    [urlCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(tipCard.mas_bottom).offset(12);
        make.left.right.equalTo(tipCard);
        make.height.mas_equalTo(56);
    }];
}

- (UIView *)tipCard {
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [self tipBg];
    box.layer.cornerRadius = 12;
    box.clipsToBounds = YES;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"with_icon"]
                                                                imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [box addSubview:iconView];
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(15);
        make.top.equalTo(box).offset(15);
        make.width.height.mas_equalTo(14);
    }];

    UILabel *tip = [[UILabel alloc] init];
    tip.numberOfLines = 0;
    tip.font = [HQITFontHelper regularFontOfSize:12];
    tip.textColor = [self tipText];
    tip.text = kHQITOfficialWebsiteTip;
    [box addSubview:tip];
    [tip mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(iconView.mas_right).offset(8);
        make.right.equalTo(box).offset(-15);
        make.top.equalTo(box).offset(15);
        make.bottom.equalTo(box).offset(-15);
    }];
    return box;
}

- (UIView *)urlCard {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 12;
    card.clipsToBounds = YES;

    self.urlLabel = [[UILabel alloc] init];
    self.urlLabel.font = [HQITFontHelper mediumFontOfSize:14];
    self.urlLabel.textColor = [self urlColor];
    self.urlLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [card addSubview:self.urlLabel];

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *copyImg = [[UIImage imageNamed:@"copy_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (copyImg) {
        [copyBtn setImage:copyImg forState:UIControlStateNormal];
    }
    copyBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [copyBtn addTarget:self action:@selector(onCopy) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:copyBtn];

    [copyBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(card).offset(-14);
        make.centerY.equalTo(card);
        make.width.height.mas_equalTo(36);
    }];
    [self.urlLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(card).offset(16);
        make.right.equalTo(copyBtn.mas_left).offset(-12);
        make.centerY.equalTo(card);
    }];
    return card;
}

#pragma mark - Data / Actions

- (void)refreshURL {
    NSString *url = [HQITAppConfigHelper fixedOfficialWebsiteURL];
    self.urlRaw = url ?: @"";
    self.urlLabel.text = url.length ? url : @"xxxxx";
}

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onCopy {
    NSString *t = [self.urlRaw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0) {
        [HQITHUDHelper showToast:@"No content to copy"];
        return;
    }
    [UIPasteboard generalPasteboard].string = t;
    [HQITHUDHelper showToast:@"Copied to clipboard"];
}

@end
