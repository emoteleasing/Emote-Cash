
#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITKYCIFSCPickedBlock)(NSString *ifscCode);

@interface HQITKYCIFSCViewController : HQITBaseViewController

- (instancetype)initWithOnPicked:(HQITKYCIFSCPickedBlock)onPicked;

@end

NS_ASSUME_NONNULL_END
