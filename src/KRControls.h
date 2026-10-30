#import <UIKit/UIKit.h>

/* Remote-control widgets. The pads fire UIControlEventValueChanged on touch down (not on release) and can repeat while held. */

typedef NS_ENUM(NSInteger, KRGlyph) {
    KRGlyphNone, KRGlyphPrev, KRGlyphRewind, KRGlyphPlayPause, KRGlyphStop, KRGlyphForward, KRGlyphNext, KRGlyphVolDown, KRGlyphVolUp, KRGlyphMute, KRGlyphKeyboard
};

void KRHaptic(void);          /* one short vibration tick */

@interface KRPad : UIControl
@property (nonatomic) BOOL repeats;
@property (nonatomic, readonly) NSInteger zone;       /* the zone that was hit */
@end

/* dark metal button with an icon or a word; blue when latched or pressed */
@interface KRButton : KRPad
@property (nonatomic) KRGlyph glyph;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *key;      /* what the remote sends: an Input.* method or an Input.ExecuteAction name */
@property (nonatomic) BOOL latched;
@end

/* round direction pad: zones 0 up, 1 down, 2 left, 3 right, 4 OK */
@interface KRDPad : KRPad
@end

/* brushed-chrome slider: ValueChanged while dragging, EditingDidEnd when the finger lifts */
@interface KRSlider : UIControl
@property (nonatomic) float value;                       /* 0...1 */
@property (nonatomic, readonly) BOOL interacting;
@end

/* the "now playing" panel: artwork, title, and a metallic position slider that seeks */
@interface KRNowPlayingView : UIView
- (void)update;
@end
