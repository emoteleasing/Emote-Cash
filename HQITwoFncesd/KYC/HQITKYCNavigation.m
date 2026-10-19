

#import "HQITKYCNavigation.h"
#import "HQITKYCModels.h"
#import "HQITKYCFormViewController.h"
#import "HQITKYCPaymentViewController.h"
#import "HQITKYCEmergencyViewController.h"
#import "HQITKYCLivenessViewController.h"
#import "HQITKYCDocumentViewController.h"
#import "HQITNetworkClient.h"
#import "HQITHUDHelper.h"
#import "HQITAppShell.h"
#import "HQITDialogs.h"
#import "HQITCategoryText.h"
#import "HQITHomeSessionState.h"

NSNotificationName const HQITKYCCompletedRefreshHomeNotification = @"HQITKYCCompletedRefreshHomeNotification";

static HQITKYCEntry sCurrentEntry = HQITKYCEntryHome;

@implementation HQITKYCNavigation

+ (NSArray<HQITKYCStepInfo *> *)parseSteps:(id)raw {
    NSArray *list = nil;
    if ([raw isKindOfClass:[NSDictionary class]]) {
        id v = raw[@"kycList"] ?: raw[@"kycList"] ?: raw[@"exact"];
        if ([v isKindOfClass:[NSArray class]]) list = v;
    } else if ([raw isKindOfClass:[NSArray class]]) {
        list = raw;
    }
    if (![list isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray<HQITKYCStepInfo *> *steps = [NSMutableArray array];
    for (id row in list) {
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = (NSDictionary *)row;
        HQITKYCStepInfo *s = [[HQITKYCStepInfo alloc] init];
        id kid = d[@"kycId"] ?: d[@"kycId"] ?: d[@"kycId"] ?: d[@"kyc_id"];
        NSString *kidStr = kid ? [[NSString stringWithFormat:@"%@", kid] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
        if ([kidStr isEqualToString:@"(null)"]) kidStr = @"";
        s.kycId = kidStr;
        s.kycSort = [d[@"kycSort"] ?: d[@"kycSort"] ?: d[@"kyc_sort"] ?: @0 integerValue];
        s.kycStatus = [d[@"kycStatus"] ?: d[@"kycStatus"] ?: d[@"kyc_status"] ?: @0 integerValue];
        id typ = d[@"kycType"] ?: d[@"kycType"] ?: d[@"kyc_type"];
        s.kycType = typ ? [NSString stringWithFormat:@"%@", typ] : @"";
        if (s.kycId.length == 0) continue;
        [steps addObject:s];
    }
    [steps sortUsingComparator:^NSComparisonResult(HQITKYCStepInfo *a, HQITKYCStepInfo *b) {
        if (a.kycSort != b.kycSort) return a.kycSort < b.kycSort ? NSOrderedAscending : NSOrderedDescending;
        return [a.kycId caseInsensitiveCompare:b.kycId];
    }];
    return steps;
}

+ (NSArray<HQITKYCStepInfo *> *)unfinishedIn:(NSArray<HQITKYCStepInfo *> *)steps {
    NSMutableArray *out = [NSMutableArray array];
    for (HQITKYCStepInfo *s in steps) {
        if (s.kycStatus != 1) [out addObject:s];
    }
    return out;
}

+ (BOOL)isLastUnfinishedStep:(NSString *)kycId inList:(NSArray *)steps {
    NSArray *unfinished = [self unfinishedIn:(NSArray<HQITKYCStepInfo *> *)steps];
    if (unfinished.count == 0) return NO;
    HQITKYCStepInfo *last = unfinished.lastObject;
    return [last.kycId caseInsensitiveCompare:kycId] == NSOrderedSame;
}

+ (NSString *)pageTitleForKycId:(NSString *)kycId {
    NSString *idLower = (kycId ?: @"").lowercaseString;
    if ([idLower isEqualToString:@"personal"]) {
        return @"Personal Information";
    }
    if ([idLower containsString:@"work"]) return @"Work Information";
    if ([idLower containsString:@"credit"] || [idLower containsString:@"survey"] || [idLower containsString:@"questionnaire"]) {
        return @"Credit Standing";
    }
    if ([idLower containsString:@"urgent"] || [idLower containsString:@"contact"] || [idLower containsString:@"emergency"]) {
        return [HQITCategoryText textForKey:@"m66" defaultText:@"Emergency Contact"];
    }
    if ([idLower containsString:@"liveness"] || [idLower containsString:@"face"]) {
        return @"Face identification";
    }
    if ([idLower containsString:@"identity"] || [idLower containsString:@"aadhaar"]) return @"Aadhaar Verification";
    if ([idLower containsString:@"pan"] || [idLower containsString:@"tax"]) return @"PAN";
    if ([idLower containsString:@"pay"] || [idLower containsString:@"account"]) return @"Bank Account";
    return kycId.length ? kycId : @"KYC";
}

+ (nullable UIViewController *)viewControllerForStep:(HQITKYCStepInfo *)step
                                          allSteps:(NSArray<HQITKYCStepInfo *> *)allSteps {
    NSString *idLower = step.kycId.lowercaseString;
    BOOL last = [self isLastUnfinishedStep:step.kycId inList:allSteps];
    NSString *title = [self pageTitleForKycId:step.kycId];

    if ([idLower containsString:@"liveness"] || [idLower containsString:@"face"]) {
        return [[HQITKYCLivenessViewController alloc] initWithKycId:step.kycId
                                                          pageTitle:title
                                                   isLastUnfinished:last];
    }
    if ([idLower containsString:@"identity"] || [idLower containsString:@"aadhaar"]) {
        return [[HQITKYCDocumentViewController alloc] initWithKycId:step.kycId
                                                          pageTitle:title
                                                               kind:HQITKYCDocumentKindAadhaar
                                                   isLastUnfinished:last];
    }
    if ([idLower containsString:@"pan"] || [idLower containsString:@"tax"]) {
        return [[HQITKYCDocumentViewController alloc] initWithKycId:step.kycId
                                                          pageTitle:title
                                                               kind:HQITKYCDocumentKindPAN
                                                   isLastUnfinished:last];
    }

    if ([idLower containsString:@"pay"] || [idLower containsString:@"account"]) {
        return [[HQITKYCPaymentViewController alloc] initWithKycId:step.kycId
                                                         pageTitle:title
                                                  isLastUnfinished:last];
    }
    if ([idLower containsString:@"urgent"] || [idLower containsString:@"emergency"]
        || [idLower isEqualToString:@"urgent_contact"]) {
        return [[HQITKYCEmergencyViewController alloc] initWithKycId:step.kycId
                                                           pageTitle:title
                                                    isLastUnfinished:last];
    }

    BOOL isForm = [idLower isEqualToString:@"personal"]
        || [idLower containsString:@"work"]
        || [idLower containsString:@"credit"]
        || [idLower containsString:@"survey"]
        || [idLower containsString:@"questionnaire"];
    if (isForm) {
        return [[HQITKYCFormViewController alloc] initWithKycId:step.kycId
                                                      pageTitle:title
                                               isLastUnfinished:last];
    }
    return nil;
}

+ (void)startFrom:(UIViewController *)from entry:(HQITKYCEntry)entry {
    if (!from) return;
    sCurrentEntry = entry;
    [HQITHUDHelper showLoading];
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/kyc/status"
                                         signedData:@{}
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        [HQITHUDHelper hideLoading];
        NSArray *steps = [self parseSteps:response.data];
        NSArray *unfinished = [self unfinishedIn:steps];
        if (unfinished.count == 0) {
            [HQITHUDHelper showToast:@"KYC already completed"];
            [HQITHomeSessionState markPendingAutoOrderAfterKYC];
            [self finishFlowFrom:from];
            return;
        }
        HQITKYCStepInfo *first = unfinished.firstObject;
        UIViewController *vc = [self viewControllerForStep:first allSteps:steps];
        if (!vc) {
            [HQITHUDHelper showToast:[NSString stringWithFormat:@"Unsupported KYC step: %@", first.kycId]];
            return;
        }
        UINavigationController *nav = from.navigationController;
        if (!nav) {
            [HQITHUDHelper showToast:@"Navigation unavailable"];
            return;
        }
        [nav pushViewController:vc animated:YES];
    } failure:^(NSError *error, NSString *message) {
        [HQITHUDHelper hideLoading];
    }];
}

+ (void)advanceFrom:(UIViewController *)from {
    if (!from) return;
    [HQITHUDHelper showLoading];
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/kyc/status"
                                         signedData:@{}
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@YES
                                            success:^(HQITNetworkResponse *response) {
        [HQITHUDHelper hideLoading];
        NSArray *steps = [self parseSteps:response.data];
        NSArray *unfinished = [self unfinishedIn:steps];
        UINavigationController *nav = from.navigationController;
        if (unfinished.count == 0) {
            [HQITHomeSessionState markPendingAutoOrderAfterKYC];
            [self finishFlowFrom:from];
            return;
        }
        HQITKYCStepInfo *next = unfinished.firstObject;
        UIViewController *vc = [self viewControllerForStep:next allSteps:steps];
        if (!vc) {
            [HQITHUDHelper showToast:[NSString stringWithFormat:@"Unsupported KYC step: %@", next.kycId]];
            return;
        }
        if (!nav) return;
        NSMutableArray *stack = [nav.viewControllers mutableCopy];
        if (stack.count > 0) {
            [stack removeLastObject];
        }
        [stack addObject:vc];
        [nav setViewControllers:stack animated:YES];
    } failure:^(NSError *error, NSString *message) {
        [HQITHUDHelper hideLoading];
    }];
}

+ (void)finishFlowFrom:(UIViewController *)from {
    UINavigationController *nav = from.navigationController;
    UITabBarController *tab = from.tabBarController;
    if (sCurrentEntry == HQITKYCEntryEMI) {
        [nav popToRootViewControllerAnimated:NO];
        tab.selectedIndex = 0;
    } else {
        [nav popToRootViewControllerAnimated:YES];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:HQITKYCCompletedRefreshHomeNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
}

+ (void)confirmExitFrom:(UIViewController *)from {
    if (sCurrentEntry == HQITKYCEntryEMI) {
        [from.navigationController popViewControllerAnimated:YES];
        return;
    }
    // Mid-flow exit: return home + refresh only. Do not treat as KYC completed
    // (that would incorrectly arm pending auto-order).
    UINavigationController *nav = from.navigationController;
    [nav popToRootViewControllerAnimated:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
}

@end
