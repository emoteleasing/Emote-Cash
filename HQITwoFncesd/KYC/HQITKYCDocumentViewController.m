

#import "HQITKYCDocumentViewController.h"
#import "HQITKYCNavigation.h"
#import "HQITKYCModels.h"
#import "HQITKYCImageHelper.h"
#import "HQITKYCDocumentCameraViewController.h"
#import "HQITNavigationBarStyle.h"
#import "HQITFontHelper.h"
#import "HQITCategoryText.h"
#import "HQITDialogs.h"
#import "HQITPermissionSecondaryPresenter.h"
#import "HQITBuryRecorder.h"
#import "HQITClickGuard.h"
#import "HQITHUDHelper.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import <Masonry/Masonry.h>
#import <AVFoundation/AVFoundation.h>
#import <PhotosUI/PhotosUI.h>

static const CGFloat kHQITDocCardRadius = 12.0;

@interface HQITKYCDocumentSlotView : UIControl
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIImageView *placeholderView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *sideLabel;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, assign) BOOL uploaded;
- (void)configureSideTitle:(NSString *)title;
- (void)setImage:(nullable UIImage *)image;
@end

@implementation HQITKYCDocumentSlotView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        _card = [[UIView alloc] init];
        _card.backgroundColor = [UIColor whiteColor];
        _card.layer.cornerRadius = kHQITDocCardRadius;
        _card.layer.shadowColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:0.08].CGColor;
        _card.layer.shadowOffset = CGSizeMake(0, 2);
        _card.layer.shadowRadius = 8;
        _card.layer.shadowOpacity = 1;
        _card.userInteractionEnabled = NO;
        [self addSubview:_card];

        _placeholderView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"your_bg"]];
        _placeholderView.contentMode = UIViewContentModeScaleAspectFit;
        _placeholderView.clipsToBounds = YES;
        _placeholderView.layer.cornerRadius = 10;
        [_card addSubview:_placeholderView];

        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.layer.cornerRadius = 10;
        _imageView.hidden = YES;
        [_card addSubview:_imageView];

        _sideLabel = [[UILabel alloc] init];
        _sideLabel.font = [HQITFontHelper regularFontOfSize:11];
        _sideLabel.textColor = [UIColor colorWithRed:0x8A/255.0 green:0x8F/255.0 blue:0x98/255.0 alpha:1];
        _sideLabel.textAlignment = NSTextAlignmentRight;
        [_card addSubview:_sideLabel];

        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *close = [UIImage systemImageNamed:@"xmark.circle.fill"];
        if (close) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
            [_deleteButton setImage:[close imageByApplyingSymbolConfiguration:cfg]
                           forState:UIControlStateNormal];
            _deleteButton.tintColor = [UIColor colorWithRed:0xC0/255.0 green:0xC4/255.0 blue:0xCA/255.0 alpha:1];
        } else {
            [_deleteButton setTitle:@"✕" forState:UIControlStateNormal];
            [_deleteButton setTitleColor:[UIColor colorWithRed:0x8A/255.0 green:0x8F/255.0 blue:0x98/255.0 alpha:1]
                               forState:UIControlStateNormal];
        }
        _deleteButton.hidden = YES;
        [self addSubview:_deleteButton];

        [_card mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        [_placeholderView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.equalTo(self.card).offset(12);
            make.right.equalTo(self.card).offset(-12);
            make.bottom.equalTo(self.card).offset(-12);
            make.height.equalTo(self.placeholderView.mas_width).multipliedBy(352.0 / 638.0);
        }];
        [_imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.placeholderView);
        }];
        [_sideLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.placeholderView).offset(-12);
            make.bottom.equalTo(self.placeholderView).offset(-10);
        }];
        [_deleteButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.card).offset(6);
            make.right.equalTo(self.card).offset(-6);
            make.width.height.mas_equalTo(28);
        }];
        [self bringSubviewToFront:_deleteButton];
    }
    return self;
}

- (void)configureSideTitle:(NSString *)title {
    self.sideLabel.text = title ?: @"";
}

- (void)setImage:(UIImage *)image {
    self.imageView.image = image;
    BOOL has = (image != nil);
    self.uploaded = has;
    self.imageView.hidden = !has;
    self.placeholderView.hidden = has;
    self.sideLabel.hidden = has;
    self.deleteButton.hidden = !has;
}

