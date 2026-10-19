

#import "HQITFeedbackViewController.h"
#import "HQITFontHelper.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITHUDHelper.h"
#import "HQITClickGuard.h"
#import "HQITNavigationBarStyle.h"
#import "HQITIndianPhoneValidator.h"
#import "HQITKYCImageHelper.h"
#import "HQITRatingGuidePresenter.h"
#import "HQITAppShell.h"
#import "HQITAppConfigHelper.h"
#import <Masonry/Masonry.h>
#import <PhotosUI/PhotosUI.h>

static const NSInteger kHQITFeedbackMaxImages = 3;
static const NSInteger kHQITFeedbackMaxDesc = 1000;
static NSString * const kHQITFeedbackTip =
@"You can describe the problem you encounter in detail on this page, or send your problem to our email, leave your contact information, and we will contact you as soon as possible!";

@interface HQITFeedbackImageItem : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *remoteURL;
@end
@implementation HQITFeedbackImageItem
@end

@interface HQITFeedbackViewController () <UITextFieldDelegate, UITextViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PHPickerViewControllerDelegate>
@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UITextView *questionView;
@property (nonatomic, strong) UILabel *questionPlaceholder;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UICollectionView *imageCollection;
@property (nonatomic, strong) UIButton *submitButton;

@property (nonatomic, strong) NSMutableArray<HQITFeedbackImageItem *> *imageItems;
@property (nonatomic, assign) BOOL isSubmitting;
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign, readwrite) HQITFeedbackExitStyle exitStyle;
@property (nonatomic, assign) BOOL didPresentRatingGuideOnEnter;
@end

@implementation HQITFeedbackViewController

- (instancetype)init {
    return [self initWithExitStyle:HQITFeedbackExitPopOne];
}

- (instancetype)initWithExitStyle:(HQITFeedbackExitStyle)exitStyle {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _exitStyle = exitStyle;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    self.imageItems = [NSMutableArray array];
    [self buildUI];
    [self updateCounter];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.backButton.enabled = YES;
    [self.view bringSubviewToFront:self.navContent];
    [HQITClickGuard unlockControl:self.submitButton];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.presentRatingGuideOnEnter || self.didPresentRatingGuideOnEnter) return;
    self.didPresentRatingGuideOnEnter = YES;
    UIView *host = [HQITAppShell shared].window ?: self.view.window ?: self.view;
    NSInteger guidance = [HQITAppConfigHelper feedbackGuidanceMode];
    NSLog(@"[HQITFeedback] enter from success → rating guide feedbackGuidance=%ld", (long)guidance);
    [HQITRatingGuidePresenter presentIfNeededForced:NO
                                           userType:0
                                             inView:host
                                         completion:^{}];
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

- (UIColor *)navyColor {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)placeholderColor {
    return [UIColor colorWithRed:0xC0/255.0 green:0xC4/255.0 blue:0xCC/255.0 alpha:1];
}

