

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITCaptureCompletion)(BOOL success);

@interface HQITOrderDataCaptureCoordinator : NSObject

+ (void)startWithOrderId:(NSString *)orderId
          hostViewController:(UIViewController *)hostVC
                  completion:(HQITCaptureCompletion)completion;

@end

NS_ASSUME_NONNULL_END