@end

@interface HQITKYCDocumentViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@property (nonatomic, copy) NSString *kycId;
@property (nonatomic, copy) NSString *pageTitleText;
@property (nonatomic, assign) HQITKYCDocumentKind kind;
@property (nonatomic, assign) BOOL isLastUnfinished;
@property (nonatomic, assign) BOOL isSubmitting;
@property (nonatomic, assign) BOOL pickingFront;

@property (nonatomic, strong) NSArray<HQITKYCFormRow *> *rows;
@property (nonatomic, strong, nullable) HQITKYCFormRow *frontRow;
@property (nonatomic, strong, nullable) HQITKYCFormRow *backRow;
@property (nonatomic, strong, nullable) HQITKYCFormRow *numberRow;

@property (nonatomic, strong, nullable) UIImage *frontImage;
@property (nonatomic, strong, nullable) UIImage *backImage;
@property (nonatomic, assign) BOOL frontUploaded;
@property (nonatomic, assign) BOOL backUploaded;
@property (nonatomic, copy, nullable) NSString *cardNumber;

@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) HQITKYCDocumentSlotView *frontSlot;
@property (nonatomic, strong, nullable) HQITKYCDocumentSlotView *backSlot;
@property (nonatomic, strong) UIView *numberCard;
@property (nonatomic, strong) UITextField *numberField;
@property (nonatomic, strong) UIButton *continueButton;
@property (nonatomic, strong) CAGradientLayer *continueGradient;
@end

@implementation HQITKYCDocumentViewController

- (instancetype)initWithKycId:(NSString *)kycId
                    pageTitle:(NSString *)pageTitle
                         kind:(HQITKYCDocumentKind)kind
             isLastUnfinished:(BOOL)isLastUnfinished {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _kycId = [kycId copy] ?: @"";
        _pageTitleText = [pageTitle copy] ?: @"Verification";
        _kind = kind;
        _isLastUnfinished = isLastUnfinished;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xEE/255.0 green:0xF0/255.0 blue:0xF5/255.0 alpha:1];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    [self buildUI];
    [self loadInit];
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
    if (self.continueGradient) {
        self.continueGradient.frame = self.continueButton.bounds;
        self.continueGradient.cornerRadius = 10;
    }
}

- (void)hqit_setupBackButtonIfNeeded {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:[[UIView alloc] init]];
    self.navigationItem.hidesBackButton = YES;
}
- (BOOL)hqit_shouldPopBack { return NO; }

#pragma mark - Load

- (void)loadInit {
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/kyc/init"
                                         signedData:@{@"kycId": self.kycId ?: @""}
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        [weakSelf parseInit:response.data];
    } failure:^(NSError *error, NSString *message) {
        [HQITHUDHelper showToast:message.length ? message : @"Load failed"];
    }];
}

