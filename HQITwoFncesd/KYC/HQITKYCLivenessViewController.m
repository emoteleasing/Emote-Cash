

#import "HQITKYCLivenessViewController.h"
#import "HQITKYCNavigation.h"
#import "HQITKYCImageHelper.h"
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
#import <AVFoundation/AVFoundation.h>
#import <Masonry/Masonry.h>

typedef NS_ENUM(NSInteger, HQITLivenessPhase) {
    HQITLivenessPhaseIdle = 0,
    HQITLivenessPhaseCapturing,
    HQITLivenessPhasePreview,
};

static const CGFloat kHQITShutterBtnSize = 102.0;
static const CGFloat kHQITActionBtnSize = 52.0;

@interface HQITKYCLivenessViewController () <AVCapturePhotoCaptureDelegate>
@property (nonatomic, copy) NSString *kycId;
@property (nonatomic, copy) NSString *pageTitleText;
@property (nonatomic, assign) BOOL isLastUnfinished;
@property (nonatomic, assign) HQITLivenessPhase phase;
@property (nonatomic, assign) BOOL isSubmitting;

@property (nonatomic, strong) UIImageView *headerBg;
@property (nonatomic, strong) UIView *navContent;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;

@property (nonatomic, strong) UIView *hintCard;
@property (nonatomic, strong) UILabel *hintEN;
@property (nonatomic, strong) UILabel *hintHI;

@property (nonatomic, strong) UIView *circleWrap;
@property (nonatomic, strong) UIImageView *facePlaceholder; // face_icon
@property (nonatomic, strong) UIView *cameraHost;
@property (nonatomic, strong) UIImageView *previewImageView;

@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *shutterButton;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIView *confirmRow;

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIImage *capturedImage;
@end

@implementation HQITKYCLivenessViewController

- (instancetype)initWithKycId:(NSString *)kycId
                    pageTitle:(NSString *)pageTitle
             isLastUnfinished:(BOOL)isLastUnfinished {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _kycId = [kycId copy] ?: @"liveness";
        _pageTitleText = pageTitle.length ? [pageTitle copy] : @"Face identification";
        _isLastUnfinished = isLastUnfinished;
        _phase = HQITLivenessPhaseIdle;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [HQITClickGuard unlockControl:self.startButton];
    [HQITClickGuard unlockControl:self.confirmButton];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopCamera];
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
    self.previewLayer.frame = self.cameraHost.bounds;
    self.circleWrap.layer.cornerRadius = self.circleWrap.bounds.size.width * 0.5;
    [self layoutStartButtonGradient];
}

- (void)layoutStartButtonGradient {
    CAGradientLayer *g = nil;
    for (CALayer *layer in self.startButton.layer.sublayers) {
        if ([layer.name isEqualToString:@"hqit.start.gradient"]) {
            g = (CAGradientLayer *)layer;
            break;
        }
    }
    if (!g) return;
    g.frame = self.startButton.bounds;
    g.cornerRadius = 10;
}

- (void)hqit_setupBackButtonIfNeeded {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:[[UIView alloc] init]];
    self.navigationItem.hidesBackButton = YES;
}

- (BOOL)hqit_shouldPopBack {
    return NO;
}

#pragma mark - UI

- (UIColor *)navyFill {
    return [UIColor colorWithRed:0x1A/255.0 green:0x1B/255.0 blue:0x2D/255.0 alpha:1];
}

