

#import "HQITKYCDocumentCameraViewController.h"
#import "HQITKYCImageHelper.h"
#import "HQITCategoryText.h"
#import "HQITPermissionSecondaryPresenter.h"
#import "HQITBuryRecorder.h"
#import "HQITHUDHelper.h"
#import "HQITClickGuard.h"
#import <AVFoundation/AVFoundation.h>
#import <Masonry/Masonry.h>

typedef NS_ENUM(NSInteger, HQITDocCamPhase) {
    HQITDocCamPhaseCapturing = 0,
    HQITDocCamPhasePreview,
};

static const CGFloat kHQITDocShutterSize = 64.0;
static const CGFloat kHQITDocActionSize = 48.0;
static const CGFloat kHQITDocBackSize = 44.0;
static const CGFloat kHQITDocCropCornerRadius = 12.0;

@interface HQITKYCDocumentCameraViewController () <AVCapturePhotoCaptureDelegate>
@property (nonatomic, copy) HQITDocumentCameraCompletion completion;
@property (nonatomic, assign) HQITDocCamPhase phase;

@property (nonatomic, strong) UIView *cameraHost;
@property (nonatomic, strong) UIImageView *fullPreviewImageView;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UIView *guideHost;
@property (nonatomic, strong) UIView *guideContainer;
@property (nonatomic, strong) UIImageView *frameOverlay;   // takewhen_bg
@property (nonatomic, strong) UIImageView *tipOverlay;
@property (nonatomic, strong) UIButton *backButton;        // white_back_icon
@property (nonatomic, strong) UIButton *shutterButton;     // camera_icon
@property (nonatomic, strong) UIView *actionRow;
@property (nonatomic, strong) UIButton *confirmButton;     // the_icon
@property (nonatomic, strong) UIButton *retakeButton;      // fcencil_icon

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong, nullable) UIImage *capturedFullImage;
@property (nonatomic, strong, nullable) UIImage *capturedImage;
@end

@implementation HQITKYCDocumentCameraViewController

- (instancetype)initWithCompletion:(HQITDocumentCameraCompletion)completion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _completion = [completion copy];
        _phase = HQITDocCamPhaseCapturing;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = YES;
    self.view.backgroundColor = [UIColor blackColor];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [HQITClickGuard unlockControl:self.shutterButton];
    [HQITClickGuard unlockControl:self.confirmButton];
    if (self.phase == HQITDocCamPhaseCapturing) {
        [self ensureCameraThenStart];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopCamera];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.previewLayer.frame = self.cameraHost.bounds;
    AVCaptureConnection *conn = self.previewLayer.connection;
    if (conn.isVideoOrientationSupported) {
        conn.videoOrientation = [self hqit_captureVideoOrientation];
    }
}

- (void)hqit_setupBackButtonIfNeeded {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:[[UIView alloc] init]];
    self.navigationItem.hidesBackButton = YES;
}