- (void)parseInit:(id)raw {
    NSArray *list = nil;
    if ([raw isKindOfClass:[NSDictionary class]]) {
        id v = raw[@"kycItemList"] ?: raw[@"kycItemList"] ?: raw[@"itemList"] ?: raw[@"exact"];
        if ([v isKindOfClass:[NSArray class]]) list = v;
    }
    NSMutableArray *rows = [NSMutableArray array];
    NSMutableArray *imgRows = [NSMutableArray array];
    HQITKYCFormRow *number = nil;
    for (id obj in list ?: @[]) {
        if (![obj isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = obj;
        HQITKYCFormRow *row = [[HQITKYCFormRow alloc] init];
        id codeVal = d[@"itemCode"] ?: d[@"itemCode"] ?: d[@"itemCode"] ?: d[@"item_code"];
        row.itemCode = codeVal ? [[NSString stringWithFormat:@"%@", codeVal] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
        if ([row.itemCode isEqualToString:@"(null)"]) row.itemCode = @"";
        row.itemName = [NSString stringWithFormat:@"%@", d[@"itemName"] ?: d[@"itemName"] ?: d[@"item_name"] ?: @""];
        if ([row.itemName isEqualToString:@"(null)"]) row.itemName = @"";
        row.itemType = [d[@"itemType"] ?: d[@"itemType"] ?: d[@"item_type"] ?: @1 integerValue];
        row.itemSort = [d[@"itemSort"] ?: d[@"itemSort"] ?: d[@"item_sort"] ?: @0 integerValue];
        row.isRequired = [[d[@"isRequired"] ?: d[@"isRequired"] ?: d[@"is_required"] ?: @0 description] integerValue] == 1;
        if (row.itemCode.length == 0) continue;
        [rows addObject:row];
        NSString *code = row.itemCode.lowercaseString;
        BOOL isImg = [code containsString:@"img"] || [code containsString:@"Greek"] || [code containsString:@"picture"] || [code containsString:@"Greek"];
        if (isImg) {
            [imgRows addObject:row];
        } else if (row.itemType == HQITKYCItemTypeInput && !number) {
            number = row;
        }
    }
    [imgRows sortUsingComparator:^NSComparisonResult(HQITKYCFormRow *a, HQITKYCFormRow *b) {
        return a.itemSort < b.itemSort ? NSOrderedAscending : NSOrderedDescending;
    }];
    self.rows = rows;
    self.numberRow = number;
    self.frontRow = nil;
    self.backRow = nil;
    for (HQITKYCFormRow *r in imgRows) {
        NSString *c = r.itemCode.lowercaseString;
        if ([c containsString:@"front"] && !self.frontRow) self.frontRow = r;
        else if ([c containsString:@"back"] && !self.backRow) self.backRow = r;
    }
    if (!self.frontRow && imgRows.count > 0) self.frontRow = imgRows[0];
    if (self.kind == HQITKYCDocumentKindAadhaar && !self.backRow && imgRows.count > 1) self.backRow = imgRows[1];
    if (self.kind == HQITKYCDocumentKindPAN) self.backRow = nil;
    [self refreshNumberEnabled];
}

#pragma mark - UI

- (UIColor *)hqit_navy {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)hqit_grey {
    return [UIColor colorWithRed:0x8A/255.0 green:0x8F/255.0 blue:0x98/255.0 alpha:1];
}

- (UIColor *)hqit_tipText {
    return [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
}

- (UIView *)hqit_tipIconView {
    UIImage *asset = [UIImage imageNamed:@"with_icon"];
    if (asset) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[asset imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        [iv mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.height.mas_equalTo(18);
        }];
        return iv;
    }
    UIView *wrap = [[UIView alloc] init];
    wrap.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
    wrap.layer.cornerRadius = 9;
    wrap.clipsToBounds = YES;
    UILabel *mark = [[UILabel alloc] init];
    mark.text = @"!";
    mark.textColor = [UIColor whiteColor];
    mark.font = [HQITFontHelper boldFontOfSize:12];
    mark.textAlignment = NSTextAlignmentCenter;
    [wrap addSubview:mark];
    [wrap mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(18);
    }];
    [mark mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(wrap);
    }];
    return wrap;
}

- (void)buildUI {
    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = [HQITNavigationBarStyle loanBackgroundHeightForWidth:w];
    self.headerBg = [[UIImageView alloc] init];
    self.headerBg.image = [HQITNavigationBarStyle loanBackgroundImageFittingSize:CGSizeMake(w, h)];
    self.headerBg.contentMode = UIViewContentModeScaleToFill;
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
    [self.backButton addTarget:self action:@selector(onNavBack) forControlEvents:UIControlEventTouchUpInside];
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];
    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = self.pageTitleText;
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.continueButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.continueButton.clipsToBounds = YES;
    self.continueButton.layer.cornerRadius = 10;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat iw = MAX(bg.size.width, 1), ih = MAX(bg.size.height, 1);
        [self.continueButton setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(ih * 0.45, iw * 0.45, ih * 0.45, iw * 0.45)
                                                                   resizingMode:UIImageResizingModeStretch]
                                       forState:UIControlStateNormal];
    } else {
        self.continueGradient = [CAGradientLayer layer];
        self.continueGradient.colors = @[
            (id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
            (id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
        ];
        self.continueGradient.startPoint = CGPointMake(0.5, 0);
        self.continueGradient.endPoint = CGPointMake(0.5, 1);
        [self.continueButton.layer insertSublayer:self.continueGradient atIndex:0];
    }
    NSString *btnTitle = self.isLastUnfinished ? @"Apply Now" : @"Continue";
    [self.continueButton setTitle:btnTitle forState:UIControlStateNormal];
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
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.continueButton.mas_top).offset(-12);
    }];

    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];

    UILabel *heading = [[UILabel alloc] init];
    heading.numberOfLines = 0;
    heading.font = [HQITFontHelper boldFontOfSize:16];
    heading.textColor = [self hqit_navy];
    heading.text = self.kind == HQITKYCDocumentKindPAN
        ? [HQITCategoryText textForKey:@"m50" defaultText:@"Please upload your PAN"]
        : [HQITCategoryText textForKey:@"m31" defaultText:@"Please upload your Aadhaar"];
    [self.contentView addSubview:heading];
    [heading mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(4);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
    }];

    UIView *belowHeading = heading;
    if (self.kind == HQITKYCDocumentKindPAN) {
        UILabel *subHI = [[UILabel alloc] init];
        subHI.numberOfLines = 0;
        subHI.font = [HQITFontHelper regularFontOfSize:12];
        subHI.textColor = [self hqit_tipText];
        subHI.text = [HQITCategoryText textForKey:@"m49"
                                      defaultText:@"कृपया अपने पैन कार्ड के सामने वाले हिस्से को अपलोड करें"];
        [self.contentView addSubview:subHI];
        [subHI mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(heading.mas_bottom).offset(6);
            make.left.right.equalTo(heading);
        }];
        belowHeading = subHI;
    }

    self.frontSlot = [[HQITKYCDocumentSlotView alloc] init];
    NSString *frontTitle = self.kind == HQITKYCDocumentKindPAN
        ? [HQITCategoryText textForKey:@"m47" defaultText:@"Front of PAN - सामना"]
        : @"Front";
    [self.frontSlot configureSideTitle:frontTitle];
    [self.frontSlot addTarget:self action:@selector(onFrontTap) forControlEvents:UIControlEventTouchUpInside];
    [self.frontSlot.deleteButton addTarget:self action:@selector(onFrontDelete) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.frontSlot];
    [self.frontSlot mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(belowHeading.mas_bottom).offset(12);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
    }];

    UIView *belowSlots = self.frontSlot;
    if (self.kind == HQITKYCDocumentKindAadhaar) {
        self.backSlot = [[HQITKYCDocumentSlotView alloc] init];
        [self.backSlot configureSideTitle:@"Back"];
        [self.backSlot addTarget:self action:@selector(onBackTap) forControlEvents:UIControlEventTouchUpInside];
        [self.backSlot.deleteButton addTarget:self action:@selector(onBackDelete) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.backSlot];
        [self.backSlot mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.frontSlot.mas_bottom).offset(12);
            make.left.right.equalTo(self.frontSlot);
        }];
        belowSlots = self.backSlot;
    }

    self.numberCard = [[UIView alloc] init];
    self.numberCard.backgroundColor = [UIColor whiteColor];
    self.numberCard.layer.cornerRadius = 12;
    self.numberCard.layer.shadowColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:0.08].CGColor;
    self.numberCard.layer.shadowOffset = CGSizeMake(0, 2);
    self.numberCard.layer.shadowRadius = 8;
    self.numberCard.layer.shadowOpacity = 1;
    [self.contentView addSubview:self.numberCard];
    [self.numberCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(belowSlots.mas_bottom).offset(12);
        make.left.right.equalTo(self.frontSlot);
    }];

    UILabel *numTitle = [[UILabel alloc] init];
    numTitle.font = [HQITFontHelper boldFontOfSize:14];
    numTitle.textColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    numTitle.text = self.kind == HQITKYCDocumentKindPAN
        ? [HQITCategoryText textForKey:@"m48" defaultText:@"PAN Number"]
        : [HQITCategoryText textForKey:@"m35" defaultText:@"Aadhaar Number"];
    [self.numberCard addSubview:numTitle];
    [numTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.numberCard).offset(16);
        make.left.equalTo(self.numberCard).offset(16);
        make.right.equalTo(self.numberCard).offset(-16);
    }];

    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    box.layer.cornerRadius = 10;
    [self.numberCard addSubview:box];
    [box mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(numTitle.mas_bottom).offset(10);
        make.left.right.equalTo(numTitle);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.numberCard).offset(-16);
    }];

    UIColor *contentColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
    self.numberField = [[UITextField alloc] init];
    self.numberField.font = [HQITFontHelper regularFontOfSize:13];
    self.numberField.textColor = contentColor;
    self.numberField.placeholder = [HQITCategoryText textForKey:@"m34" defaultText:@"Please enter"];
    self.numberField.keyboardType = self.kind == HQITKYCDocumentKindPAN
        ? UIKeyboardTypeASCIICapable
        : UIKeyboardTypeNumberPad;
    self.numberField.autocapitalizationType = self.kind == HQITKYCDocumentKindPAN
        ? UITextAutocapitalizationTypeAllCharacters
        : UITextAutocapitalizationTypeNone;
    if (self.kind == HQITKYCDocumentKindPAN) {
        self.numberField.enabled = NO;
        self.numberField.userInteractionEnabled = NO;
    }
    [box addSubview:self.numberField];
    [self.numberField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(box).offset(14);
        make.right.equalTo(box).offset(-14);
        make.top.bottom.equalTo(box);
    }];

    UIView *tipCard = [self buildTipCard];
    [self.contentView addSubview:tipCard];
    [tipCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.numberCard.mas_bottom).offset(12);
        make.left.right.equalTo(self.frontSlot);
        make.bottom.equalTo(self.contentView).offset(-16);
    }];

    [self refreshNumberEnabled];
}