- (UIColor *)ringRed {
    return [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
}

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
    self.navTitleLabel.text = @"Face identification";
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.navTitleLabel.textAlignment = NSTextAlignmentLeft;
    [self.navContent addSubview:self.navTitleLabel];
    [self.navTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backButton.mas_right).offset(8);
        make.centerY.equalTo(self.backButton);
        make.right.lessThanOrEqualTo(self.navContent).offset(-16);
    }];

    // Hint card
    self.hintCard = [[UIView alloc] init];
    self.hintCard.backgroundColor = [UIColor whiteColor];
    self.hintCard.layer.cornerRadius = 12;
    [self.view addSubview:self.hintCard];
    [self.hintCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.headerBg.mas_bottom).offset(12);
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
    }];

    self.hintEN = [[UILabel alloc] init];
    self.hintEN.numberOfLines = 0;
    self.hintEN.font = [HQITFontHelper regularFontOfSize:14];
    self.hintEN.textColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    self.hintEN.text = [HQITCategoryText textForKey:@"m21"
                                       defaultText:@"Please put your face in the frame and take a clear selfie"];
    [self.hintCard addSubview:self.hintEN];
    [self.hintEN mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.hintCard).offset(14);
        make.left.equalTo(self.hintCard).offset(14);
        make.right.equalTo(self.hintCard).offset(-14);
    }];

    self.hintHI = [[UILabel alloc] init];
    self.hintHI.numberOfLines = 0;
    self.hintHI.font = [HQITFontHelper regularFontOfSize:12];
    self.hintHI.textColor = [UIColor colorWithRed:0x8A/255.0 green:0x8F/255.0 blue:0x98/255.0 alpha:1];
    self.hintHI.text = [HQITCategoryText textForKey:@"m22"
                                       defaultText:@"कृपया अपना चेहरा फ़्रेम में रखें और एक स्पष्ट सेल्फी लें"];
    [self.hintCard addSubview:self.hintHI];
    [self.hintHI mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.hintEN.mas_bottom).offset(6);
        make.left.right.equalTo(self.hintEN);
        make.bottom.equalTo(self.hintCard).offset(-14);
    }];

    self.circleWrap = [[UIView alloc] init];
    self.circleWrap.backgroundColor = [self navyFill];
    self.circleWrap.layer.borderWidth = 2.5;
    self.circleWrap.layer.borderColor = [self ringRed].CGColor;
    self.circleWrap.clipsToBounds = YES;
    [self.view addSubview:self.circleWrap];
    [self.circleWrap mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.hintCard.mas_bottom).offset(30);
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.equalTo(self.circleWrap.mas_width);
    }];

    self.facePlaceholder = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"face_icon"]];
    self.facePlaceholder.contentMode = UIViewContentModeScaleAspectFit;
    [self.circleWrap addSubview:self.facePlaceholder];
    [self.facePlaceholder mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.circleWrap);
    }];

    self.cameraHost = [[UIView alloc] init];
    self.cameraHost.hidden = YES;
    [self.circleWrap addSubview:self.cameraHost];
    [self.cameraHost mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.circleWrap);
    }];

    self.previewImageView = [[UIImageView alloc] init];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.previewImageView.clipsToBounds = YES;
    self.previewImageView.hidden = YES;
    [self.circleWrap addSubview:self.previewImageView];
    [self.previewImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.circleWrap);
    }];

    self.startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.startButton.clipsToBounds = YES;
    self.startButton.layer.cornerRadius = 10;
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.name = @"hqit.start.gradient";
    grad.colors = @[
        (id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
    ];
    grad.startPoint = CGPointMake(0.5, 0);
    grad.endPoint = CGPointMake(0.5, 1);
    [self.startButton.layer insertSublayer:grad atIndex:0];
    [self.startButton setTitle:[HQITCategoryText textForKey:@"m25" defaultText:@"Start"]
                      forState:UIControlStateNormal];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.startButton addTarget:self action:@selector(onStart) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startButton];
    [self.startButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16);
    }];

    self.shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.shutterButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.shutterButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    UIImage *cam = [UIImage imageNamed:@"rcamera_icon"];
    if (cam) {
        [self.shutterButton setImage:[cam imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                            forState:UIControlStateNormal];
        self.shutterButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        self.shutterButton.backgroundColor = [self ringRed];
        self.shutterButton.layer.cornerRadius = kHQITShutterBtnSize * 0.5;
        UIImage *sf = [[UIImage systemImageNamed:@"camera.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.shutterButton setImage:sf forState:UIControlStateNormal];
        self.shutterButton.tintColor = [UIColor whiteColor];
    }
    [self.shutterButton addTarget:self action:@selector(onShutter) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.shutterButton];
    [self.shutterButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-24);
        make.width.height.mas_equalTo(kHQITShutterBtnSize);
    }];

    self.confirmRow = [[UIView alloc] init];
    [self.view addSubview:self.confirmRow];
    [self.confirmRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-24);
        make.height.mas_equalTo(kHQITActionBtnSize);
    }];

    self.retryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.retryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.retryButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    UIImage *retryImg = [UIImage imageNamed:@"cencil_icon"];
    if (retryImg) {
        [self.retryButton setImage:[retryImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                          forState:UIControlStateNormal];
        self.retryButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        self.retryButton.backgroundColor = [UIColor whiteColor];
        self.retryButton.layer.cornerRadius = kHQITActionBtnSize * 0.5;
        self.retryButton.layer.borderWidth = 1;
        self.retryButton.layer.borderColor = [UIColor colorWithRed:0xE8/255.0 green:0xEA/255.0 blue:0xEE/255.0 alpha:1].CGColor;
        UIImage *sf = [[UIImage systemImageNamed:@"arrow.clockwise"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.retryButton setImage:sf forState:UIControlStateNormal];
        self.retryButton.tintColor = [UIColor colorWithRed:0x8A/255.0 green:0x8F/255.0 blue:0x98/255.0 alpha:1];
    }
    [self.retryButton addTarget:self action:@selector(onRetry) forControlEvents:UIControlEventTouchUpInside];
    [self.confirmRow addSubview:self.retryButton];

    self.confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.confirmButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.confirmButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    UIImage *sure = [UIImage imageNamed:@"redbeen_icon"];
    if (sure) {
        [self.confirmButton setImage:[sure imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                            forState:UIControlStateNormal];
        self.confirmButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        self.confirmButton.backgroundColor = [self ringRed];
        self.confirmButton.layer.cornerRadius = kHQITActionBtnSize * 0.5;
        UIImage *sf = [[UIImage systemImageNamed:@"checkmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.confirmButton setImage:sf forState:UIControlStateNormal];
        self.confirmButton.tintColor = [UIColor whiteColor];
    }
    [self.confirmButton addTarget:self action:@selector(onConfirm) forControlEvents:UIControlEventTouchUpInside];
    [self.confirmRow addSubview:self.confirmButton];

    [self.retryButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(self.confirmRow);
        make.width.height.mas_equalTo(kHQITActionBtnSize);
    }];
    [self.confirmButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.retryButton.mas_right).offset(40);
        make.right.top.bottom.equalTo(self.confirmRow);
        make.width.height.mas_equalTo(kHQITActionBtnSize);
    }];

    self.shutterButton.hidden = YES;
    self.confirmRow.hidden = YES;
    [self.view bringSubviewToFront:self.startButton];
    [self applyPhase];
}

- (void)applyPhase {
    BOOL idle = (self.phase == HQITLivenessPhaseIdle);
    BOOL capturing = (self.phase == HQITLivenessPhaseCapturing);
    BOOL preview = (self.phase == HQITLivenessPhasePreview);

    self.startButton.hidden = !idle;
    self.shutterButton.hidden = !capturing;
    self.confirmRow.hidden = !preview;

    self.facePlaceholder.hidden = !idle;
    self.cameraHost.hidden = !capturing;
    self.previewImageView.hidden = !preview;
    self.previewImageView.image = self.capturedImage;

    self.circleWrap.layer.borderWidth = idle ? 0 : 2.5;
    self.circleWrap.backgroundColor = idle ? [UIColor clearColor] : [self navyFill];
    self.circleWrap.clipsToBounds = YES;
}

#pragma mark - Camera

- (void)ensureCameraPermissionThen:(void (^)(BOOL granted))completion {
    AVAuthorizationStatus st = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (st == AVAuthorizationStatusAuthorized) {
        [HQITBuryRecorder recordCameraPermissionGranted:YES]; // 11
        if (completion) completion(YES);
        return;
    }
    if (st == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [HQITBuryRecorder recordCameraPermissionGranted:granted]; // 11 / 12
                if (completion) completion(granted);
            });
        }];
        return;
    }
    [HQITBuryRecorder recordCameraPermissionGranted:NO]; // 12
    UIView *host = self.view.window ?: self.view;
    [HQITPermissionSecondaryPresenter showCameraSettingsGuideInView:host
                                                          onConfirm:nil
                                                           onCancel:^{
        self.phase = HQITLivenessPhaseIdle;
        [self applyPhase];
    }];
    if (completion) completion(NO);
}

