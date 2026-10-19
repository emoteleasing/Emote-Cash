

#import "HQITBankAccountViewController.h"
#import "HQITBankAccountViewModel.h"
#import "HQITBankAccountEditViewController.h"
#import "HQITFontHelper.h"
#import "HQITNavigationBarStyle.h"
#import "HQITHUDHelper.h"
#import "HQITClickGuard.h"
#import <Masonry/Masonry.h>

static NSString * const kHQITBankTipText =
@"Clicking the bank card logo, you can modify the information. But when your loan order is under review, you can not modify bank account information.";

@interface HQITBankAccountCardView : UIView
@property (nonatomic, strong) UIImageView *bgView;
@property (nonatomic, strong) UIImageView *typeIcon;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UILabel *numberTitleLab;
@property (nonatomic, strong) UILabel *numberLab;
@property (nonatomic, strong) UILabel *nameLab;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, copy, nullable) void (^onEdit)(void);
- (void)applyItem:(HQITBankAccountItem *)item showsEdit:(BOOL)showsEdit;
@end

@implementation HQITBankAccountCardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 16;

        self.bgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bank_bg"]];
        self.bgView.contentMode = UIViewContentModeScaleToFill;
        self.bgView.clipsToBounds = YES;
        self.bgView.userInteractionEnabled = YES;
        [self addSubview:self.bgView];
        [self.bgView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];

        self.typeIcon = [[UIImageView alloc] init];
        self.typeIcon.image = [UIImage imageNamed:@"bank_icon_b"];
        self.typeIcon.contentMode = UIViewContentModeScaleAspectFit;
        [self.bgView addSubview:self.typeIcon];

        self.typeLabel = [[UILabel alloc] init];
        self.typeLabel.text = @"Bank Account";
        self.typeLabel.textColor = [UIColor whiteColor];
        self.typeLabel.font = [HQITFontHelper boldFontOfSize:13];
        [self.bgView addSubview:self.typeLabel];

        self.editButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *edit = [UIImage imageNamed:@"edit_icon"];
        if (edit) {
            [self.editButton setImage:[edit imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                             forState:UIControlStateNormal];
        } else {
            UIImageSymbolConfiguration *penCfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium];
            UIImage *pen = [[UIImage systemImageNamed:@"pencil" withConfiguration:penCfg]
                            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.editButton setImage:pen forState:UIControlStateNormal];
            self.editButton.tintColor = [UIColor whiteColor];
            self.editButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
            self.editButton.layer.cornerRadius = 8;
            self.editButton.layer.borderWidth = 1;
            self.editButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.55].CGColor;
        }
        [self.editButton addTarget:self action:@selector(onEditTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.bgView addSubview:self.editButton];

        self.numberTitleLab = [[UILabel alloc] init];
        self.numberTitleLab.text = @"Bank Account Number";
        self.numberTitleLab.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.55];
        self.numberTitleLab.font = [HQITFontHelper regularFontOfSize:12];
        [self.bgView addSubview:self.numberTitleLab];

        self.numberLab = [[UILabel alloc] init];
        self.numberLab.textColor = [UIColor whiteColor];
        self.numberLab.font = [HQITFontHelper boldFontOfSize:17];
        self.numberLab.numberOfLines = 2;
        self.numberLab.adjustsFontSizeToFitWidth = YES;
        self.numberLab.minimumScaleFactor = 0.7;
        [self.bgView addSubview:self.numberLab];

        self.nameLab = [[UILabel alloc] init];
        self.nameLab.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.90];
        self.nameLab.font = [HQITFontHelper boldFontOfSize:14];
        [self.bgView addSubview:self.nameLab];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onEditTapped)];
        [self.bgView addGestureRecognizer:tap];

        [self.typeIcon mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bgView).offset(20);
            make.top.equalTo(self.bgView).offset(20);
            make.width.height.mas_equalTo(28);
        }];
        [self.typeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.typeIcon.mas_right).offset(8);
            make.centerY.equalTo(self.typeIcon);
            make.right.lessThanOrEqualTo(self.editButton.mas_left).offset(-8);
        }];
        [self.editButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.bgView).offset(-20);
            make.centerY.equalTo(self.typeIcon);
            make.width.height.mas_equalTo(28);
        }];
        [self.numberTitleLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bgView).offset(20);
            make.top.equalTo(self.typeIcon.mas_bottom).offset(32);
            make.right.equalTo(self.bgView).offset(-20);
        }];
        [self.numberLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bgView).offset(20);
            make.right.equalTo(self.bgView).offset(-20);
            make.top.equalTo(self.numberTitleLab.mas_bottom).offset(2);
        }];
        [self.nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bgView).offset(20);
            make.right.equalTo(self.bgView).offset(-20);
            make.bottom.equalTo(self.bgView).offset(-20);
        }];
    }
    return self;
}

- (void)applyItem:(HQITBankAccountItem *)item showsEdit:(BOOL)showsEdit {
    self.numberLab.text = item.accountNoDisplay.length ? item.accountNoDisplay : @"—";
    NSString *name = item.accountName.length ? item.accountName : @"—";
    self.nameLab.text = [name uppercaseString];
    self.editButton.hidden = !showsEdit;
    self.bgView.gestureRecognizers.firstObject.enabled = showsEdit;
    self.userInteractionEnabled = YES;
}

- (void)onEditTapped {
    if (self.editButton.hidden) return;
    if (self.onEdit) self.onEdit();
}

@end

@interface HQITBankAccountViewController ()
@property (nonatomic, strong) HQITBankAccountViewModel *viewModel;
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) HQITBankAccountCardView *cardView;
@property (nonatomic, strong) UIView *tipView;
@property (nonatomic, strong) UIView *emptyView;
@end

