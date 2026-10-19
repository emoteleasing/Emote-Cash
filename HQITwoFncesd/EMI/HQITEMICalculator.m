

#import "HQITEMICalculator.h"

@implementation HQITEMICalculator

+ (NSInteger)minAmount { return 1; }
+ (NSInteger)maxAmount { return 10000000; }
+ (NSInteger)minDuration { return 1; }
+ (NSInteger)maxDuration { return 25; }
+ (NSInteger)minInterestRate { return 0; }
+ (NSInteger)maxInterestRate { return 22; }

+ (NSInteger)defaultAmount { return 50000; }
+ (NSInteger)defaultDuration { return 5; }
+ (NSInteger)defaultInterestRate { return 3; }

+ (NSString *)validateInput:(HQITEMIInputModel *)input {
    if (input.amount < [self minAmount] || input.amount > [self maxAmount]) {
        return [NSString stringWithFormat:@"Range: 0 ~ %@", [self formatIntegerIndian:[self maxAmount]]];
    }
    if (input.durationYears < [self minDuration] || input.durationYears > [self maxDuration]) {
        return [NSString stringWithFormat:@"Range: 0 ~ %ld", (long)[self maxDuration]];
    }
    if (input.interestRate < [self minInterestRate] || input.interestRate > [self maxInterestRate]) {
        return [NSString stringWithFormat:@"Range: 0 ~ %ld", (long)[self maxInterestRate]];
    }
    return nil;
}

+ (HQITEMIResultModel *)calculateWithInput:(HQITEMIInputModel *)input {
    double amount = (double)input.amount;
    NSInteger years = input.durationYears;
    double annualRate = (double)input.interestRate;
    NSInteger months = years * 12;

    double monthlyPayment = 0;
    if (months <= 0) {
        monthlyPayment = 0;
    } else if (annualRate <= 0) {
        monthlyPayment = amount / (double)months;
    } else {
        double r = annualRate / 12.0 / 100.0;
        double powTerm = pow(1.0 + r, (double)months);
        monthlyPayment = amount * r * powTerm / (powTerm - 1.0);
    }

    double totalRepayment = monthlyPayment * (double)months;
    double totalInterest = totalRepayment - amount;

    HQITEMIResultModel *result = [[HQITEMIResultModel alloc] init];
    result.monthlyPayment = monthlyPayment;
    result.totalRepayment = totalRepayment;
    result.totalInterest = MAX(totalInterest, 0);
    return result;
}

+ (NSNumberFormatter *)integerFormatter {
    static NSNumberFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSNumberFormatter alloc] init];
        fmt.numberStyle = NSNumberFormatterDecimalStyle;
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_IN"];
        fmt.maximumFractionDigits = 0;
        fmt.minimumFractionDigits = 0;
        fmt.usesGroupingSeparator = YES;
    });
    return fmt;
}

+ (NSNumberFormatter *)currencyFormatter {
    static NSNumberFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSNumberFormatter alloc] init];
        fmt.numberStyle = NSNumberFormatterDecimalStyle;
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_IN"];
        fmt.maximumFractionDigits = 2;
        fmt.minimumFractionDigits = 2;
        fmt.usesGroupingSeparator = YES;
    });
    return fmt;
}

+ (NSString *)formatIntegerIndian:(NSInteger)value {
    return [[self integerFormatter] stringFromNumber:@(value)] ?: [NSString stringWithFormat:@"%ld", (long)value];
}

+ (NSString *)formatCurrency:(double)value {
    NSString *num = [[self currencyFormatter] stringFromNumber:@(value)] ?: [NSString stringWithFormat:@"%.2f", value];
    return [NSString stringWithFormat:@"₹ %@", num];
}

@end