- (void)startCamera {
    [self stopCamera];
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                mediaType:AVMediaTypeVideo
                                                                 position:AVCaptureDevicePositionFront];
    if (!device) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m27" defaultText:@"Camera is unavailable..."]];
        self.phase = HQITLivenessPhaseIdle;
        [self applyPhase];
        return;
    }
    NSError *err = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];
    if (!input || err) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m27" defaultText:@"Camera is unavailable..."]];
        self.phase = HQITLivenessPhaseIdle;
        [self applyPhase];
        return;
    }
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        self.session.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
    }
    self.photoOutput = [[AVCapturePhotoOutput alloc] init];
    if ([self.session canAddOutput:self.photoOutput]) {
        [self.session addOutput:self.photoOutput];
    }
    if ([device lockForConfiguration:&err]) {
        if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
        if ([device isAutoFocusRangeRestrictionSupported]) {
            device.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
        }
        [device unlockForConfiguration];
    }
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.cameraHost.bounds;
    if (self.previewLayer.connection.isVideoMirroringSupported) {
        self.previewLayer.connection.automaticallyAdjustsVideoMirroring = NO;
        self.previewLayer.connection.videoMirrored = YES;
    }
    [self.cameraHost.layer addSublayer:self.previewLayer];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self.session startRunning];
    });
}

