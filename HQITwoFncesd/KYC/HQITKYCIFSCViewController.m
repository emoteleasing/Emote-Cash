
#import "HQITKYCIFSCViewController.h"
#import "HQITNetworkClient.h"
#import "HQITFontHelper.h"
#import "HQITDialogs.h"
#import "HQITCategoryText.h"
#import "HQITClickGuard.h"
#import "HQITHUDHelper.h"
#import "HQITNavigationBarStyle.h"
#import <Masonry/Masonry.h>

typedef NS_ENUM(NSInteger, HQITIFSCLevel) {
    HQITIFSCLevelState = 0,
    HQITIFSCLevelCity,
    HQITIFSCLevelBank,
    HQITIFSCLevelBranch,
};

@interface HQITKYCIFSCViewController ()
@property (nonatomic, copy) HQITKYCIFSCPickedBlock onPicked;

@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIStackView *formStack;
@property (nonatomic, strong) UIButton *continueButton;

@property (nonatomic, copy, nullable) NSString *stateValue;
@property (nonatomic, copy, nullable) NSString *cityValue;
@property (nonatomic, copy, nullable) NSString *bankValue;
@property (nonatomic, copy, nullable) NSString *branchValue;
@property (nonatomic, copy, nullable) NSString *stateKey;
@property (nonatomic, copy, nullable) NSString *cityKey;
@property (nonatomic, copy, nullable) NSString *bankKey;
@property (nonatomic, copy, nullable) NSString *branchKey;

@property (nonatomic, strong) NSArray<UILabel *> *valueLabels;
@property (nonatomic, assign) BOOL isResolving;
@end

@implementation HQITKYCIFSCViewController

- (instancetype)initWithOnPicked:(HQITKYCIFSCPickedBlock)onPicked {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _onPicked = [onPicked copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self buildUI];
    [self reloadValues];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [HQITClickGuard unlockControl:self.continueButton];
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

- (void)hqit_setupBackButtonIfNeeded {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:[[UIView alloc] init]];
    self.navigationItem.hidesBackButton = YES;
}

#pragma mark - Colors

- (UIColor *)color102B4B {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)placeholderColor {
    return [UIColor colorWithRed:0xC0/255.0 green:0xC4/255.0 blue:0xCC/255.0 alpha:1];
}

- (UIColor *)fieldFillColor {
    return [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
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
    [self.backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];

    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = [HQITCategoryText textForKey:@"m55" defaultText:@"Find IFSC"];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.continueButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.continueButton.clipsToBounds = YES;
    self.continueButton.layer.cornerRadius = 10;
    UIImage *btnBg = [UIImage imageNamed:@"button_bg"];
    if (btnBg) {
        CGFloat bw = MAX(btnBg.size.width, 1), bh = MAX(btnBg.size.height, 1);
        [self.continueButton setBackgroundImage:[btnBg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                       resizingMode:UIImageResizingModeStretch]
                                       forState:UIControlStateNormal];
    } else {
        self.continueButton.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    }
    [self.continueButton setTitle:[HQITCategoryText textForKey:@"m65" defaultText:@"Continue"]
                         forState:UIControlStateNormal];
    [self.continueButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.continueButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.continueButton addTarget:self action:@selector(onContinue) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.continueButton];
    [self.continueButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
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
        make.bottom.equalTo(self.continueButton.mas_top).offset(-12);
    }];

    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor whiteColor];
    self.cardView.layer.cornerRadius = 16;
    self.cardView.clipsToBounds = YES;
    [self.scrollView addSubview:self.cardView];
    [self.cardView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.scrollView).offset(8);
        make.left.equalTo(self.scrollView).offset(16);
        make.right.equalTo(self.scrollView).offset(-16);
        make.width.equalTo(self.scrollView).offset(-32);
        make.bottom.equalTo(self.scrollView).offset(-16);
    }];

    self.formStack = [[UIStackView alloc] init];
    self.formStack.axis = UILayoutConstraintAxisVertical;
    self.formStack.spacing = 16;
    [self.cardView addSubview:self.formStack];
    [self.formStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView).offset(20);
        make.left.equalTo(self.cardView).offset(16);
        make.right.equalTo(self.cardView).offset(-16);
        make.bottom.equalTo(self.cardView).offset(-20);
    }];

    NSArray *titles = @[
        [HQITCategoryText textForKey:@"m57" defaultText:@"Bank State"],
        [HQITCategoryText textForKey:@"m58" defaultText:@"Bank City"],
        [HQITCategoryText textForKey:@"m59" defaultText:@"Bank Name"],
        [HQITCategoryText textForKey:@"m60" defaultText:@"Bank Branch"],
    ];
    static const NSInteger kHQITIFSCValueLabelTag = 71001;
    NSMutableArray *labels = [NSMutableArray array];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIView *block = [self selectBlockWithTitle:titles[i] level:i];
        [self.formStack addArrangedSubview:block];
        UILabel *valueLab = [block viewWithTag:kHQITIFSCValueLabelTag];
        if ([valueLab isKindOfClass:[UILabel class]]) [labels addObject:valueLab];
    }
    self.valueLabels = labels;
}