- (UIView *)buildTipCard {
    if (self.kind == HQITKYCDocumentKindPAN) {
        return [self buildPANTipCard];
    }
    return [self buildAadhaarTipCard];
}

- (UIView *)buildPANTipCard {
    UIView *tipCard = [[UIView alloc] init];
    tipCard.backgroundColor = [UIColor colorWithRed:0xFF/255.0 green:0xF6/255.0 blue:0xEC/255.0 alpha:1];
    tipCard.layer.cornerRadius = 12;
    tipCard.layer.borderWidth = 1;
    tipCard.layer.borderColor = [UIColor colorWithRed:0xF5/255.0 green:0xC9/255.0 blue:0x9A/255.0 alpha:1].CGColor;

    UIView *icon = [self hqit_tipIconView];
    [tipCard addSubview:icon];
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(tipCard).offset(14);
        make.left.equalTo(tipCard).offset(12);
    }];

    UIColor *tipColor = [self hqit_tipText];
    UIFont *tipFont = [HQITFontHelper regularFontOfSize:12];

    UILabel *enLab = [[UILabel alloc] init];
    enLab.numberOfLines = 0;
    enLab.font = tipFont;
    enLab.textColor = tipColor;
    enLab.text = [HQITCategoryText textForKey:@"m53"
                                  defaultText:@"If the information is wrong, please re-take and upload the front of the PAN"];
    [tipCard addSubview:enLab];
    [enLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(tipCard).offset(12);
        make.left.equalTo(icon.mas_right).offset(8);
        make.right.equalTo(tipCard).offset(-12);
    }];

    UILabel *hiLab = [[UILabel alloc] init];
    hiLab.numberOfLines = 0;
    hiLab.font = tipFont;
    hiLab.textColor = tipColor;
    hiLab.text = [HQITCategoryText textForKey:@"m46"
                                  defaultText:@"अगर जानकारी गलत है तो कृपया पैन की तस्वीर दोबारा लें और अपलोड करें"];
    [tipCard addSubview:hiLab];
    [hiLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(enLab.mas_bottom).offset(6);
        make.left.right.equalTo(enLab);
        make.bottom.equalTo(tipCard).offset(-12);
    }];
    return tipCard;
}