- (UIColor *)fieldFillColor {
    return [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
}

- (UIColor *)borderColor {
    return [UIColor colorWithRed:0xE5/255.0 green:0xE7/255.0 blue:0xEB/255.0 alpha:1];
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
    self.backButton.exclusiveTouch = YES;
    [self.navContent addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.navContent).offset(16);
        make.bottom.equalTo(self.headerBg.mas_bottom).offset(-8);
        make.width.height.mas_equalTo(36);
    }];

    self.navTitleLabel = [[UILabel alloc] init];
    self.navTitleLabel.text = @"Feedback";
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textAlignment = NSTextAlignmentLeft;
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.submitButton.clipsToBounds = YES;
    self.submitButton.layer.cornerRadius = 10;
    UIImage *btnBg = [UIImage imageNamed:@"button_bg"];
    if (btnBg) {
        CGFloat bw = MAX(btnBg.size.width, 1), bh = MAX(btnBg.size.height, 1);
        [self.submitButton setBackgroundImage:[btnBg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                     resizingMode:UIImageResizingModeStretch]
                                     forState:UIControlStateNormal];
    } else {
        self.submitButton.backgroundColor = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    }
    [self.submitButton setTitle:@"Submit" forState:UIControlStateNormal];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.submitButton addTarget:self action:@selector(onSubmit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.submitButton];
    [self.submitButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16);
    }];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.submitButton.mas_top).offset(-12);
    }];

    self.contentView = [[UIView alloc] init];
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];

    UIView *phoneCard = [self whiteCard];
    [self.contentView addSubview:phoneCard];
    [phoneCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(12);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
    }];
    UILabel *phoneTitle = [self sectionTitle:@"Your phone number"];
    [phoneCard addSubview:phoneTitle];
    [phoneTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.equalTo(phoneCard).offset(16);
        make.right.equalTo(phoneCard).offset(-16);
    }];
    self.phoneField = [[UITextField alloc] init];
    self.phoneField.delegate = self;
    self.phoneField.keyboardType = UIKeyboardTypeNumberPad;
    self.phoneField.font = [HQITFontHelper regularFontOfSize:14];
    self.phoneField.textColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
    self.phoneField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Please enter"
                                                                            attributes:@{NSForegroundColorAttributeName: [self placeholderColor]}];
    self.phoneField.backgroundColor = [UIColor whiteColor];
    self.phoneField.layer.cornerRadius = 10;
    self.phoneField.layer.borderWidth = 1;
    self.phoneField.layer.borderColor = [self borderColor].CGColor;
    self.phoneField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    self.phoneField.leftViewMode = UITextFieldViewModeAlways;
    self.phoneField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    self.phoneField.rightViewMode = UITextFieldViewModeAlways;
    [self.phoneField addTarget:self action:@selector(onPhoneChanged:) forControlEvents:UIControlEventEditingChanged];
    [phoneCard addSubview:self.phoneField];
    [self.phoneField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(phoneTitle.mas_bottom).offset(12);
        make.left.equalTo(phoneCard).offset(16);
        make.right.equalTo(phoneCard).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(phoneCard).offset(-16);
    }];

    UIView *questionCard = [self whiteCard];
    [self.contentView addSubview:questionCard];
    [questionCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(phoneCard.mas_bottom).offset(12);
        make.left.right.equalTo(phoneCard);
    }];
    UILabel *qTitle = [self sectionTitle:@"Your question"];
    [questionCard addSubview:qTitle];
    [qTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.equalTo(questionCard).offset(16);
        make.right.equalTo(questionCard).offset(-16);
    }];
    self.questionView = [[UITextView alloc] init];
    self.questionView.delegate = self;
    self.questionView.font = [HQITFontHelper regularFontOfSize:14];
    self.questionView.textColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
    self.questionView.backgroundColor = [self fieldFillColor];
    self.questionView.layer.cornerRadius = 10;
    self.questionView.textContainerInset = UIEdgeInsetsMake(12, 10, 28, 10);
    [questionCard addSubview:self.questionView];
    [self.questionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(qTitle.mas_bottom).offset(12);
        make.left.equalTo(questionCard).offset(16);
        make.right.equalTo(questionCard).offset(-16);
        make.height.mas_equalTo(140);
        make.bottom.equalTo(questionCard).offset(-16);
    }];
    self.questionPlaceholder = [[UILabel alloc] init];
    self.questionPlaceholder.text = @"Please enter";
    self.questionPlaceholder.font = [HQITFontHelper regularFontOfSize:14];
    self.questionPlaceholder.textColor = [self placeholderColor];
    [questionCard addSubview:self.questionPlaceholder];
    [self.questionPlaceholder mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.questionView).offset(12);
        make.left.equalTo(self.questionView).offset(15);
    }];
    self.counterLabel = [[UILabel alloc] init];
    self.counterLabel.font = [HQITFontHelper regularFontOfSize:12];
    self.counterLabel.textColor = [self placeholderColor];
    self.counterLabel.textAlignment = NSTextAlignmentRight;
    [questionCard addSubview:self.counterLabel];
    [self.counterLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.questionView).offset(-12);
        make.bottom.equalTo(self.questionView).offset(-8);
    }];

    UIView *uploadCard = [self whiteCard];
    [self.contentView addSubview:uploadCard];
    [uploadCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(questionCard.mas_bottom).offset(12);
        make.left.right.equalTo(phoneCard);
    }];
    UILabel *upTitle = [self sectionTitle:@"Upload Pictures"];
    [uploadCard addSubview:upTitle];
    [upTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.equalTo(uploadCard).offset(16);
        make.right.equalTo(uploadCard).offset(-16);
    }];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 10;
    self.imageCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.imageCollection.backgroundColor = [UIColor clearColor];
    self.imageCollection.showsHorizontalScrollIndicator = NO;
    self.imageCollection.dataSource = self;
    self.imageCollection.delegate = self;
    [self.imageCollection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"add"];
    [self.imageCollection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"img"];
    [uploadCard addSubview:self.imageCollection];
    [self.imageCollection mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(upTitle.mas_bottom).offset(12);
        make.left.equalTo(uploadCard).offset(16);
        make.right.equalTo(uploadCard).offset(-16);
        make.height.mas_equalTo(72);
        make.bottom.equalTo(uploadCard).offset(-16);
    }];

    UIView *tip = [self buildTipView];
    [self.contentView addSubview:tip];
    [tip mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(uploadCard.mas_bottom).offset(12);
        make.left.right.equalTo(phoneCard);
        make.bottom.equalTo(self.contentView).offset(-20);
    }];
}

