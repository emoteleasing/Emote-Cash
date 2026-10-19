

#import "HQITCaptureProgressDialog.h"
#import "HQITFontHelper.h"
#import <Masonry/Masonry.h>

@interface HQITCaptureProgressDialog ()
@property (nonatomic, strong) UIImageView *spinView;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIImageView *stepsImageView;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) NSTimeInterval totalDuration;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, strong, nullable) NSTimer *tickTimer;
@property (nonatomic, assign) BOOL finished;
@end

@implementation HQITCaptureProgressDialog

+ (instancetype)showInView:(UIView *)hostView {
    HQITCaptureProgressDialog *dialog = [[HQITCaptureProgressDialog alloc] initWithFrame:hostView.bounds];
    [dialog showInView:hostView placement:HQITDialogPlacementCenter];
    [dialog startProgressAnimation];
    return dialog;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.allowBackgroundDismiss = NO;
        self.cardView.backgroundColor = [UIColor whiteColor];
        self.cardView.layer.cornerRadius = 16;
        self.cardView.clipsToBounds = YES;
        _progress = 12.0;
        [self buildContent];
        [self refreshProgressUI];
    }
    return self;
}

- (UIColor *)colorSpinner {
    return [UIColor colorWithRed:0xB0/255.0 green:0xB0/255.0 blue:0xB0/255.0 alpha:1];
}

- (NSAttributedString *)attributedText:(NSString *)text
                              fontSize:(CGFloat)fontSize
                                 color:(UIColor *)color
                             lineHeight:(CGFloat)lineHeight {
    if (text.length == 0) return [[NSAttributedString alloc] initWithString:@""];
    UIFont *font = [HQITFontHelper regularFontOfSize:fontSize];
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    ps.minimumLineHeight = lineHeight;
    ps.maximumLineHeight = lineHeight;
    CGFloat baseline = (lineHeight - font.lineHeight) / 2.0;
    return [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: ps,
        NSBaselineOffsetAttributeName: @(baseline),
    }];
}

- (void)buildContent {
    UIColor *black = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
    UIColor *gray66 = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];

    self.spinView = [[UIImageView alloc] init];
    UIImage *spinImg = [UIImage imageNamed:@"jzloding_icon"];
    if (spinImg) {
        self.spinView.image = [spinImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.spinView.tintColor = [self colorSpinner];
    }
    self.spinView.contentMode = UIViewContentModeScaleAspectFit;
    [self.cardView addSubview:self.spinView];
    [self.spinView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView).offset(28);
        make.centerX.equalTo(self.cardView);
        make.width.height.mas_equalTo(28);
    }];

    self.percentLabel = [[UILabel alloc] init];
    self.percentLabel.font = [HQITFontHelper regularFontOfSize:13];
    self.percentLabel.textColor = black;
    self.percentLabel.textAlignment = NSTextAlignmentCenter;
    [self.cardView addSubview:self.percentLabel];
    [self.percentLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.spinView.mas_bottom).offset(10);
        make.left.equalTo(self.cardView).offset(20);
        make.right.equalTo(self.cardView).offset(-20);
    }];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.attributedText = [self attributedText:@"Please wait a moment~ We're updating your credit score, it will be done in around 15 seconds!"
                                                   fontSize:14
                                                      color:gray66
                                                  lineHeight:23];
    [self.cardView addSubview:self.messageLabel];
    [self.messageLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.percentLabel.mas_bottom).offset(10);
        make.left.equalTo(self.cardView).offset(24);
        make.right.equalTo(self.cardView).offset(-24);
    }];

    self.stepsImageView = [[UIImageView alloc] init];
    UIImage *stepsImg = [UIImage imageNamed:@"apply_image"];
    self.stepsImageView.image = stepsImg ? [stepsImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] : nil;
    self.stepsImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.cardView addSubview:self.stepsImageView];
    [self.stepsImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.messageLabel.mas_bottom).offset(6);
        make.left.equalTo(self.cardView).offset(43);
        make.right.equalTo(self.cardView).offset(-33);
        make.height.mas_equalTo(47);
    }];

    self.footerLabel = [[UILabel alloc] init];
    self.footerLabel.numberOfLines = 0;
    self.footerLabel.attributedText = [self attributedText:@"Just one more step before your loan is credited, please don't leave this page."
                                                  fontSize:12
                                                     color:gray66
                                                 lineHeight:16];
    [self.cardView addSubview:self.footerLabel];
    [self.footerLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.stepsImageView.mas_bottom).offset(13);
        make.left.equalTo(self.cardView).offset(24);
        make.right.equalTo(self.cardView).offset(-24);
        make.bottom.equalTo(self.cardView).offset(-24);
    }];
}

