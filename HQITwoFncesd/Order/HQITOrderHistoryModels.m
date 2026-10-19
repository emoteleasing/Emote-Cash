

#import "HQITOrderHistoryModels.h"

@implementation HQITOrderHistoryItem
@end

@implementation HQITOrderStatusStyle

+ (UIColor *)rgb:(NSInteger)r g:(NSInteger)g b:(NSInteger)b {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
}

+ (UIColor *)rgba:(NSInteger)r g:(NSInteger)g b:(NSInteger)b a:(CGFloat)a {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

+ (void)applyStyleForStatusCode:(NSInteger)code
                          title:(NSString **)outTitle
                      textColor:(UIColor **)outText
                        bgColor:(UIColor **)outBg {
    switch (code) {
        case 60: // Repayment Due
            *outTitle = @"Repayment Due";
            *outText = [self rgb:0xF6 g:0x71 b:0x15];
            *outBg = [self rgb:0xFF g:0xF3 b:0xEE];
            break;
        case 61: // Overdue
            *outTitle = @"Overdue";
            *outText = [self rgb:0xD3 g:0x2F b:0x2F];
            *outBg = [self rgb:0xFF g:0xEB b:0xEE];
            break;
        case 36: // Change bank account
            *outTitle = @"Change bank account";
            *outText = [self rgb:0xF6 g:0x71 b:0x15];
            *outBg = [self rgb:0xFF g:0xF3 b:0xEE];
            break;
        case 10: // Unfinished Application
            *outTitle = @"Unfinished Application";
            *outText = [self rgb:0xFF g:0x98 b:0x00];
            *outBg = [self rgb:0xFF g:0xF8 b:0xE1];
            break;
        case 32: // Pending (To be withdrawn)
            *outTitle = @"Pending";
            *outText = [self rgb:0x5F g:0x6F b:0x88];
            *outBg = [self rgb:0xF5 g:0xF5 b:0xF5];
            break;
        case 50: // Loan processing
            *outTitle = @"Loan processing";
            *outText = [self rgb:0x19 g:0x76 b:0xD2];
            *outBg = [self rgb:0xE3 g:0xF2 b:0xFD];
            break;
        case 30: // Under review
            *outTitle = @"Under review";
            *outText = [self rgb:0x7B g:0x1F b:0xA2];
            *outBg = [self rgb:0xF3 g:0xE5 b:0xF5];
            break;
        case 31: // Reject
            *outTitle = @"Reject";
            *outText = [self rgb:0xD3 g:0x2F b:0x2F];
            *outBg = [self rgb:0xFF g:0xEB b:0xEE];
            break;
        case 70: // Pay off
            *outTitle = @"Pay off";
            *outText = [self rgb:0x33 g:0xB8 b:0x0F];
            *outBg = [self rgb:0xE8 g:0xF5 b:0xE9];
            break;
        case 99: // Cancel
            *outTitle = @"Cancel";
            *outText = [self rgb:0x5F g:0x6F b:0x88];
            *outBg = [self rgb:0xF5 g:0xF5 b:0xF5];
            break;
        default:
            *outTitle = [NSString stringWithFormat:@"Status %ld", (long)code];
            *outText = [self rgb:0x5F g:0x6F b:0x88];
            *outBg = [self rgb:0xF5 g:0xF5 b:0xF5];
            break;
    }
}

+ (void)dateLabelsForStatusCode:(NSInteger)code
                      leftLabel:(NSString **)outLeft
                     rightLabel:(NSString **)outRight {
    if (code == 60 || code == 61) {
        *outLeft = @"Payment date";
        *outRight = @"Due Date";
        return;
    }
    if (code == 70) {
        *outLeft = @"Payment date";
        *outRight = @"Repayment date";
        return;
    }
    *outLeft = @"Date of application";
    *outRight = @"Due Date";
}

@end
