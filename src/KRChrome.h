#import <UIKit/UIKit.h>

/* Custom-drawn chrome (nav bar, back button, segmented control, tab bar) and a tiny navigation stack.
   UIKit's own bars are not used, so the app looks the same on every iOS version. */

@protocol KRScreen <NSObject>
@optional
- (NSString *)krTitle;
- (UIView *)krTitleView;    /* replaces the title (e.g. the Video / Music / Apps control) */
- (UIView *)krRightView;
- (void)krWillShow;         /* the screen is about to become visible again */
@end

/* glossy segmented control for the nav bar */
@interface KRSegmented : UIControl
@property (nonatomic) NSInteger selectedIndex;
- (id)initWithItems:(NSArray *)items;
- (void)setEnabled:(BOOL)on forIndex:(NSInteger)i;
@end

@interface KRRootController : UIViewController
+ (KRRootController *)shared;
/* tabs: dictionaries with @"title", @"icon" (NSNumber, see KRTabIcon) and @"vc" (root view controller of that tab) */
- (id)initWithTabs:(NSArray *)tabs;
- (void)push:(UIViewController *)vc;
- (void)pop;
- (void)selectTab:(NSInteger)tab;
- (void)refreshBar;         /* call when a screen's title / right view changed */
@end
