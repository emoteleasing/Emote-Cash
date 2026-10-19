

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HQITKYCEntry) {
    HQITKYCEntryHome = 0,
    HQITKYCEntryEMI = 1,
};

FOUNDATION_EXPORT NSNotificationName const HQITKYCCompletedRefreshHomeNotification;

@interface HQITKYCNavigation : NSObject

+ (void)startFrom:(UIViewController *)from entry:(HQITKYCEntry)entry;
+ (void)advanceFrom:(UIViewController *)from;
+ (void)confirmExitFrom:(UIViewController *)from;
+ (void)finishFlowFrom:(UIViewController *)from;

+ (BOOL)isLastUnfinishedStep:(NSString *)kycId inList:(NSArray *)steps;
+ (nullable NSString *)pageTitleForKycId:(NSString *)kycId;

@end

NS_ASSUME_NONNULL_END