- (UIView *)buildAadhaarTipCard {
    UIView *tipCard = [[UIView alloc] init];
    tipCard.backgroundColor = [UIColor colorWithRed:0xFF/255.0 green:0xF6/255.0 blue:0xEC/255.0 alpha:1];
    tipCard.layer.cornerRadius = 12;
    tipCard.layer.borderWidth = 1;
    tipCard.layer.borderColor = [UIColor colorWithRed:0xF5/255.0 green:0xC9/255.0 blue:0x9A/255.0 alpha:1].CGColor;

    UIView *icon = [self hqit_tipIconView];
    [tipCard addSubview:icon];
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(tipCard).offset(14);
        make.left.equalTo(tipCard).offset(12);
    }];

    NSString *intro = [HQITCategoryText textForKey:@"m38"
                                       defaultText:@"If the information is wrong, please take a photo again and upload the front of the Aadhaar card."];
    NSString *aText = [HQITCategoryText textForKey:@"m39"
                                       defaultText:@"Please make sure that the Aadhaar card you upload is genuine and valid."];
    NSString *bText = [HQITCategoryText textForKey:@"m40"
                                       defaultText:@"Please make sure that the uploaded Aadhaar card photo is clear and complete, otherwise it will not pass verification."];

    UIColor *tipColor = [self hqit_tipText];
    UIFont *tipFont = [HQITFontHelper regularFontOfSize:12];

    UILabel *introLab = [[UILabel alloc] init];
    introLab.numberOfLines = 0;
    introLab.font = tipFont;
    introLab.textColor = tipColor;
    introLab.text = intro;
    [tipCard addSubview:introLab];
    [introLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(tipCard).offset(12);
        make.left.equalTo(icon.mas_right).offset(8);
        make.right.equalTo(tipCard).offset(-12);
    }];

    UIView *aRow = [self hqit_tipBulletRowPrefix:@"a." body:aText tipColor:tipColor tipFont:tipFont];
    [tipCard addSubview:aRow];
    [aRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(introLab.mas_bottom).offset(8);
        make.left.equalTo(icon);
        make.right.equalTo(tipCard).offset(-12);
    }];

    UIView *bRow = [self hqit_tipBulletRowPrefix:@"b." body:bText tipColor:tipColor tipFont:tipFont];
    [tipCard addSubview:bRow];
    [bRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(aRow.mas_bottom).offset(6);
        make.left.right.equalTo(aRow);
        make.bottom.equalTo(tipCard).offset(-12);
    }];
    return tipCard;
}

