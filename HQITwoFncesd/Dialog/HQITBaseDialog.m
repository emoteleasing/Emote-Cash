

#import "HQITBaseDialog.h"
#import <Masonry/Masonry.h>

@interface HQITBaseDialog ()
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong, readwrite) UIView *cardView;
@property (nonatomic, assign) HQITDialogPlacement placement;
@end


@implementation HQITBaseDialog

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _allowBackgroundDismiss = NO;
        self.backgroundColor = [UIColor clearColor];

        _dimView = [[UIView alloc] init];
        _dimView.translatesAutoresizingMaskIntoConstraints = NO;
        _dimView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        [self addSubview:_dimView];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDimTapped)];
        [_dimView addGestureRecognizer:tap];

        _cardView = [[UIView alloc] init];
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        _cardView.backgroundColor = [UIColor colorWithRed:0x0F/255.0 green:0x17/255.0 blue:0x2A/255.0 alpha:1];
        _cardView.layer.cornerRadius = 16;
        _cardView.clipsToBounds = YES;
        [self addSubview:_cardView];
    }
    return self;
}

- (void)showInView:(UIView *)hostView placement:(HQITDialogPlacement)placement {
    self.placement = placement;
    self.frame = hostView.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [hostView addSubview:self];

    [self.dimView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];

    if (placement == HQITDialogPlacementCenter) {
        self.cardView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
        [self.cardView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.left.equalTo(self).offset(24);
            make.right.equalTo(self).offset(-24);
        }];
    } else {
        self.cardView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        [self.cardView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self);
            make.bottom.equalTo(self);
        }];
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];

    self.dimView.alpha = 0;
    CGAffineTransform t = (placement == HQITDialogPlacementBottom)
        ? CGAffineTransformMakeTranslation(0, 40)
        : CGAffineTransformMakeScale(0.96, 0.96);
    self.cardView.transform = t;
    [UIView animateWithDuration:0.25 animations:^{
        self.dimView.alpha = 1;
        self.cardView.transform = CGAffineTransformIdentity;
    }];
}

- (void)onDimTapped {
    if (self.allowBackgroundDismiss) {
        [self dismissAnimated:YES];
    }
}

- (void)dismissAnimated:(BOOL)animated {
    void (^finish)(void) = ^{
        [self removeFromSuperview];
        if (self.onDismiss) self.onDismiss();
    };
    if (!animated) {
        finish();
        return;
    }
    [UIView animateWithDuration:0.2 animations:^{
        self.dimView.alpha = 0;
        if (self.placement == HQITDialogPlacementBottom) {
            self.cardView.transform = CGAffineTransformMakeTranslation(0, 40);
        } else {
            self.cardView.alpha = 0;
        }
    } completion:^(BOOL finished) {
        finish();
    }];
}

@end