- (UIView *)selectBlockWithTitle:(NSString *)title level:(NSInteger)level {
    UIView *wrap = [[UIView alloc] init];

    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = title;
    titleLab.font = [HQITFontHelper boldFontOfSize:14];
    titleLab.textColor = [self color102B4B];
    [wrap addSubview:titleLab];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(wrap);
    }];

    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [self fieldFillColor];
    box.layer.cornerRadius = 10;
    box.clipsToBounds = YES;
    [wrap addSubview:box];
    [box mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLab.mas_bottom).offset(8);
        make.left.right.bottom.equalTo(wrap);
        make.height.mas_equalTo(44);
    }];

    UILabel *value = [[UILabel alloc] init];
    value.tag = 71001;
    value.font = [HQITFontHelper regularFontOfSize:13];
    value.text = [HQITCategoryText textForKey:@"m56" defaultText:@"Please choose"];
    value.textColor = [self placeholderColor];
    [box addSubview:value];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"kycplease_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [box addSubview:chevron];

    [value mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(14);
        make.centerY.equalTo(box);
        make.right.equalTo(chevron.mas_left).offset(-8);
    }];
    [chevron mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(box).offset(-15);
        make.centerY.equalTo(box);
        make.width.height.mas_equalTo(14);
    }];

    UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
    hit.tag = level;
    [hit addTarget:self action:@selector(onSelectLevel:) forControlEvents:UIControlEventTouchUpInside];
    [box addSubview:hit];
    [hit mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(box);
    }];
    return wrap;
}

- (void)reloadValues {
    NSArray *values = @[
        self.stateValue ?: @"",
        self.cityValue ?: @"",
        self.bankValue ?: @"",
        self.branchValue ?: @"",
    ];
    for (NSInteger i = 0; i < (NSInteger)self.valueLabels.count; i++) {
        UILabel *lab = self.valueLabels[i];
        NSString *v = values[i];
        BOOL empty = v.length == 0;
        lab.text = empty ? [HQITCategoryText textForKey:@"m56" defaultText:@"Please choose"] : v;
        lab.textColor = empty ? [self placeholderColor] : [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
    }
}

#pragma mark - Actions

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onSelectLevel:(UIButton *)sender {
    HQITIFSCLevel level = (HQITIFSCLevel)sender.tag;
    if (level == HQITIFSCLevelCity && self.stateValue.length == 0) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k54" defaultText:@"Please select bank state first."]];
        return;
    }
    if (level == HQITIFSCLevelBank && self.cityValue.length == 0) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k55" defaultText:@"Please select bank city first."]];
        return;
    }
    if (level == HQITIFSCLevelBranch && self.bankValue.length == 0) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k56" defaultText:@"Please select bank name first."]];
        return;
    }

    NSMutableDictionary *unsignedData = [NSMutableDictionary dictionary];
    if (level >= HQITIFSCLevelCity && self.stateKey.length) {
        unsignedData[@"state"] = self.stateKey;
    }
    if (level >= HQITIFSCLevelBank && self.cityKey.length) {
        unsignedData[@"city"] = self.cityKey;
    }
    if (level >= HQITIFSCLevelBranch && self.bankKey.length) {
        unsignedData[@"bank"] = self.bankKey;
    }

    [HQITHUDHelper showLoading];
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/sys/ifsc"
                                         signedData:@{}
                                       unsignedData:unsignedData.count ? unsignedData : nil
                                        showLoading:@NO
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        [HQITHUDHelper hideLoading];
        NSArray<HQITSelectionOption *> *opts = [weakSelf optionsFromResponse:response.data];
        [weakSelf presentOptions:opts forLevel:level];
    } failure:^(NSError *error, NSString *message) {
        [HQITHUDHelper hideLoading];
    }];
}