- (UIView *)whiteCard {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;
    return card;
}

- (UILabel *)sectionTitle:(NSString *)text {
    UILabel *lab = [[UILabel alloc] init];
    lab.text = text;
    lab.font = [HQITFontHelper boldFontOfSize:15];
    lab.textColor = [self navyColor];
    return lab;
}

- (UIView *)buildTipView {
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [UIColor colorWithRed:0xFF/255.0 green:0xF6/255.0 blue:0xE8/255.0 alpha:1];
    box.layer.cornerRadius = 10;
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
    tip.textColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    tip.text = kHQITFeedbackTip;
    [box addSubview:tip];
    [tip mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(iconView.mas_right).offset(8);
        make.right.equalTo(box).offset(-15);
        make.top.equalTo(box).offset(15);
        make.bottom.equalTo(box).offset(-15);
    }];
    return box;
}

#pragma mark - Counter / Phone

- (void)updateCounter {
    NSInteger count = self.questionView.text.length;
    self.counterLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)count, (long)kHQITFeedbackMaxDesc];
    self.questionPlaceholder.hidden = count > 0;
}

- (void)onPhoneChanged:(UITextField *)tf {
    NSString *digits = [HQITIndianPhoneValidator digitsOnly:tf.text];
    NSInteger maxL = [HQITIndianPhoneValidator maxLengthForDigits:digits];
    if ((NSInteger)digits.length > maxL) digits = [digits substringToIndex:maxL];
    if (![digits isEqualToString:tf.text]) tf.text = digits;
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger n = self.imageItems.count;
    return n < kHQITFeedbackMaxImages ? n + 1 : n;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(72, 72);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isAdd = (indexPath.item == (NSInteger)self.imageItems.count);
    if (isAdd) {
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"add" forIndexPath:indexPath];
        for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];
        cell.contentView.backgroundColor = [UIColor clearColor];
        cell.contentView.layer.cornerRadius = 10;
        cell.contentView.clipsToBounds = YES;

        UIImageView *plus = [[UIImageView alloc] init];
        UIImage *add = [UIImage imageNamed:@"add_icon"];
        if (add) {
            plus.image = [add imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        } else {
            plus.image = [[UIImage systemImageNamed:@"plus"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            plus.tintColor = [self placeholderColor];
            plus.backgroundColor = [self fieldFillColor];
        }
        plus.contentMode = UIViewContentModeScaleAspectFill;
        plus.clipsToBounds = YES;
        [cell.contentView addSubview:plus];
        [plus mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(cell.contentView);
        }];
        return cell;
    }

    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"img" forIndexPath:indexPath];
    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];
    cell.contentView.backgroundColor = [self fieldFillColor];
    cell.contentView.layer.cornerRadius = 10;
    cell.contentView.clipsToBounds = YES;

    HQITFeedbackImageItem *item = self.imageItems[indexPath.item];
    UIImageView *iv = [[UIImageView alloc] initWithImage:item.image];
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    [cell.contentView addSubview:iv];
    [iv mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(cell.contentView);
    }];

    UIButton *del = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *close = [UIImage imageNamed:@"close_icon"] ?: [UIImage imageNamed:@"delete_icon"];
    if (close) {
        [del setImage:[close imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    } else {
        [del setTitle:@"×" forState:UIControlStateNormal];
        [del setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        del.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        del.layer.cornerRadius = 10;
    }
    del.tag = indexPath.item;
    [del addTarget:self action:@selector(onDeleteImage:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:del];
    [del mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(cell.contentView).offset(4);
        make.right.equalTo(cell.contentView).offset(-4);
        make.width.height.mas_equalTo(20);
    }];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item == (NSInteger)self.imageItems.count) {
        [self openAlbum];
    }
}

- (void)onDeleteImage:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.imageItems.count) return;
    [self.imageItems removeObjectAtIndex:idx];
    [self.imageCollection reloadData];
}

