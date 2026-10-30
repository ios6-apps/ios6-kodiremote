#import "KRStyle.h"

UIColor *KRRGB(int r, int g, int b) { return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1]; }
UIFont *KRFont(NSString *name, CGFloat size) { return [UIFont fontWithName:name size:size] ?: [UIFont boldSystemFontOfSize:size]; }

static void rgba(UIColor *c, CGFloat *out) {
    if (![c getRed:out green:out + 1 blue:out + 2 alpha:out + 3]) {
        CGFloat w, a;
        [c getWhite:&w alpha:&a];
        out[0] = out[1] = out[2] = w; out[3] = a;
    }
}

void KRFillGradient(CGContextRef c, CGRect r, UIColor *top, UIColor *bottom) {
    CGFloat comps[8];
    rgba(top, comps); rgba(bottom, comps + 4);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextSaveGState(c);
    CGContextClipToRect(c, r);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, CGRectGetMinY(r)), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGContextRestoreGState(c);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
}

void KRRoundRectPath(CGContextRef c, CGRect r, CGFloat rad) {
    CGFloat x0 = CGRectGetMinX(r), x1 = CGRectGetMaxX(r), y0 = CGRectGetMinY(r), y1 = CGRectGetMaxY(r);
    CGContextMoveToPoint(c, x0 + rad, y0);
    CGContextAddArcToPoint(c, x1, y0, x1, y1, rad);
    CGContextAddArcToPoint(c, x1, y1, x0, y1, rad);
    CGContextAddArcToPoint(c, x0, y1, x0, y0, rad);
    CGContextAddArcToPoint(c, x0, y0, x1, y0, rad);
    CGContextClosePath(c);
}

void KRDrawText(NSString *s, CGRect r, UIFont *font, UIColor *color, UIColor *shadow, CGFloat dy, NSTextAlignment align) {
    if (!s.length) return;
    /* a one-line box truncates instead of wrapping */
    NSLineBreakMode mode = r.size.height < font.lineHeight * 1.5 ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping;
    if (shadow) {
        [shadow set];
        [s drawInRect:CGRectOffset(r, 0, dy) withFont:font lineBreakMode:mode alignment:align];
    }
    [color set];
    [s drawInRect:r withFont:font lineBreakMode:mode alignment:align];
}


void KRFillGradient4(CGContextRef c, CGRect r, const CGFloat *stops /* 4 x (loc, r, g, b) in 0..1 */) {
    CGFloat comps[16], locs[4];
    for (int i = 0; i < 4; i++) { locs[i] = stops[i * 4]; comps[i * 4] = stops[i * 4 + 1]; comps[i * 4 + 1] = stops[i * 4 + 2]; comps[i * 4 + 2] = stops[i * 4 + 3]; comps[i * 4 + 3] = 1; }
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, locs, 4);
    CGContextSaveGState(c);
    CGContextClipToRect(c, r);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, CGRectGetMinY(r)), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGContextRestoreGState(c);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
}

void KRGlow(CGContextRef c, CGPoint p, CGFloat radius, CGFloat alpha) {
    CGFloat gc[8] = {0.2, 0.6, 1.0, alpha,  0.2, 0.6, 1.0, 0.0};
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, gc, NULL, 2);
    CGContextDrawRadialGradient(c, g, p, 0, p, radius, 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
}

void KRGlassFill(CGContextRef c, CGRect r, UIColor *t0, UIColor *t1, UIColor *b0, UIColor *b1) {
    /* the classic split: the upper half is lighter, with a hard edge in the middle */
    CGFloat h = r.size.height / 2;
    KRFillGradient(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, h), t0, t1);
    KRFillGradient(c, CGRectMake(r.origin.x, r.origin.y + h, r.size.width, r.size.height - h), b0, b1);
    /* wet-look gloss: a bright sheen fading down the upper half, a crisp seam, and light bounced up from below */
    KRFillGradient(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, h), [UIColor colorWithWhite:1 alpha:0.52], [UIColor colorWithWhite:1 alpha:0.12]);
    [[UIColor colorWithWhite:1 alpha:0.2] set]; CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y + h, r.size.width, 1));
    [[UIColor colorWithWhite:0 alpha:0.18] set]; CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y + h + 1, r.size.width, 1));
    CGFloat bh = MIN(h * 0.7, 10);
    KRFillGradient(c, CGRectMake(r.origin.x, CGRectGetMaxY(r) - bh, r.size.width, bh), [UIColor colorWithWhite:1 alpha:0], [UIColor colorWithWhite:1 alpha:0.26]);
}

