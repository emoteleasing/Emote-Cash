
#import "HQITBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HQITKYCDocumentKind) {
    HQITKYCDocumentKindAadhaar = 0, // front + back + number
    HQITKYCDocumentKindPAN = 1,     // front + number (readonly after OCR)
};

@interface HQITKYCDocumentViewController : HQITBaseViewController

- (instancetype)initWithKycId:(NSString *)kycId
                    pageTitle:(NSString *)pageTitle
                         kind:(HQITKYCDocumentKind)kind
             isLastUnfinished:(BOOL)isLastUnfinished;

@end

NS_ASSUME_NONNULL_END
