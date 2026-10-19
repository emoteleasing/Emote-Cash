

#import "HQITRepaymentInstructionsViewController.h"
#import "HQITFontHelper.h"
#import "HQITAppConfigHelper.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import <Masonry/Masonry.h>

@interface HQITRepaymentInstructionsViewController ()
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *emailValue;
@property (nonatomic, strong) UILabel *webValue;
@property (nonatomic, copy) NSString *emailRaw;
@property (nonatomic, copy) NSString *webRaw;
@end

@implementation HQITRepaymentInstructionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [self refreshConfigValues];
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

- (UIColor *)valueColor {
    return [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
}

- (UIColor *)labelGray {
    return [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1];
}

- (UIColor *)bodyGray {
    return [UIColor colorWithRed:0x55/255.0 green:0x55/255.0 blue:0x55/255.0 alpha:1];
}

- (UIColor *)divider {
    return [UIColor colorWithRed:0xEE/255.0 green:0xEE/255.0 blue:0xEE/255.0 alpha:1];
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
    self.navTitleLabel.text = @"Repayment instructions";
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.textAlignment = NSTextAlignmentLeft;
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.bottom.equalTo(self.view);
    }];

    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];

    UIView *emailCard = [self copyCardTitle:@"Customer service email"
                                valueLabel:&_emailValue
                                    action:@selector(copyEmail)];
    UIView *webCard = [self copyCardTitle:@"Official website link"
                               valueLabel:&_webValue
                                   action:@selector(copyWeb)];
    UIView *tipsCard = [self tipsCard];

    [self.contentView addSubview:emailCard];
    [self.contentView addSubview:webCard];
    [self.contentView addSubview:tipsCard];

    [emailCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(4);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
    }];
    [webCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(emailCard.mas_bottom).offset(12);
        make.left.right.equalTo(emailCard);
    }];
    [tipsCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(webCard.mas_bottom).offset(12);
        make.left.right.equalTo(emailCard);
        make.bottom.equalTo(self.contentView).offset(-24);
    }];
}

- (UIView *)whiteCard {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 12;
    card.clipsToBounds = YES;
    return card;
}

- (UIView *)copyCardTitle:(NSString *)title valueLabel:(UILabel * __strong *)outLab action:(SEL)action {
    UIView *card = [self whiteCard];

    UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
    hit.backgroundColor = [UIColor clearColor];
    [hit addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:hit];
    [hit mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(card);
    }];

    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = title;
    titleLab.font = [HQITFontHelper regularFontOfSize:12];
    titleLab.textColor = [self labelGray];
    [card addSubview:titleLab];

    UILabel *valueLab = [[UILabel alloc] init];
    valueLab.font = [HQITFontHelper regularFontOfSize:13];
    valueLab.textColor = [self valueColor];
    valueLab.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [card addSubview:valueLab];
    *outLab = valueLab;

    UIImageView *copyIcon = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"copy_icon"]
                                                                imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    copyIcon.contentMode = UIViewContentModeScaleAspectFit;
    copyIcon.userInteractionEnabled = NO;
    [card addSubview:copyIcon];

    [copyIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(card).offset(-14);
        make.centerY.equalTo(card);
        make.width.height.mas_equalTo(36);
    }];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(14);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(copyIcon.mas_left).offset(-12);
    }];
    [valueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLab.mas_bottom).offset(6);
        make.left.right.equalTo(titleLab);
        make.bottom.equalTo(card).offset(-14);
    }];

    return card;
}

- (UIView *)tipsCard {
    UIView *card = [self whiteCard];

    NSString *officialWeb = [HQITAppConfigHelper fixedOfficialWebsiteURL];
    NSArray<NSString *> *paragraphs = @[
        [NSString stringWithFormat:
         @"For repayments, please obtain the repayment link from the app first. Should the app be unavailable, you can also repay by signing in on our official website: %@. Any repayment link that differs from what appears in the app or on the official website will be treated as a failed repayment.",
         officialWeb],
        @"If you are asked to break the full repayment into several payments, or receive a repayment link that does not match the one shown in the app or on the official website, reach out to customer service for help. Once the case is confirmed, the service fee will be waived for you.",
        @"Should anything look suspicious while you are repaying, contact customer service by email first. We will help you sort out the issue without delay."
    ];

    UIView *last = nil;
    for (NSInteger i = 0; i < (NSInteger)paragraphs.count; i++) {
        UILabel *lab = [[UILabel alloc] init];
        lab.numberOfLines = 0;
        lab.font = [HQITFontHelper regularFontOfSize:13];
        lab.textColor = [self bodyGray];
        lab.text = paragraphs[i];
        [card addSubview:lab];
        [lab mas_makeConstraints:^(MASConstraintMaker *make) {
            if (last) {
                make.top.equalTo(last.mas_bottom).offset(14);
            } else {
                make.top.equalTo(card).offset(16);
            }
            make.left.equalTo(card).offset(16);
            make.right.equalTo(card).offset(-16);
            if (i == (NSInteger)paragraphs.count - 1) {
                make.bottom.equalTo(card).offset(-16);
            }
        }];

        if (i < (NSInteger)paragraphs.count - 1) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = [self divider];
            [card addSubview:line];
            [line mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(lab.mas_bottom).offset(14);
                make.left.equalTo(card).offset(16);
                make.right.equalTo(card).offset(-16);
                make.height.mas_equalTo(1.0 / UIScreen.mainScreen.scale);
            }];
            last = line;
        } else {
            last = lab;
        }
    }
    return card;
}

#pragma mark - Data / Actions

- (void)refreshConfigValues {
    NSString *email = [HQITAppConfigHelper fixedCustomerServiceEmail];
    NSString *web = [HQITAppConfigHelper fixedOfficialWebsiteURL];
    self.emailRaw = email ?: @"";
    self.webRaw = web ?: @"";
    self.emailValue.text = email.length ? email : @"—";
    self.webValue.text = web.length ? web : @"—";
}

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)copyString:(NSString *)s {
    NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0 || [t isEqualToString:@"—"]) {
        [HQITHUDHelper showToast:@"No content to copy"];
        return;
    }
    [UIPasteboard generalPasteboard].string = t;
    [HQITHUDHelper showToast:@"Copied to clipboard"];
}

- (void)copyEmail { [self copyString:self.emailRaw.length ? self.emailRaw : self.emailValue.text]; }
- (void)copyWeb { [self copyString:self.webRaw.length ? self.webRaw : self.webValue.text]; }

@end