- (void)stopCamera {
    if (self.session.isRunning) {
        [self.session stopRunning];
    }
    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
    self.session = nil;
    self.photoOutput = nil;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output
didFinishProcessingPhoto:(AVCapturePhoto *)photo
                error:(NSError *)error {
    if (error || !photo) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m26" defaultText:@"Failed to take photo."]];
        return;
    }
    NSData *data = [photo fileDataRepresentation];
    UIImage *img = data.length ? [UIImage imageWithData:data] : nil;
    if (!img) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m26" defaultText:@"Failed to take photo."]];
        return;
    }
    self.capturedImage = img;
    [self stopCamera];
    self.phase = HQITLivenessPhasePreview;
    [self applyPhase];
}

#pragma mark - Actions

- (void)onBack {
    NSString *body = [HQITCategoryText textForKey:@"a40"
                                     defaultText:@"Do you want to pause the authentication and return to the homepage?"];
    UIView *host = self.view.window ?: self.view;
    [HQITDialogs showWhiteConfirmTitle:@"Confirm to return?"
                                  body:body
                                  icon:nil
                         confirmTitle:@"Confirm"
                          cancelTitle:@"Cancel"
                               inView:host
                            onConfirm:^{
        [self stopCamera];
        [HQITKYCNavigation confirmExitFrom:self];
    } onCancel:nil];
}

- (void)onStart {
    [self ensureCameraPermissionThen:^(BOOL granted) {
        if (!granted) return;
        self.phase = HQITLivenessPhaseCapturing;
        [self applyPhase];
        [self startCamera];
    }];
}

- (void)onShutter {
    if (!self.photoOutput) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m26" defaultText:@"Failed to take photo."]];
        return;
    }
    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
    [self.photoOutput capturePhotoWithSettings:settings delegate:self];
}

- (void)onRetry {
    self.capturedImage = nil;
    self.phase = HQITLivenessPhaseIdle;
    [self applyPhase];
}

- (void)onConfirm {
    if (self.isSubmitting) return;
    if (!self.capturedImage) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m28" defaultText:@"Please take a photo first."]];
        return;
    }
    if (![HQITClickGuard tryLockControl:self.confirmButton]) return;
    NSString *b64 = [HQITKYCImageHelper livenessBase64FromImage:self.capturedImage];
    if (b64.length == 0) {
        [HQITHUDHelper showToast:@"Image process failed"];
        [HQITClickGuard unlockControl:self.confirmButton];
        return;
    }
    self.isSubmitting = YES;
    self.confirmButton.enabled = NO;
    self.confirmButton.alpha = 0.5;
    __weak typeof(self) weakSelf = self;
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/kyc/liveness/silent"
                                         signedData:@{@"liveness": b64}
                                       unsignedData:nil
                                            success:^(HQITNetworkResponse *response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        self.confirmButton.enabled = YES;
        self.confirmButton.alpha = 1;
        [HQITKYCNavigation advanceFrom:self];
    } failure:^(NSError *error, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isSubmitting = NO;
        self.confirmButton.enabled = YES;
        self.confirmButton.alpha = 1;
        [HQITClickGuard unlockControl:self.confirmButton];
    }];
}

@end
