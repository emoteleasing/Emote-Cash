

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITEMIInputModel : NSObject
@property (nonatomic, assign) NSInteger amount;
@property (nonatomic, assign) NSInteger durationYears;
@property (nonatomic, assign) NSInteger interestRate;
@end

@interface HQITEMIResultModel : NSObject
@property (nonatomic, assign) double monthlyPayment;
@property (nonatomic, assign) double totalRepayment;
@property (nonatomic, assign) double totalInterest;
@end

NS_ASSUME_NONNULL_END
