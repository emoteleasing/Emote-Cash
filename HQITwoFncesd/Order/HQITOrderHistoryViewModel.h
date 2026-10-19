

#import <Foundation/Foundation.h>
#import "HQITOrderHistoryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface HQITOrderHistoryViewModel : NSObject

@property (nonatomic, assign) HQITOrderHistoryTab selectedTab;
@property (nonatomic, copy, readonly) NSArray<HQITOrderHistoryItem *> *currentItems;
@property (nonatomic, assign, readonly) BOOL isLoading;
@property (nonatomic, assign, readonly) BOOL hasLoadedOnce;

@property (nonatomic, copy, nullable) void (^onUpdated)(void);

- (void)reloadCurrentSection;
- (void)reloadAllSections;
- (void)selectTab:(HQITOrderHistoryTab)tab;
- (void)selectTab:(HQITOrderHistoryTab)tab reload:(BOOL)reload;
- (void)selectOrderStatus:(NSInteger)orderStatus;

+ (NSInteger)orderStatusForTab:(HQITOrderHistoryTab)tab;
+ (HQITOrderHistoryTab)tabForOrderStatus:(NSInteger)orderStatus;
+ (NSArray<NSString *> *)tabTitles;

@end

NS_ASSUME_NONNULL_END