#pragma mark - Progress

- (void)startProgressAnimation {
    [self startSpin];
    self.finished = NO;
    self.progress = 12.0;
    self.totalDuration = 10.0 + (arc4random_uniform(11000) / 1000.0); // 10.000 ~ 20.999
    if (self.totalDuration > 20.0) self.totalDuration = 20.0;
    self.startTime = CACurrentMediaTime();
    [self refreshProgressUI];
    [self scheduleNextTick];
}

- (void)startSpin {
    [self.spinView.layer removeAnimationForKey:@"hqit_capture_spin"];
    CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    spin.fromValue = @0;
    spin.toValue = @(M_PI * 2);
    spin.duration = 1.0;
    spin.repeatCount = HUGE_VALF;
    spin.removedOnCompletion = NO;
    [self.spinView.layer addAnimation:spin forKey:@"hqit_capture_spin"];
}

- (void)scheduleNextTick {
    if (self.finished) return;
    [self.tickTimer invalidate];
    NSTimeInterval delay = (1 + arc4random_uniform(3000)) / 1000.0; // 1~3000ms
    __weak typeof(self) weakSelf = self;
    self.tickTimer = [NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:^(NSTimer *timer) {
        [weakSelf onTick];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.tickTimer forMode:NSRunLoopCommonModes];
}

- (void)onTick {
    if (self.finished) return;
    NSTimeInterval elapsed = CACurrentMediaTime() - self.startTime;
    if (self.progress >= 99.0 - 0.001 || elapsed >= self.totalDuration) {
        self.progress = 99.0;
        [self refreshProgressUI];
        return;
    }

    double remainingT = MAX(0.05, self.totalDuration - elapsed);
    double remainingP = 99.0 - self.progress;
    double delayShare = MIN(1.0, (1.0 + arc4random_uniform(3000)) / 1000.0 / remainingT);
    double factor = 0.4 + (arc4random_uniform(120) / 100.0); // 0.4 ~ 1.59
    double inc = remainingP * delayShare * factor;
    if (inc < 0.2) inc = 0.2;
    if (inc > remainingP) inc = remainingP;
    if (remainingT > 1.5 && inc > remainingP * 0.55) {
        inc = remainingP * (0.25 + (arc4random_uniform(30) / 100.0));
    }
    self.progress = MIN(99.0, self.progress + inc);
    [self refreshProgressUI];
    if (self.progress < 99.0) {
        [self scheduleNextTick];
    }
}

- (void)refreshProgressUI {
    NSInteger p = (NSInteger)llround(self.progress);
    if (p > 99) p = 99;
    self.percentLabel.text = [NSString stringWithFormat:@"%ld%%", (long)p];
}

- (void)dismissAnimated:(BOOL)animated {
    self.finished = YES;
    [self.tickTimer invalidate];
    self.tickTimer = nil;
    [self.spinView.layer removeAnimationForKey:@"hqit_capture_spin"];
    self.progress = 100.0;
    [self refreshProgressUI];
    [super dismissAnimated:animated];
}

- (void)dealloc {
    [self.tickTimer invalidate];
}

@end