- (UIView *)hqit_tipBulletRowPrefix:(NSString *)prefix
                               body:(NSString *)body
                           tipColor:(UIColor *)tipColor
                            tipFont:(UIFont *)tipFont {
    UIView *row = [[UIView alloc] init];
    UILabel *prefixLab = [[UILabel alloc] init];
    prefixLab.font = [HQITFontHelper boldFontOfSize:12];
    prefixLab.textColor = [UIColor colorWithRed:0xF6/255.0 green:0x71/255.0 blue:0x15/255.0 alpha:1];
    prefixLab.text = prefix ?: @"";
    prefixLab.textAlignment = NSTextAlignmentLeft;
    [row addSubview:prefixLab];

    UILabel *bodyLab = [[UILabel alloc] init];
    bodyLab.numberOfLines = 0;
    bodyLab.font = tipFont;
    bodyLab.textColor = tipColor;
    bodyLab.text = body ?: @"";
    [row addSubview:bodyLab];

    [prefixLab setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [prefixLab setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [prefixLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(row);
        make.width.mas_equalTo(18);
    }];
    [bodyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(prefixLab.mas_right).offset(2);
        make.top.right.bottom.equalTo(row);
    }];
    return row;
}

- (void)refreshNumberEnabled {
    if (self.kind == HQITKYCDocumentKindPAN) {
        BOOL hasFront = self.frontUploaded;
        self.numberField.enabled = NO;
        self.numberField.userInteractionEnabled = NO;
        self.numberField.alpha = hasFront ? 1.0 : 0.45;
        if (!hasFront) {
            self.numberField.text = @"";
            self.cardNumber = nil;
            return;
        }
        if (self.cardNumber.length) {
            self.numberField.text = self.cardNumber;
        }
        return;
    }
    self.numberField.enabled = YES;
    self.numberField.userInteractionEnabled = YES;
    self.numberField.alpha = 1.0;
    if (self.cardNumber.length && self.numberField.text.length == 0) {
        self.numberField.text = self.cardNumber;
    }
}

#pragma mark - Pick

- (void)onFrontTap {
    self.pickingFront = YES;
    if (self.kind == HQITKYCDocumentKindPAN) {
        [HQITBuryRecorder recordEventCode:41 eventContent:nil remark1:nil remark2:nil remark3:nil];
    } else {
        [HQITBuryRecorder recordEventCode:50 eventContent:nil remark1:nil remark2:nil remark3:nil];
    }
    [self presentPicker];
}
- (void)onBackTap { self.pickingFront = NO; [self presentPicker]; }
- (void)onFrontDelete {
    self.frontImage = nil;
    self.frontUploaded = NO;
    [self.frontSlot setImage:nil];
    if (self.kind == HQITKYCDocumentKindPAN) {
        self.cardNumber = nil;
    }
    [self refreshNumberEnabled];
}
- (void)onBackDelete {
    self.backImage = nil; self.backUploaded = NO;
    [self.backSlot setImage:nil];
}