void KRPanel(CGContextRef c, CGRect r, CGFloat rad, BOOL lit) {
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1.5), 3, [UIColor colorWithWhite:0 alpha:0.85].CGColor);
    KRRoundRectPath(c, r, rad); [KRRGB(10, 12, 16) setFill]; CGContextFillPath(c);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    KRRoundRectPath(c, r, rad); CGContextClip(c);
    if (lit) KRGlassFill(c, r, KRRGB(92, 138, 214), KRRGB(60, 104, 184), KRRGB(36, 76, 158), KRRGB(50, 96, 176));
    else KRGlassFill(c, r, KRRGB(66, 74, 90), KRRGB(48, 54, 68), KRRGB(34, 38, 48), KRRGB(40, 45, 56));
    [[UIColor colorWithWhite:1 alpha:0.5] set]; CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, 1));
    CGContextRestoreGState(c);
    KRRoundRectPath(c, CGRectInset(r, 0.5, 0.5), rad - 0.5);
    [KRRGB(6, 8, 12) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
}

UIImage *KRBackdropImage(void) {   /* dark blue-grey linen */
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(64, 64), YES, 0);
        CGContextRef c = UIGraphicsGetCurrentContext();
        [KRRGB(30, 34, 42) setFill]; CGContextFillRect(c, CGRectMake(0, 0, 64, 64));
        for (int y = 0; y < 64; y += 2) {   /* warp and weft */
            [[UIColor colorWithWhite:(y % 4 ? 0 : 1) alpha:0.07] set]; CGContextFillRect(c, CGRectMake(0, y, 64, 1));
        }
        for (int x = 0; x < 64; x += 2) {
            [[UIColor colorWithWhite:(x % 4 ? 0 : 1) alpha:0.06] set]; CGContextFillRect(c, CGRectMake(x, 0, 1, 64));
        }
        srand(5);
        for (int i = 0; i < 160; i++) {
            [[UIColor colorWithWhite:rand() % 2 alpha:0.05] set];
            CGContextFillRect(c, CGRectMake(rand() % 64, rand() % 64, 1 + rand() % 2, 1));
        }
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

UIImage *KRTabIcon(int kind) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] set];
    CGContextSetLineWidth(c, 2);
    if (kind == 0) {            /* remote: ring with a centre button and four arrows */
        CGContextStrokeEllipseInRect(c, CGRectMake(3, 3, 24, 24));
        CGContextFillEllipseInRect(c, CGRectMake(11.5, 11.5, 7, 7));
        CGContextMoveToPoint(c, 15, 6.5); CGContextAddLineToPoint(c, 12.5, 9.5); CGContextAddLineToPoint(c, 17.5, 9.5); CGContextFillPath(c);
        CGContextMoveToPoint(c, 15, 23.5); CGContextAddLineToPoint(c, 12.5, 20.5); CGContextAddLineToPoint(c, 17.5, 20.5); CGContextFillPath(c);
        CGContextMoveToPoint(c, 6.5, 15); CGContextAddLineToPoint(c, 9.5, 12.5); CGContextAddLineToPoint(c, 9.5, 17.5); CGContextFillPath(c);
        CGContextMoveToPoint(c, 23.5, 15); CGContextAddLineToPoint(c, 20.5, 12.5); CGContextAddLineToPoint(c, 20.5, 17.5); CGContextFillPath(c);
    } else if (kind == 1) {     /* add-ons: 2x2 tiles, one of them lifted out */
        KRRoundRectPath(c, CGRectMake(4, 4, 10, 10), 2); CGContextFillPath(c);
        KRRoundRectPath(c, CGRectMake(4, 16, 10, 10), 2); CGContextFillPath(c);
        KRRoundRectPath(c, CGRectMake(16, 16, 10, 10), 2); CGContextFillPath(c);
        KRRoundRectPath(c, CGRectMake(17, 3, 10, 10), 2); CGContextStrokePath(c);
    } else {                    /* servers: a TV on its stand */
        KRRoundRectPath(c, CGRectMake(3, 5, 24, 16), 3); CGContextStrokePath(c);
        CGContextFillRect(c, CGRectMake(9, 24, 12, 2.5));
        CGContextFillRect(c, CGRectMake(13.5, 21, 3, 4));
    }
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

void KRGlossRoundRect(CGContextRef c, CGRect r, CGFloat rad, UIColor *top, UIColor *bot, UIColor *stroke) {
    CGContextSaveGState(c);
    KRRoundRectPath(c, r, rad); CGContextClip(c);
    KRFillGradient(c, r, top, bot);
    KRFillGradient(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height / 2), [UIColor colorWithWhite:1 alpha:0.30], [UIColor colorWithWhite:1 alpha:0.04]);
    CGContextRestoreGState(c);
    KRRoundRectPath(c, CGRectInset(r, 0.5, 0.5), rad);
    [stroke set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
}