- (NSArray<HQITSelectionOption *> *)optionsFromResponse:(id)raw {
    NSArray *list = nil;
    if ([raw isKindOfClass:[NSDictionary class]]) {
        id v = raw[@"buttonList"] ?: raw[@"list"] ?: raw[@"data"];
        if ([v isKindOfClass:[NSArray class]]) list = v;
    } else if ([raw isKindOfClass:[NSArray class]]) {
        list = raw;
    }
    NSMutableArray *opts = [NSMutableArray array];
    for (id item in list ?: @[]) {
        if ([item isKindOfClass:[NSString class]]) {
            NSString *s = [(NSString *)item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (s.length && ![s isEqualToString:@"(null)"]) {
                [opts addObject:[HQITSelectionOption optionWithKey:s label:s]];
            }
            continue;
        }
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = (NSDictionary *)item;
        NSString *key = [NSString stringWithFormat:@"%@", d[@"buttonKey"] ?: d[@"key"] ?: d[@"name"] ?: d[@"value"] ?: @""];
        NSString *label = [NSString stringWithFormat:@"%@", d[@"buttonLabel"] ?: d[@"exit"] ?: d[@"label"] ?: d[@"name"] ?: key];
        if (key.length == 0 || [key isEqualToString:@"(null)"]) continue;
        if ([label isEqualToString:@"(null)"]) label = key;
        [opts addObject:[HQITSelectionOption optionWithKey:key label:label.length ? label : key]];
    }
    return opts;
}

- (void)presentOptions:(NSArray<HQITSelectionOption *> *)options forLevel:(HQITIFSCLevel)level {
    if (options.count == 0) {
        [HQITHUDHelper showToast:@"No options available"];
        return;
    }
    NSArray *titles = @[
        [HQITCategoryText textForKey:@"m57" defaultText:@"Bank State"],
        [HQITCategoryText textForKey:@"m58" defaultText:@"Bank City"],
        [HQITCategoryText textForKey:@"m59" defaultText:@"Bank Name"],
        [HQITCategoryText textForKey:@"m60" defaultText:@"Bank Branch"],
    ];
    NSString *sheetTitle = [NSString stringWithFormat:@"Select %@", titles[level]];
    NSString *selected = nil;
    if (level == HQITIFSCLevelState) selected = self.stateKey;
    else if (level == HQITIFSCLevelCity) selected = self.cityKey;
    else if (level == HQITIFSCLevelBank) selected = self.bankKey;
    else selected = self.branchKey;

    __weak typeof(self) weakSelf = self;
    [HQITDialogs showSelectionTitle:sheetTitle
                            options:options
                        selectedKey:selected
                             inView:self.view.window ?: self.view
                         onConfirm:^(HQITSelectionOption *option) {
        [weakSelf applySelection:option forLevel:level];
    } onCancel:nil];
}

- (void)applySelection:(HQITSelectionOption *)option forLevel:(HQITIFSCLevel)level {
    NSString *key = option.key.length ? option.key : option.label;
    NSString *label = option.label.length ? option.label : option.key;
    if (level == HQITIFSCLevelState) {
        self.stateKey = key;
        self.stateValue = label;
        self.cityKey = nil; self.cityValue = nil;
        self.bankKey = nil; self.bankValue = nil;
        self.branchKey = nil; self.branchValue = nil;
    } else if (level == HQITIFSCLevelCity) {
        self.cityKey = key;
        self.cityValue = label;
        self.bankKey = nil; self.bankValue = nil;
        self.branchKey = nil; self.branchValue = nil;
    } else if (level == HQITIFSCLevelBank) {
        self.bankKey = key;
        self.bankValue = label;
        self.branchKey = nil; self.branchValue = nil;
    } else {
        self.branchKey = key;
        self.branchValue = label;
    }
    [self reloadValues];
}

- (void)onContinue {
    if (self.isResolving) return;
    if (![HQITClickGuard tryLockControl:self.continueButton]) return;

    if (self.stateValue.length == 0) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k54" defaultText:@"Please select bank state first."]];
        [HQITClickGuard unlockControl:self.continueButton];
        return;
    }
    if (self.cityValue.length == 0) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k55" defaultText:@"Please select bank city first."]];
        [HQITClickGuard unlockControl:self.continueButton];
        return;
    }
    if (self.bankValue.length == 0) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k56" defaultText:@"Please select bank name first."]];
        [HQITClickGuard unlockControl:self.continueButton];
        return;
    }
    if (self.branchValue.length == 0) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k57" defaultText:@"Please select bank branch first."]];
        [HQITClickGuard unlockControl:self.continueButton];
        return;
    }

    self.isResolving = YES;
    self.continueButton.enabled = NO;
    self.continueButton.alpha = 0.5;

    NSDictionary *unsignedData = @{
        @"state": self.stateKey ?: @"",
        @"city": self.cityKey ?: @"",
        @"bank": self.bankKey ?: @"",
        @"branch": self.branchKey ?: @"",
    };
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/sys/ifsc"
                                         signedData:@{}
                                       unsignedData:unsignedData
                                        showLoading:@YES
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isResolving = NO;
        self.continueButton.enabled = YES;
        self.continueButton.alpha = 1.0;
        [HQITClickGuard unlockControl:self.continueButton];
        NSString *code = [self parseIFSCCode:response.data];
        if (code.length == 0) {
            [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"k59"
                                                     defaultText:@"Failed to resolve IFSC. Please try again."]];
            return;
        }
        if (self.onPicked) self.onPicked(code);
        [self.navigationController popViewControllerAnimated:YES];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isResolving = NO;
        self.continueButton.enabled = YES;
        self.continueButton.alpha = 1.0;
        [HQITClickGuard unlockControl:self.continueButton];
    }];
}