- (void)presentPicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:[HQITCategoryText textForKey:@"m42" defaultText:@"Camera"]
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) { [self openDocumentCamera]; }]];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:[HQITCategoryText textForKey:@"m43" defaultText:@"Album"]
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.kind == HQITKYCDocumentKindPAN) {
            [HQITBuryRecorder recordEventCode:48 eventContent:nil remark1:nil remark2:nil remark3:nil];
        } else if (self.kind == HQITKYCDocumentKindAadhaar && self.pickingFront) {
            [HQITBuryRecorder recordEventCode:57 eventContent:nil remark1:nil remark2:nil remark3:nil];
        }
        [self openPicker:UIImagePickerControllerSourceTypePhotoLibrary];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openDocumentCamera {
    AVAuthorizationStatus st = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (st == AVAuthorizationStatusDenied || st == AVAuthorizationStatusRestricted) {
        [HQITBuryRecorder recordCameraPermissionGranted:NO]; // 12
        [HQITPermissionSecondaryPresenter showCameraSettingsGuideInView:self.view.window ?: self.view
                                                              onConfirm:nil
                                                               onCancel:nil];
        return;
    }
    if (self.kind == HQITKYCDocumentKindPAN) {
        [HQITBuryRecorder recordEventCode:43 eventContent:nil remark1:nil remark2:nil remark3:nil];
    } else if (self.pickingFront) {
        [HQITBuryRecorder recordEventCode:53 eventContent:nil remark1:nil remark2:nil remark3:nil];
    }
    __weak typeof(self) weakSelf = self;
    BOOL isFront = self.pickingFront;
    HQITKYCDocumentCameraViewController *cam = [[HQITKYCDocumentCameraViewController alloc] initWithCompletion:^(UIImage *image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !image) return;
        [self uploadImage:image isFront:isFront];
    }];
    [self presentViewController:cam animated:YES completion:nil];
}

