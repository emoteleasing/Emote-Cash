

#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITDocumentCameraCompletion)(UIImage * _Nullable image);

@interface HQITKYCDocumentCameraViewController : HQITBaseViewController

- (instancetype)initWithCompletion:(HQITDocumentCameraCompletion)completion;

@end

NS_ASSUME_NONNULL_END
