#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, KRAccessory) { KRAccessoryNone, KRAccessoryCheck, KRAccessoryPlus, KRAccessoryGo };

/* One card on the linen backdrop: optional picture or icon tile, a title, a second line and a round glossy accessory. */
@interface KRCardCell : UITableViewCell
@property (nonatomic, copy) NSString *title, *subtitle;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic) int iconKind;                  /* KRTabIcon kind drawn on a dark tile when there is no image, -1 for none */
@property (nonatomic) KRAccessory badge;
- (void)reloadCard;
@end

#define KR_CARD_H 64

/* small embossed caption above a group of cards */
UIView *KRSectionHeader(NSString *text, CGFloat width);
