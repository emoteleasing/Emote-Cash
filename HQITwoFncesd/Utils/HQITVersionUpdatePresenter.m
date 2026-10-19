

#import "HQITVersionUpdatePresenter.h"
#import "HQITDialogs.h"
#import "HQITNetworkClient.h"
#import "HQITNetworkResponse.h"
#import "HQITAppShell.h"

static NSInteger const kHQITForceUpdateBizCode = 2009006;

@interface HQITVersionUpdatePresenter ()
@property (nonatomic, assign, readwrite) BOOL isForceUpdateShowing;
@property (nonatomic, assign) BOOL isFetchingForceVersion;
@property (nonatomic, weak, nullable) HQITBaseDialog *showingDialog;
@end

@implementation HQITVersionUpdatePresenter

+ (instancetype)shared {
    static HQITVersionUpdatePresenter *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HQITVersionUpdatePresenter alloc] init];
    });
    return instance;
}

- (UIView *)resolveHostView:(UIView *)hostView {
    if (hostView) return hostView;
    UIWindow *window = [HQITAppShell shared].window;
    if (window) return window;
    return UIApplication.sharedApplication.windows.firstObject;
}

- (void)openUpdateURL:(NSString *)updateURL {
    if (updateURL.length == 0) return;
    NSURL *url = [NSURL URLWithString:updateURL];
    if (!url) return;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)showWithVersion:(NSString *)version
            forceUpdate:(BOOL)forceUpdate
              updateURL:(NSString *)updateURL
                 inView:(UIView *)hostView
             onContinue:(HQITVersionContinueBlock)onContinue {
    UIView *host = [self resolveHostView:hostView];
    if (!host) {
        if (!forceUpdate && onContinue) onContinue();
        return;
    }

    if (self.isForceUpdateShowing && !forceUpdate) {
        if (onContinue) onContinue();
        return;
    }
    if (forceUpdate && self.isForceUpdateShowing) {
        return;
    }

    if (forceUpdate) {
        self.isForceUpdateShowing = YES;
    }

    __weak typeof(self) weakSelf = self;
    __block NSString *urlCopy = [updateURL copy] ?: @"";
    HQITBaseDialog *dialog = [HQITDialogs showVersionUpgradeWithVersion:version
                                                            forceUpdate:forceUpdate
                                                              updateURL:urlCopy
                                                                 inView:host
                                                              onUpgrade:^{
        [weakSelf openUpdateURL:urlCopy];
        if (forceUpdate) {
            return;
        }
        if (onContinue) onContinue();
    } onCancel:^{
        if (onContinue) onContinue();
    }];
    self.showingDialog = dialog;
    if (forceUpdate) {
        __weak HQITBaseDialog *weakDialog = dialog;
        dialog.onDismiss = ^{
            if (weakSelf.showingDialog == weakDialog) {
                weakSelf.showingDialog = nil;
                weakSelf.isForceUpdateShowing = NO;
            }
        };
    }
}

- (void)handleForceUpdateBusinessError {
    if (self.isForceUpdateShowing || self.isFetchingForceVersion) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isForceUpdateShowing || self.isFetchingForceVersion) return;
        self.isFetchingForceVersion = YES;

        __weak typeof(self) weakSelf = self;
        [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/app/versionV2"
                                             signedData:@{}
                                           unsignedData:nil
                                            showLoading:@NO
                                         showErrorToast:@NO
                                                success:^(HQITNetworkResponse *response) {
            __strong typeof(weakSelf) self = weakSelf;
            self.isFetchingForceVersion = NO;
            NSString *version = nil;
            NSString *url = nil;
            [self parseVersionPayload:response.data version:&version updateURL:&url];
            [self showWithVersion:version
                      forceUpdate:YES
                        updateURL:url
                           inView:nil
                       onContinue:nil];
        } failure:^(NSError *error, NSString *message) {
            __strong typeof(weakSelf) self = weakSelf;
            self.isFetchingForceVersion = NO;
            if (error.code == kHQITForceUpdateBizCode) {
                id data = error.userInfo[@"HQITResponseData"];
                NSString *version = nil;
                NSString *url = nil;
                [self parseVersionPayload:data version:&version updateURL:&url];
                [self showWithVersion:version
                          forceUpdate:YES
                            updateURL:url
                               inView:nil
                           onContinue:nil];
                return;
            }
            [self showWithVersion:nil
                      forceUpdate:YES
                        updateURL:nil
                           inView:nil
                       onContinue:nil];
        }];
    });
}

- (void)parseVersionPayload:(id)raw version:(NSString * _Nullable * _Nonnull)outVersion updateURL:(NSString * _Nullable * _Nonnull)outURL {
    *outVersion = nil;
    *outURL = nil;
    NSDictionary *data = [raw isKindOfClass:[NSDictionary class]] ? raw : nil;
    if (!data) return;

    id ver = data[@"latestVersion"] ?: data[@"latest_version"] ?: data[@"huge"] ?: data[@"goal"];
    if ([ver isKindOfClass:[NSString class]] && [(NSString *)ver length] > 0) {
        *outVersion = ver;
    } else if ([ver isKindOfClass:[NSNumber class]]) {
        *outVersion = [(NSNumber *)ver stringValue];
    }

    id url = data[@"latestVersionUrl"] ?: data[@"latest_version_url"] ?: data[@"downloadUrl"]
             ?: data[@"url"] ?: data[@"updateUrl"] ?: data[@"appStoreUrl"];
    if ([url isKindOfClass:[NSString class]] && [(NSString *)url length] > 0) {
        *outURL = url;
    }
}

@end