#pragma mark - Picker

- (void)openAlbum {
    if (self.isUploading || self.imageItems.count >= kHQITFeedbackMaxImages) return;
    [self.view endEditing:YES];
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (![provider canLoadObjectOfClass:[UIImage class]]) return;
    __weak typeof(self) weakSelf = self;
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading> object, NSError *error) {
        UIImage *img = (UIImage *)object;
        if (![img isKindOfClass:[UIImage class]]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf uploadImage:img];
        });
    }];
}

- (void)uploadImage:(UIImage *)image {
    if (self.imageItems.count >= kHQITFeedbackMaxImages) return;
    NSData *data = [HQITKYCImageHelper jpegDataUnder600KBFromImage:image];
    if (!data.length) {
        [HQITHUDHelper showToast:@"Failed to process image."];
        return;
    }
    self.isUploading = YES;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] uploadJPEGData:data success:^(NSString *imageURL) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isUploading = NO;
        HQITFeedbackImageItem *item = [[HQITFeedbackImageItem alloc] init];
        item.image = image;
        item.remoteURL = imageURL;
        [self.imageItems addObject:item];
        [self.imageCollection reloadData];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isUploading = NO;
    }];
}

#pragma mark - TextView

- (void)textViewDidChange:(UITextView *)textView {
    if ((NSInteger)textView.text.length > kHQITFeedbackMaxDesc) {
        textView.text = [textView.text substringToIndex:kHQITFeedbackMaxDesc];
    }
    [self updateCounter];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    return YES;
}

#pragma mark - Actions

- (void)hqit_leaveFeedbackAnimated:(BOOL)animated {
    UINavigationController *nav = self.navigationController;
    if (!nav) {
        if (self.presentingViewController) {
            [self dismissViewControllerAnimated:animated completion:nil];
        }
        return;
    }
    if (self.exitStyle == HQITFeedbackExitPopToNavRoot) {
        [nav popToRootViewControllerAnimated:animated];
        return;
    }
    if (nav.viewControllers.count > 1) {
        [nav popViewControllerAnimated:animated];
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:animated completion:nil];
    }
}

- (void)onBack {
    if (!self.backButton.enabled) return;
    self.backButton.enabled = NO;
    [self hqit_leaveFeedbackAnimated:YES];
}

- (void)onSubmit {
    if (self.isSubmitting || self.isUploading) return;
    if (![HQITClickGuard tryLockControl:self.submitButton]) return;
    [self.view endEditing:YES];

    NSString *phone = [HQITIndianPhoneValidator digitsOnly:self.phoneField.text];
    if (phone.length == 0) {
        [HQITHUDHelper showToast:@"Enter your phone number"];
        [HQITClickGuard unlockControl:self.submitButton];
        return;
    }
    if (![HQITIndianPhoneValidator isValidIndianMobile:phone]) {
        [HQITHUDHelper showToast:@"Your phone number is invalid. Please check."];
        [HQITClickGuard unlockControl:self.submitButton];
        return;
    }

    NSString *desc = [self.questionView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (desc.length == 0) {
        [HQITHUDHelper showToast:@"Please enter your question"];
        [HQITClickGuard unlockControl:self.submitButton];
        return;
    }

    NSMutableArray *urls = [NSMutableArray array];
    for (HQITFeedbackImageItem *item in self.imageItems) {
        if (item.remoteURL.length) [urls addObject:item.remoteURL];
    }

    NSMutableDictionary *unsignedData = [@{
        @"description": desc,
        @"contactWay": phone,
    } mutableCopy];
    if (urls.count) {
        unsignedData[@"pictureUrl"] = [urls componentsJoinedByString:@","];
    }

    self.isSubmitting = YES;
    self.submitButton.enabled = NO;
    self.submitButton.alpha = 0.5;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/user/problemFeedback"
                                         signedData:@{}
                                       unsignedData:unsignedData
                                        showLoading:@YES
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        self.submitButton.enabled = YES;
        self.submitButton.alpha = 1;
        [HQITClickGuard unlockControl:self.submitButton];
        [HQITHUDHelper showToast:@"Submitted successfully"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self hqit_leaveFeedbackAnimated:YES];
        });
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        self.submitButton.enabled = YES;
        self.submitButton.alpha = 1;
        [HQITClickGuard unlockControl:self.submitButton];
    }];
}

@end
