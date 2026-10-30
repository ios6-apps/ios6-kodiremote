#import <UIKit/UIKit.h>

/* Drawing helpers for the dark glass, steel-blue iOS 6 look: split-gloss bars, beveled glass buttons, linen, embossed text. Everything is drawn in code, no image assets. */

UIColor *KRRGB(int r, int g, int b);
UIFont *KRFont(NSString *name, CGFloat size);       /* falls back to the bold system font when the face is missing */

#define KR_ACCENT KRRGB(52, 152, 255)
#define KR_ACCENT_HI KRRGB(132, 206, 255)
#define KR_TEXT KRRGB(240, 244, 250)
#define KR_DIM KRRGB(152, 164, 184)
#define KR_LINE KRRGB(44, 58, 82)

UIImage *KRBackdropImage(void);
UIImage *KRTabIcon(int kind);   /* 0 remote, 1 add-ons, 2 servers */
void KRGlossRoundRect(CGContextRef c, CGRect r, CGFloat radius, UIColor *top, UIColor *bottom, UIColor *stroke);

void KRFillGradient(CGContextRef c, CGRect r, UIColor *top, UIColor *bottom);
void KRFillGradient4(CGContextRef c, CGRect r, const CGFloat *stops);   /* four (location, r, g, b) stops, for metal */
void KRRoundRectPath(CGContextRef c, CGRect r, CGFloat radius);
void KRGlow(CGContextRef c, CGPoint p, CGFloat radius, CGFloat alpha);  /* soft blue light */
void KRGlassFill(CGContextRef c, CGRect r, UIColor *topLight, UIColor *topDark, UIColor *bottomDark, UIColor *bottomLight);   /* split-gloss gradient */
void KRPanel(CGContextRef c, CGRect r, CGFloat radius, BOOL lit);        /* dark card with a blue-grey edge */
void KRDrawText(NSString *s, CGRect r, UIFont *font, UIColor *color, UIColor *shadow, CGFloat shadowDY, NSTextAlignment align);