- (void)openPicker:(UIImagePickerControllerSourceType)type {
    if (![UIImagePickerController isSourceTypeAvailable:type]) {
        [HQITHUDHelper showToast:@"Unavailable"];
        return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = type;
    picker.delegate = self;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (img) [self uploadImage:img isFront:self.pickingFront];
    }];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)hqit_cardNoFromCommitData:(id)data {
    if (![data isKindOfClass:[NSDictionary class]]) return @"";
    NSDictionary *d = (NSDictionary *)data;
    NSArray<NSString *> *keys = @[ @"cardNo", @"panNo", @"panNumber", @"aadhaarNo", @"idNumber", @"idNo" ];
    NSString *(^pick)(NSDictionary *) = ^NSString *(NSDictionary *dict) {
        if (![dict isKindOfClass:[NSDictionary class]]) return @"";
        for (NSString *k in keys) {
            id v = dict[k];
            if ([v isKindOfClass:[NSString class]]) {
                NSString *s = [(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (s.length && ![s isEqualToString:@"(null)"]) return s;
            } else if ([v isKindOfClass:[NSNumber class]]) {
                return [NSString stringWithFormat:@"%@", v];
            }
        }
        return @"";
    };
    NSString *found = pick(d);
    if (found.length) return found;
    id echo = d[@"echoMap"];
    if ([echo isKindOfClass:[NSDictionary class]]) {
        found = pick((NSDictionary *)echo);
        if (found.length) return found;
        if (self.kind == HQITKYCDocumentKindPAN) {
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^[A-Z]{5}[0-9]{4}[A-Z]$"
                                                                               options:0
                                                                                 error:nil];
            for (id v in [(NSDictionary *)echo allValues]) {
                if (![v isKindOfClass:[NSString class]]) continue;
                NSString *s = [[(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
                if (s.length == 10 && [re numberOfMatchesInString:s options:0 range:NSMakeRange(0, s.length)] == 1) {
                    return s;
                }
            }
        }
    }
    return @"";
}

- (void)uploadImage:(UIImage *)image isFront:(BOOL)isFront {
    HQITKYCFormRow *row = isFront ? self.frontRow : self.backRow;
    if (!row.itemCode.length) {
        [HQITHUDHelper showToast:@"Missing image field"];
        return;
    }
    UIImage *oriented = [HQITKYCImageHelper documentOrientedImageFromImage:image] ?: image;
    NSString *b64 = [HQITKYCImageHelper jpegBase64Under600KBFromImage:oriented];
    if (!b64.length) {
        [HQITHUDHelper showToast:@"Image process failed"];
        return;
    }
    if (isFront) { self.frontImage = oriented; [self.frontSlot setImage:oriented]; }
    else { self.backImage = oriented; [self.backSlot setImage:oriented]; }

    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/kyc/item/commit"
                                         signedData:@{
        @"kycId": self.kycId ?: @"",
        @"itemCode": row.itemCode ?: @"",
        @"itemValueType": @"2",
        @"itemValue": b64,
    }
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (isFront) {
            NSString *cardNo = [self hqit_cardNoFromCommitData:response.data];
            if (self.kind == HQITKYCDocumentKindPAN && cardNo.length == 0) {
                [HQITDialogs showDocumentVerifyFailInView:self.view.window ?: self.view onConfirm:^{
                    [self onFrontDelete];
                }];
                return;
            }
            self.frontUploaded = YES;
            if (cardNo.length) {
                self.cardNumber = cardNo;
                self.numberField.text = cardNo;
            }
            [self refreshNumberEnabled];
        } else {
            self.backUploaded = YES;
        }
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSInteger code = error.code;
        BOOL authFail = (code == 6212011 || code == 6212201);
        if (authFail) {
            [HQITDialogs showDocumentVerifyFailInView:self.view.window ?: self.view onConfirm:^{
                if (isFront) [self onFrontDelete];
                else [self onBackDelete];
            }];
        } else {
            if (isFront) [self onFrontDelete];
            else [self onBackDelete];
        }
    }];
}

#pragma mark - Submit / Back

- (void)onNavBack {
    NSString *body = [HQITCategoryText textForKey:@"a40"
                                     defaultText:@"Do you want to pause the authentication and return to the homepage?"];
    [HQITDialogs showWhiteConfirmTitle:@"Confirm to return?" body:body icon:nil confirmTitle:@"Confirm" cancelTitle:@"Cancel" inView:self.view.window ?: self.view onConfirm:^{
        [HQITKYCNavigation confirmExitFrom:self];
    } onCancel:nil];
}

- (void)onContinue {
    if (self.isSubmitting) return;
    if (![HQITClickGuard tryLockControl:self.continueButton]) return;
    if (self.kind == HQITKYCDocumentKindPAN) {
        [HQITBuryRecorder recordEventCode:40 eventContent:nil remark1:nil remark2:nil remark3:nil];
    } else {
        [HQITBuryRecorder recordEventCode:66 eventContent:nil remark1:nil remark2:nil remark3:nil];
    }
    if (!self.frontUploaded) {
        [HQITHUDHelper showToast:@"Please upload front image"];
        [HQITClickGuard unlockControl:self.continueButton];
        return;
    }
    if (self.kind == HQITKYCDocumentKindAadhaar && self.backRow && !self.backUploaded) {
        [HQITHUDHelper showToast:@"Please upload back image"];
        [HQITClickGuard unlockControl:self.continueButton];
        return;
    }
    NSString *number = [self.numberField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (number.length == 0 && self.cardNumber.length) number = self.cardNumber;
    if (self.numberRow && number.length == 0) {
        [HQITHUDHelper showToast:@"Please enter number"];
        [HQITClickGuard unlockControl:self.continueButton];
        return;
    }
    if (!self.numberRow) {
        [HQITKYCNavigation advanceFrom:self];
        return;
    }
    self.isSubmitting = YES;
    self.continueButton.enabled = NO;
    self.continueButton.alpha = 0.5;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/kyc/item/commit"
                                         signedData:@{
        @"kycId": self.kycId ?: @"",
        @"itemCode": self.numberRow.itemCode ?: @"",
        @"itemValueType": @"1",
        @"itemValue": number ?: @"",
    }
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        self.continueButton.enabled = YES;
        self.continueButton.alpha = 1;
        [HQITKYCNavigation advanceFrom:self];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        self.continueButton.enabled = YES;
        self.continueButton.alpha = 1;
        [HQITClickGuard unlockControl:self.continueButton];
    }];
}

@end