@implementation HQITBankAccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    self.viewModel = [[HQITBankAccountViewModel alloc] init];
    [self buildUI];
    [self bindVM];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [self.viewModel reload];
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

#pragma mark - Bind

- (void)bindVM {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onUpdated = ^{
        [weakSelf applyDisplay];
    };
    self.viewModel.onToast = ^(NSString *message) {
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
    [self.backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];

    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = @"Bank Account";
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.font = [HQITFontHelper boldFontOfSize:16];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];

    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
        make.height.greaterThanOrEqualTo(self.scrollView).priorityLow();
    }];

    self.cardView = [[HQITBankAccountCardView alloc] init];
    self.cardView.hidden = YES;
    __weak typeof(self) weakSelf = self;
    self.cardView.onEdit = ^{
        [weakSelf openModify];
    };
    [self.contentView addSubview:self.cardView];
    [self.cardView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(16);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.height.mas_equalTo(205);
    }];

    self.tipView = [self buildTipView];
    self.tipView.hidden = YES;
    [self.contentView addSubview:self.tipView];
    [self.tipView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView.mas_bottom).offset(14);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.bottom.equalTo(self.contentView).offset(-24);
    }];

    self.emptyView = [[UIView alloc] init];
    self.emptyView.hidden = YES;
    [self.contentView addSubview:self.emptyView];
    [self.emptyView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentView);
        make.centerY.equalTo(self.contentView).offset(-20);
        make.left.greaterThanOrEqualTo(self.contentView).offset(24);
        make.right.lessThanOrEqualTo(self.contentView).offset(-24);
    }];

    UIImageView *emptyImg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"no_image"]];
    emptyImg.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyView addSubview:emptyImg];
    [emptyImg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.centerX.equalTo(self.emptyView);
        make.width.mas_equalTo(160);
        make.height.mas_equalTo(138);
    }];

    UILabel *emptyLab = [[UILabel alloc] init];
    emptyLab.text = @"No bank account";
    emptyLab.textColor = [UIColor colorWithRed:0x94/255.0 green:0xA3/255.0 blue:0xB8/255.0 alpha:1];
    emptyLab.font = [HQITFontHelper regularFontOfSize:14];
    emptyLab.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:emptyLab];
    [emptyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(emptyImg.mas_bottom).offset(24);
        make.left.right.bottom.equalTo(self.emptyView);
    }];
}

- (UIView *)buildTipView {
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [UIColor colorWithRed:0xFF/255.0 green:0xF6/255.0 blue:0xE8/255.0 alpha:1];
    box.layer.cornerRadius = 10;
    box.clipsToBounds = YES;

    UIView *iconWrap = [[UIView alloc] init];
    iconWrap.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
    iconWrap.layer.cornerRadius = 7;
    [box addSubview:iconWrap];
    [iconWrap mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(15);
        make.top.equalTo(box).offset(15);
        make.width.height.mas_equalTo(14);
    }];

    UILabel *bang = [[UILabel alloc] init];
    bang.text = @"i";
    bang.textColor = [UIColor whiteColor];
    bang.font = [HQITFontHelper boldFontOfSize:10];
    bang.textAlignment = NSTextAlignmentCenter;
    [iconWrap addSubview:bang];
    [bang mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(iconWrap);
    }];

    UILabel *tip = [[UILabel alloc] init];
    tip.numberOfLines = 0;
    tip.font = [HQITFontHelper regularFontOfSize:12];
    tip.textColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    tip.text = kHQITBankTipText;
    [box addSubview:tip];
    [tip mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(iconWrap.mas_right).offset(8);
        make.right.equalTo(box).offset(-15);
        make.top.equalTo(box).offset(15);
        make.bottom.equalTo(box).offset(-15);
    }];
    return box;
}

#pragma mark - Display

- (void)applyDisplay {
    if (!self.viewModel.hasLoadedOnce) return;

    BOOL hasCard = self.viewModel.displayItem != nil;
    self.emptyView.hidden = hasCard;
    self.cardView.hidden = !hasCard;
    self.tipView.hidden = !hasCard;

    if (hasCard) {
        self.tipView.hidden = NO;
        [self.cardView applyItem:self.viewModel.displayItem showsEdit:self.viewModel.canModify];
        [self.tipView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.cardView.mas_bottom).offset(14);
            make.left.equalTo(self.contentView).offset(16);
            make.right.equalTo(self.contentView).offset(-16);
            make.bottom.equalTo(self.contentView).offset(-24);
        }];
        [self.emptyView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.contentView).offset(80);
            make.centerX.equalTo(self.contentView);
            make.left.greaterThanOrEqualTo(self.contentView).offset(16);
            make.right.lessThanOrEqualTo(self.contentView).offset(-16);
        }];
    } else {
        // Hide tip and keep it out of the vertical chain (avoid height==0 vs label insets).
        self.tipView.hidden = YES;
        [self.tipView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView).offset(16);
            make.right.equalTo(self.contentView).offset(-16);
            make.top.equalTo(self.contentView);
        }];
        [self.emptyView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.contentView).offset(80);
            make.centerX.equalTo(self.contentView);
            make.left.greaterThanOrEqualTo(self.contentView).offset(16);
            make.right.lessThanOrEqualTo(self.contentView).offset(-16);
            make.bottom.equalTo(self.contentView).offset(-24);
        }];
    }
}

#pragma mark - Actions

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)openModify {
    if (!self.viewModel.canModify || !self.viewModel.displayItem) return;
    if (![HQITClickGuard tryLockControl:self.cardView]) return;
    [HQITClickGuard unlockControl:self.cardView];
    HQITBankAccountEditViewController *vc =
        [[HQITBankAccountEditViewController alloc] initWithAccount:self.viewModel.displayItem];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
