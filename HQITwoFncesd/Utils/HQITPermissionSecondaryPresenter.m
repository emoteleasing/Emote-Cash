

#import "HQITPermissionSecondaryPresenter.h"
#import "HQITDialogs.h"

static NSString * const kHQITAppDisplayName = @"Emote Cash";

@implementation HQITPermissionSecondaryPresenter

+ (NSString *)fixedContactsBody {
    return [NSString stringWithFormat:
            @"To run fraud checks and confirm your identity, %@ requires permission to read your contacts. "
            @"When the system asks, select \"Allow Full Access\" so your application review is not delayed. "
            @"Contact details are sent to our server only for this security check; we do not keep them on file "
            @"or pass them to anyone else. You may revoke or change this access later under Settings.",
            kHQITAppDisplayName];
}

+ (NSString *)fixedLocationBody {
    return [NSString stringWithFormat:
            @"Location is turned off for %@. Turn it on in Settings so we can finish processing your loan application.",
            kHQITAppDisplayName];
}

+ (NSString *)fixedCameraBody {
    return [NSString stringWithFormat:
            @"Camera is disabled for %@. Enable it in Settings to capture the photos required for this step.",
            kHQITAppDisplayName];
}

+ (BOOL)hqit_shouldOpenSettingsForKey:(NSString *)copyKey {
    NSString *key = copyKey.lowercaseString ?: @"";
    if ([key isEqualToString:@"b2"] || [key isEqualToString:@"b3"]) return YES;
    if ([key hasPrefix:@"b4"] || [key isEqualToString:@"b5"] || [key isEqualToString:@"b6"]) return YES;
    return NO;
}

+ (NSString *)fixedBodyForCopyKey:(NSString *)copyKey fallback:(NSString *)fallback {
    NSString *key = copyKey.lowercaseString ?: @"";
    if ([key isEqualToString:@"b2"]) return [self fixedCameraBody];
    if ([key isEqualToString:@"b3"]) return [self fixedLocationBody];
    if ([key hasPrefix:@"b4"] || [key isEqualToString:@"b5"] || [key isEqualToString:@"b6"]) {
        return [self fixedContactsBody];
    }
    return fallback.length ? fallback : @"";
}

+ (void)hqit_iconAndSymbolForCopyKey:(NSString *)copyKey
                                icon:(UIImage * _Nullable * _Nonnull)outIcon
                          symbolName:(NSString * _Nullable * _Nonnull)outSymbol
                               title:(NSString * _Nullable * _Nonnull)outTitle {
    (void)copyKey;
    *outIcon = [UIImage imageNamed:@"and_icon_t"];
    *outSymbol = @"bell.fill";
    *outTitle = nil;
}

+ (void)showBodyKey:(NSString *)copyKey
       defaultBody:(NSString *)defaultBody
            inView:(UIView *)hostView
         onConfirm:(HQITPermissionActionBlock)onConfirm
          onCancel:(HQITPermissionActionBlock)onCancel {
    NSString *body = [self fixedBodyForCopyKey:copyKey fallback:defaultBody];
    UIImage *icon = nil;
    NSString *symbol = nil;
    NSString *title = nil;
    [self hqit_iconAndSymbolForCopyKey:copyKey icon:&icon symbolName:&symbol title:&title];
    BOOL openSettings = [self hqit_shouldOpenSettingsForKey:copyKey];
    [HQITDialogs showPermissionTitle:title
                                body:body
                                icon:icon
                          symbolName:symbol
                       confirmTitle:@"Confirm"
                        cancelTitle:@"Cancel"
                             inView:hostView
                          onConfirm:^{
        if (openSettings) [self openSystemSettings];
        if (onConfirm) onConfirm();
    } onCancel:onCancel];
}

+ (void)showCameraSettingsGuideInView:(UIView *)hostView
                            onConfirm:(HQITPermissionActionBlock)onConfirm
                             onCancel:(HQITPermissionActionBlock)onCancel {
    [self showBodyKey:@"b2"
          defaultBody:[self fixedCameraBody]
               inView:hostView
            onConfirm:onConfirm
             onCancel:onCancel];
}

+ (void)showLocationSettingsGuideInView:(UIView *)hostView
                              onConfirm:(HQITPermissionActionBlock)onConfirm
                               onCancel:(HQITPermissionActionBlock)onCancel {
    [self showBodyKey:@"b3"
          defaultBody:[self fixedLocationBody]
               inView:hostView
            onConfirm:onConfirm
             onCancel:onCancel];
}

+ (void)showContactsSettingsGuideInView:(UIView *)hostView
                              onConfirm:(HQITPermissionActionBlock)onConfirm
                               onCancel:(HQITPermissionActionBlock)onCancel {
    [self showBodyKey:@"b4"
          defaultBody:[self fixedContactsBody]
               inView:hostView
            onConfirm:onConfirm
             onCancel:onCancel];
}

+ (void)openSystemSettings {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (url && [UIApplication.sharedApplication canOpenURL:url]) {
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
    }
}

@end