- (BOOL)hqit_shouldPopBack {
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - UI

- (void)buildUI {
    self.cameraHost = [[UIView alloc] init];
    self.cameraHost.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.cameraHost];
    [self.cameraHost mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    self.fullPreviewImageView = [[UIImageView alloc] init];
    self.fullPreviewImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.fullPreviewImageView.clipsToBounds = YES;
    self.fullPreviewImageView.hidden = YES;
    [self.view addSubview:self.fullPreviewImageView];
    [self.fullPreviewImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.backButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    UIImage *backImg = [UIImage imageNamed:@"white_back_icon"];
    if (backImg) {
        [self.backButton setImage:[backImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                         forState:UIControlStateNormal];
        self.backButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    [self.backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.backButton];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(8);
        make.centerX.equalTo(self.view);
        make.width.height.mas_equalTo(kHQITDocBackSize);
    }];

    self.shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.shutterButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.shutterButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    UIImage *shutter = [UIImage imageNamed:@"camera_icon"];
    if (shutter) {
        [self.shutterButton setImage:[shutter imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                            forState:UIControlStateNormal];
        self.shutterButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    [self.shutterButton addTarget:self action:@selector(onShutter) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.shutterButton];
    [self.shutterButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-24);
        make.width.height.mas_equalTo(kHQITDocShutterSize);
    }];

    self.actionRow = [[UIView alloc] init];
    self.actionRow.hidden = YES;
    [self.view addSubview:self.actionRow];
    [self.actionRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-24);
        make.height.mas_equalTo(kHQITDocActionSize);
    }];

    self.confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.confirmButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.confirmButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    UIImage *confirm = [UIImage imageNamed:@"the_icon"];
    if (confirm) {
        [self.confirmButton setImage:[confirm imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                            forState:UIControlStateNormal];
        self.confirmButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    [self.confirmButton addTarget:self action:@selector(onConfirm) forControlEvents:UIControlEventTouchUpInside];
    [self.actionRow addSubview:self.confirmButton];

    self.retakeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.retakeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.retakeButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    UIImage *retake = [UIImage imageNamed:@"fcencil_icon"];
    if (retake) {
        [self.retakeButton setImage:[retake imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                           forState:UIControlStateNormal];
        self.retakeButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    [self.retakeButton addTarget:self action:@selector(onRetake) forControlEvents:UIControlEventTouchUpInside];
    [self.actionRow addSubview:self.retakeButton];

    [self.confirmButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(self.actionRow);
        make.width.height.mas_equalTo(kHQITDocActionSize);
    }];
    [self.retakeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.confirmButton.mas_right).offset(48);
        make.right.top.bottom.equalTo(self.actionRow);
        make.width.height.mas_equalTo(kHQITDocActionSize);
    }];

    self.guideHost = [[UIView alloc] init];
    self.guideHost.userInteractionEnabled = NO;
    [self.view addSubview:self.guideHost];
    [self.guideHost mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.right.equalTo(self.view).offset(-20);
        make.top.equalTo(self.backButton.mas_bottom).offset(16);
        make.bottom.equalTo(self.shutterButton.mas_top).offset(-20);
    }];

    self.guideContainer = [[UIView alloc] init];
    self.guideContainer.userInteractionEnabled = NO;
    self.guideContainer.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.guideContainer.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.guideHost addSubview:self.guideContainer];
    [self.guideContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.guideHost);
        make.width.equalTo(self.guideContainer.mas_height).multipliedBy(666.0 / 1080.0);
        make.width.lessThanOrEqualTo(self.guideHost);
        make.height.lessThanOrEqualTo(self.guideHost);
        make.height.equalTo(self.guideHost).priorityHigh();
        make.width.equalTo(self.guideHost).priorityHigh();
    }];

    self.previewImageView = [[UIImageView alloc] init];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.previewImageView.clipsToBounds = YES;
    self.previewImageView.hidden = YES;
    [self.guideContainer addSubview:self.previewImageView];
    [self.previewImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.guideContainer);
    }];

    self.frameOverlay = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"takewhen_bg"]];
    self.frameOverlay.contentMode = UIViewContentModeScaleToFill;
    self.frameOverlay.userInteractionEnabled = NO;
    [self.guideContainer addSubview:self.frameOverlay];
    [self.frameOverlay mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.guideContainer);
    }];

    self.tipOverlay = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"take_bg"]];
    self.tipOverlay.contentMode = UIViewContentModeScaleAspectFit;
    self.tipOverlay.userInteractionEnabled = NO;
    [self.guideContainer addSubview:self.tipOverlay];
    [self.tipOverlay mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.guideContainer).offset(-18);
        make.centerY.equalTo(self.guideContainer);
        make.height.equalTo(self.guideContainer).multipliedBy(914.0 / 1080.0 * 0.92);
        make.width.equalTo(self.tipOverlay.mas_height).multipliedBy(70.0 / 914.0);
        make.left.greaterThanOrEqualTo(self.guideContainer).offset(18);
    }];

    [self.view bringSubviewToFront:self.backButton];
    [self.view bringSubviewToFront:self.shutterButton];
    [self.view bringSubviewToFront:self.actionRow];
    [self applyPhase];
}