- (BOOL)looksLikeIFSC:(NSString *)code {
    if (code.length != 11) return NO;
    static NSRegularExpression *re;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z]{4}0[A-Za-z0-9]{6}$"
                                                       options:0
                                                         error:nil];
    });
    if (!re) return NO;
    NSRange r = NSMakeRange(0, code.length);
    return [re numberOfMatchesInString:code options:0 range:r] == 1;
}

- (NSString *)parseIFSCCode:(id)raw {
    if ([raw isKindOfClass:[NSString class]]) {
        NSString *s = [[(NSString *)raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        return [self looksLikeIFSC:s] ? s : @"";
    }
    if ([raw isKindOfClass:[NSDictionary class]]) {
        NSDictionary *d = (NSDictionary *)raw;
        for (NSString *k in @[@"ifscCode", @"ifsc", @"IFSC", @"ifscCode", @"code", @"pause", @"pause"]) {
            id v = d[k];
            if ([v isKindOfClass:[NSString class]]) {
                NSString *s = [[(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
                if ([self looksLikeIFSC:s]) return s;
            } else if (v && ![v isKindOfClass:[NSNull class]]) {
                NSString *s = [[[NSString stringWithFormat:@"%@", v] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
                if ([self looksLikeIFSC:s]) return s;
            }
        }
        id list = d[@"buttonList"] ?: d[@"list"];
        if ([list isKindOfClass:[NSArray class]]) {
            for (id first in (NSArray *)list) {
                NSString *parsed = [self parseIFSCCode:first];
                if (parsed.length) return parsed;
            }
        }
    }
    if ([raw isKindOfClass:[NSArray class]]) {
        for (id first in (NSArray *)raw) {
            NSString *parsed = [self parseIFSCCode:first];
            if (parsed.length) return parsed;
        }
    }
    return @"";
}

@end
