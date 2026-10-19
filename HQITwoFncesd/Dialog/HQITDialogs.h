

#import <UIKit/UIKit.h>
#import "HQITBaseDialog.h"

@class HQITLoanApplyDetailRow;

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITDialogActionBlock)(void);
typedef void (^HQITRatingSubmitBlock)(NSInteger stars);

@interface HQITSelectionOption : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *label;
+ (instancetype)optionWithKey:(NSString *)key label:(NSString *)label;
@end

typedef void (^HQITSelectionConfirmBlock)(HQITSelectionOption *option);

@interface HQITDialogs : NSObject

+ (HQITBaseDialog *)showTitle:(nullable NSString *)title
                         body:(NSString *)body
                confirmTitle:(NSString *)confirmTitle
                 cancelTitle:(nullable NSString *)cancelTitle
                   placement:(HQITDialogPlacement)placement
                      inView:(UIView *)hostView
                   onConfirm:(nullable HQITDialogActionBlock)onConfirm
                    onCancel:(nullable HQITDialogActionBlock)onCancel;

+ (HQITBaseDialog *)showBody:(NSString *)body
               confirmTitle:(NSString *)confirmTitle
                cancelTitle:(nullable NSString *)cancelTitle
                  placement:(HQITDialogPlacement)placement
                     inView:(UIView *)hostView
                  onConfirm:(nullable HQITDialogActionBlock)onConfirm
                   onCancel:(nullable HQITDialogActionBlock)onCancel;

+ (HQITBaseDialog *)showIcon:(nullable UIImage *)icon
                       title:(NSString *)title
                        body:(NSString *)body
               confirmTitle:(NSString *)confirmTitle
                cancelTitle:(nullable NSString *)cancelTitle
                     inView:(UIView *)hostView
                  onConfirm:(nullable HQITDialogActionBlock)onConfirm
                   onCancel:(nullable HQITDialogActionBlock)onCancel;

+ (HQITBaseDialog *)showSelectionTitle:(NSString *)title
                               options:(NSArray<HQITSelectionOption *> *)options
                           selectedKey:(nullable NSString *)selectedKey
                                inView:(UIView *)hostView
                            onConfirm:(nullable HQITSelectionConfirmBlock)onConfirm
                             onCancel:(nullable HQITDialogActionBlock)onCancel;

+ (HQITBaseDialog *)showVersionUpgradeWithVersion:(nullable NSString *)version
                                      forceUpdate:(BOOL)forceUpdate
                                        updateURL:(nullable NSString *)updateURL
                                           inView:(UIView *)hostView
                                        onUpgrade:(nullable HQITDialogActionBlock)onUpgrade
                                         onCancel:(nullable HQITDialogActionBlock)onCancel;

+ (HQITBaseDialog *)showWhiteConfirmTitle:(NSString *)title
                                     body:(NSString *)body
                                     icon:(nullable UIImage *)icon
                            confirmTitle:(NSString *)confirmTitle
                             cancelTitle:(nullable NSString *)cancelTitle
                           cancelPrimary:(BOOL)cancelPrimary
                                  inView:(UIView *)hostView
                               onConfirm:(nullable HQITDialogActionBlock)onConfirm
                                onCancel:(nullable HQITDialogActionBlock)onCancel;

+ (HQITBaseDialog *)showWhiteConfirmTitle:(NSString *)title
                                     body:(NSString *)body
                                     icon:(nullable UIImage *)icon
                            confirmTitle:(NSString *)confirmTitle
                             cancelTitle:(nullable NSString *)cancelTitle
                                  inView:(UIView *)hostView
                               onConfirm:(nullable HQITDialogActionBlock)onConfirm
                                onCancel:(nullable HQITDialogActionBlock)onCancel;

+ (HQITBaseDialog *)showPermissionTitle:(nullable NSString *)title
                                   body:(NSString *)body
                                   icon:(nullable UIImage *)icon
                             symbolName:(nullable NSString *)symbolName
                          confirmTitle:(NSString *)confirmTitle
                           cancelTitle:(nullable NSString *)cancelTitle
                                inView:(UIView *)hostView
                             onConfirm:(nullable HQITDialogActionBlock)onConfirm
                              onCancel:(nullable HQITDialogActionBlock)onCancel;

+ (HQITBaseDialog *)showDocumentVerifyFailInView:(UIView *)hostView
                                       onConfirm:(nullable HQITDialogActionBlock)onConfirm;

+ (UIImage *)orangeCheckHeaderIcon;

+ (HQITBaseDialog *)showRatingGuideInView:(UIView *)hostView
                                 onSubmit:(HQITRatingSubmitBlock)onSubmit
                                  onCancel:(nullable HQITDialogActionBlock)onCancel
                            onEmptySubmit:(nullable HQITDialogActionBlock)onEmptySubmit;

+ (HQITBaseDialog *)showRatingThanksInView:(UIView *)hostView
                                 onConfirm:(nullable HQITDialogActionBlock)onConfirm;

+ (HQITBaseDialog *)showMatchingProgressInView:(UIView *)hostView;

+ (HQITBaseDialog *)showCaptureProgressInView:(UIView *)hostView;

+ (HQITBaseDialog *)showLoanDetailsRows:(NSArray<HQITLoanApplyDetailRow *> *)rows
                                 inView:(UIView *)hostView
                               onCancel:(nullable HQITDialogActionBlock)onCancel;

@end

NS_ASSUME_NONNULL_END