- (void)applyPhase {
    BOOL capturing = (self.phase == HQITDocCamPhaseCapturing);
    BOOL preview = (self.phase == HQITDocCamPhasePreview);
    self.shutterButton.hidden = !capturing;
    self.actionRow.hidden = !preview;
    self.fullPreviewImageView.hidden = !preview;
    self.fullPreviewImageView.image = preview ? self.capturedFullImage : nil;
    self.previewImageView.hidden = !preview;
    self.previewImageView.image = preview ? self.capturedImage : nil;
    self.tipOverlay.hidden = preview;
    self.cameraHost.hidden = preview;
    self.guideContainer.layer.cornerRadius = preview ? kHQITDocCropCornerRadius : 0;
}

#pragma mark - Camera

- (void)ensureCameraThenStart {
    AVAuthorizationStatus st = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (st == AVAuthorizationStatusAuthorized) {
        [HQITBuryRecorder recordCameraPermissionGranted:YES]; // 11
        [self startCamera];
        return;
    }
    if (st == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [HQITBuryRecorder recordCameraPermissionGranted:granted]; // 11 / 12
                if (granted) {
                    [self startCamera];
                } else {
                    [self dismissWithImage:nil];
                }
            });
        }];
        return;
    }
    [HQITBuryRecorder recordCameraPermissionGranted:NO]; // 12
    [HQITPermissionSecondaryPresenter showCameraSettingsGuideInView:self.view.window ?: self.view
                                                          onConfirm:nil
                                                           onCancel:^{
        [self dismissWithImage:nil];
    }];
}

- (AVCaptureDevice *)hqit_rearDocumentCamera {
    AVCaptureDevice *ultra = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInUltraWideCamera
                                                                mediaType:AVMediaTypeVideo
                                                                 position:AVCaptureDevicePositionBack];
    if (ultra) return ultra;
    return [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                              mediaType:AVMediaTypeVideo
                                               position:AVCaptureDevicePositionBack];
}

- (void)startCamera {
    [self stopCamera];
    AVCaptureDevice *device = [self hqit_rearDocumentCamera];
    if (!device) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m27" defaultText:@"Camera is unavailable..."]];
        [self dismissWithImage:nil];
        return;
    }
    NSError *err = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];
    if (!input || err) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m27" defaultText:@"Camera is unavailable..."]];
        [self dismissWithImage:nil];
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
    AVCaptureConnection *previewConn = self.previewLayer.connection;
    if (previewConn.isVideoMirroringSupported) {
        previewConn.automaticallyAdjustsVideoMirroring = NO;
        previewConn.videoMirrored = NO;
    }
    if (previewConn.isVideoOrientationSupported) {
        previewConn.videoOrientation = [self hqit_captureVideoOrientation];
    }
    [self.cameraHost.layer addSublayer:self.previewLayer];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self.session startRunning];
    });
}

- (AVCaptureVideoOrientation)hqit_captureVideoOrientation {
    UIInterfaceOrientation io = UIInterfaceOrientationPortrait;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = self.view.window.windowScene;
        if (scene) io = scene.interfaceOrientation;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        io = UIApplication.sharedApplication.statusBarOrientation;
#pragma clang diagnostic pop
    }
    switch (io) {
        case UIInterfaceOrientationLandscapeLeft: return AVCaptureVideoOrientationLandscapeLeft;
        case UIInterfaceOrientationLandscapeRight: return AVCaptureVideoOrientationLandscapeRight;
        case UIInterfaceOrientationPortraitUpsideDown: return AVCaptureVideoOrientationPortraitUpsideDown;
        default: return AVCaptureVideoOrientationPortrait;
    }
}

- (UIImage *)hqit_uprightImageMatchingPreview:(UIImage *)image {
    UIImage *src = [HQITKYCImageHelper normalizeOrientation:image];
    if (!src) return nil;
    BOOL viewPortrait = self.view.bounds.size.height >= self.view.bounds.size.width;
    if (viewPortrait && src.size.width > src.size.height) {
        return [HQITKYCImageHelper rotateLeft90:src] ?: src;
    }
    return src;
}

