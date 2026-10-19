

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITPermissionActionBlock)(void);

@interface HQITPermissionSecondaryPresenter : NSObject

+ (void)showBodyKey:(NSString *)copyKey
       defaultBody:(NSString *)defaultBody
            inView:(UIView *)hostView
         onConfirm:(nullable HQITPermissionActionBlock)onConfirm
          onCancel:(nullable HQITPermissionActionBlock)onCancel;

+ (void)showCameraSettingsGuideInView:(UIView *)hostView
                            onConfirm:(nullable HQITPermissionActionBlock)onConfirm
                             onCancel:(nullable HQITPermissionActionBlock)onCancel;

+ (void)showLocationSettingsGuideInView:(UIView *)hostView
                              onConfirm:(nullable HQITPermissionActionBlock)onConfirm
                               onCancel:(nullable HQITPermissionActionBlock)onCancel;

+ (void)showContactsSettingsGuideInView:(UIView *)hostView
                              onConfirm:(nullable HQITPermissionActionBlock)onConfirm
                               onCancel:(nullable HQITPermissionActionBlock)onCancel;

+ (void)openSystemSettings;

@end

NS_ASSUME_NONNULL_END