- (UIImage *)hqit_cropImageToGuideFrame:(UIImage *)photo {
    if (!photo) return nil;
    [self.view layoutIfNeeded];
    UIImage *upright = [self hqit_uprightImageMatchingPreview:photo];
    CGRect hostBounds = self.cameraHost.bounds;
    CGRect guideInHost = [self.guideContainer convertRect:self.guideContainer.bounds toView:self.cameraHost];
    if (CGRectIsEmpty(guideInHost) || CGRectGetWidth(guideInHost) < 1 || CGRectGetHeight(guideInHost) < 1) {
        return upright;
    }

    if (self.previewLayer) {
        CGRect rectInLayer = [self.previewLayer convertRect:guideInHost fromLayer:self.cameraHost.layer];
        CGRect meta = [self.previewLayer metadataOutputRectOfInterestForRect:rectInLayer];
        if (!CGRectIsEmpty(meta) && meta.size.width > 0.001 && meta.size.height > 0.001) {
            CGFloat pw = upright.size.width * upright.scale;
            CGFloat ph = upright.size.height * upright.scale;
            CGRect pixel = CGRectMake(meta.origin.x * pw,
                                      meta.origin.y * ph,
                                      meta.size.width * pw,
                                      meta.size.height * ph);
            pixel = CGRectIntersection(CGRectIntegral(pixel), CGRectMake(0, 0, pw, ph));
            if (pixel.size.width >= 2 && pixel.size.height >= 2 && upright.CGImage) {
                CGImageRef cg = CGImageCreateWithImageInRect(upright.CGImage, pixel);
                if (cg) {
                    UIImage *cropped = [UIImage imageWithCGImage:cg scale:upright.scale orientation:UIImageOrientationUp];
                    CGImageRelease(cg);
                    if (cropped) return cropped;
                }
            }
        }
    }

    return [HQITKYCImageHelper cropImage:upright
                   aspectFillInViewBounds:hostBounds
                            cropRectInView:guideInHost] ?: upright;
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
        [HQITClickGuard unlockControl:self.shutterButton];
        return;
    }
    NSData *data = [photo fileDataRepresentation];
    UIImage *img = data.length ? [UIImage imageWithData:data] : nil;
    if (!img) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m26" defaultText:@"Failed to take photo."]];
        [HQITClickGuard unlockControl:self.shutterButton];
        return;
    }
    UIImage *upright = [self hqit_uprightImageMatchingPreview:img];
    UIImage *cropped = [self hqit_cropImageToGuideFrame:img];
    self.capturedFullImage = upright;
    self.capturedImage = cropped ?: upright;
    [self stopCamera];
    self.phase = HQITDocCamPhasePreview;
    [self applyPhase];
    [HQITClickGuard unlockControl:self.shutterButton];
}

#pragma mark - Actions

- (void)onBack {
    [self dismissWithImage:nil];
}

- (void)onShutter {
    if (self.phase != HQITDocCamPhaseCapturing) return;
    if (![HQITClickGuard tryLockControl:self.shutterButton]) return;
    if (!self.photoOutput || !self.session.isRunning) {
        [HQITClickGuard unlockControl:self.shutterButton];
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m26" defaultText:@"Failed to take photo."]];
        return;
    }
    AVCaptureConnection *photoConn = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (photoConn.isVideoOrientationSupported) {
        photoConn.videoOrientation = [self hqit_captureVideoOrientation];
    }
    if (photoConn.isVideoMirroringSupported) {
        photoConn.videoMirrored = NO;
    }
    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
    [self.photoOutput capturePhotoWithSettings:settings delegate:self];
}

- (void)onRetake {
    self.capturedImage = nil;
    self.capturedFullImage = nil;
    self.phase = HQITDocCamPhaseCapturing;
    [self applyPhase];
    [self ensureCameraThenStart];
}

- (void)onConfirm {
    if (!self.capturedImage) {
        [HQITHUDHelper showToast:[HQITCategoryText textForKey:@"m28" defaultText:@"Please take a photo first."]];
        return;
    }
    if (![HQITClickGuard tryLockControl:self.confirmButton]) return;
    UIImage *img = self.capturedImage;
    [self dismissWithImage:img];
}

- (void)dismissWithImage:(UIImage *)image {
    HQITDocumentCameraCompletion block = self.completion;
    [self dismissViewControllerAnimated:YES completion:^{
        if (block) block(image);
    }];
}

@end
