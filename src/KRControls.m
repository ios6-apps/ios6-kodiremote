#import "KRControls.h"
#import "KRStyle.h"
#import "KRClient.h"
#import <AudioToolbox/AudioToolbox.h>
#include <dlfcn.h>

/* The iPhone 5 has no Taptic Engine, only a plain vibration motor, and the public call buzzes for about 0.4 s.
   AudioServicesPlaySystemSoundWithVibration is a private entry point that takes a pattern, so one 25 ms pulse is a tick.
   It is looked up at run time; if it is missing the normal buzz is used. */
typedef void (*KRVibeFn)(UInt32 sound, id unused, NSDictionary *pattern);

void KRHaptic(void) {
    static KRVibeFn fn; static BOOL looked; static NSDictionary *tick;
    if (!looked) {
        looked = YES;
        fn = (KRVibeFn)dlsym(RTLD_DEFAULT, "AudioServicesPlaySystemSoundWithVibration");
        tick = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSArray arrayWithObjects:[NSNumber numberWithBool:YES], [NSNumber numberWithInt:25], nil], @"VibePattern",
                [NSNumber numberWithFloat:1.0f], @"Intensity", nil];
    }
    if (fn) fn(kSystemSoundID_Vibrate, nil, tick);
    else AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

@interface KRPad ()
@property (nonatomic) NSInteger zone, pressedZone;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation KRPad

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.pressedZone = -1; }
    return self;
}

- (NSInteger)zoneAtPoint:(CGPoint)p { return CGRectContainsPoint(self.bounds, p) ? 0 : -1; }
- (BOOL)zoneRepeats:(NSInteger)z { return self.repeats; }

- (void)stopTimer { [self.timer invalidate]; self.timer = nil; }

- (void)press:(NSInteger)z {
    [self stopTimer];
    if (z >= 0) KRHaptic();
    self.pressedZone = z;
    self.zone = z;
    [self setNeedsDisplay];
    if (z < 0) return;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    if ([self zoneRepeats:z]) self.timer = [NSTimer scheduledTimerWithTimeInterval:0.45 target:self selector:@selector(startRepeating) userInfo:nil repeats:NO];
}

- (void)startRepeating {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.12 target:self selector:@selector(fire) userInfo:nil repeats:YES];
}

- (void)fire { [self sendActionsForControlEvents:UIControlEventValueChanged]; }

- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    NSInteger z = [self zoneAtPoint:[t locationInView:self]];
    if (z < 0) return NO;
    [self press:z];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    NSInteger z = [self zoneAtPoint:[t locationInView:self]];
    if (z != self.pressedZone) { [self stopTimer]; self.pressedZone = z; [self setNeedsDisplay]; }   /* sliding off cancels the repeat */
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e { [self stopTimer]; self.pressedZone = -1; [self setNeedsDisplay]; }
- (void)cancelTrackingWithEvent:(UIEvent *)e { [self stopTimer]; self.pressedZone = -1; [self setNeedsDisplay]; }
- (void)removeFromSuperview { [self stopTimer]; [super removeFromSuperview]; }

@end

#pragma mark - button

static void Triangle(CGContextRef c, CGFloat x, CGFloat y, CGFloat w, CGFloat h, BOOL right) {
    CGContextMoveToPoint(c, right ? x : x + w, y);
    CGContextAddLineToPoint(c, right ? x + w : x, y + h / 2);
    CGContextAddLineToPoint(c, right ? x : x + w, y + h);
    CGContextClosePath(c);
    CGContextFillPath(c);
}

@implementation KRButton

- (void)drawGlyphIn:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat cx = CGRectGetMidX(r), cy = CGRectGetMidY(r);
    switch (self.glyph) {
        case KRGlyphPlayPause:
            Triangle(c, cx - 8, cy - 7, 9, 14, YES);
            CGContextFillRect(c, CGRectMake(cx + 3, cy - 7, 2.5, 14)); CGContextFillRect(c, CGRectMake(cx + 7.5, cy - 7, 2.5, 14));
            break;
        case KRGlyphKeyboard: {     /* a keyboard seen from above: outline, two rows of keys, a space bar */
            CGRect k = CGRectMake(cx - 12, cy - 7, 24, 14);
            CGContextSetLineWidth(c, 1.6);
            KRRoundRectPath(c, k, 2.5); CGContextStrokePath(c);
            for (int i = 0; i < 4; i++) { CGContextFillRect(c, CGRectMake(k.origin.x + 3 + i * 5.2, k.origin.y + 3, 3, 2.2)); }
            for (int i = 0; i < 3; i++) { CGContextFillRect(c, CGRectMake(k.origin.x + 5.6 + i * 5.2, k.origin.y + 6.4, 3, 2.2)); }
            CGContextFillRect(c, CGRectMake(k.origin.x + 6, k.origin.y + 9.8, 12, 2));
            break;
        }
        case KRGlyphStop: CGContextFillRect(c, CGRectMake(cx - 6, cy - 6, 12, 12)); break;
        case KRGlyphForward: Triangle(c, cx - 9, cy - 6, 9, 12, YES); Triangle(c, cx, cy - 6, 9, 12, YES); break;
        case KRGlyphRewind: Triangle(c, cx - 9, cy - 6, 9, 12, NO); Triangle(c, cx, cy - 6, 9, 12, NO); break;
        case KRGlyphNext: Triangle(c, cx - 8, cy - 6, 9, 12, YES); CGContextFillRect(c, CGRectMake(cx + 4, cy - 6, 2.5, 12)); break;
        case KRGlyphPrev: Triangle(c, cx - 1, cy - 6, 9, 12, NO); CGContextFillRect(c, CGRectMake(cx - 6.5, cy - 6, 2.5, 12)); break;
        case KRGlyphVolDown: case KRGlyphVolUp: case KRGlyphMute: {
            CGContextFillRect(c, CGRectMake(cx - 12, cy - 3, 5, 6));
            CGContextMoveToPoint(c, cx - 7, cy - 3); CGContextAddLineToPoint(c, cx - 1, cy - 8); CGContextAddLineToPoint(c, cx - 1, cy + 8); CGContextAddLineToPoint(c, cx - 7, cy + 3);
            CGContextClosePath(c); CGContextFillPath(c);
            CGContextSetLineWidth(c, 2);
            if (self.glyph == KRGlyphMute) {
                CGContextMoveToPoint(c, cx + 3, cy - 5); CGContextAddLineToPoint(c, cx + 11, cy + 5);
                CGContextMoveToPoint(c, cx + 11, cy - 5); CGContextAddLineToPoint(c, cx + 3, cy + 5);
                CGContextStrokePath(c);
            } else {
                CGContextAddArc(c, cx + 1, cy, 5, -0.9, 0.9, 0); CGContextStrokePath(c);
                if (self.glyph == KRGlyphVolUp) { CGContextAddArc(c, cx + 1, cy, 9, -0.9, 0.9, 0); CGContextStrokePath(c); }
            }
            break;
        }
        default: break;
    }
}

- (void)setLatched:(BOOL)on { if (_latched != on) { _latched = on; [self setNeedsDisplay]; } }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    BOOL down = self.pressedZone >= 0, blue = down || self.latched;
    CGRect b = CGRectInset(self.bounds, 0.5, 1);
    /* light lip underneath, like a button standing proud of the surface */
    KRRoundRectPath(c, CGRectOffset(b, 0, 1), 8); [[UIColor colorWithWhite:1 alpha:0.14] setFill]; CGContextFillPath(c);
    CGContextSaveGState(c);
    KRRoundRectPath(c, b, 8); CGContextClip(c);
    if (blue) KRGlassFill(c, b, KRRGB(132, 168, 228), KRRGB(88, 128, 202), KRRGB(52, 92, 176), KRRGB(78, 118, 196));
    else if (down) KRGlassFill(c, b, KRRGB(52, 58, 72), KRRGB(40, 45, 56), KRRGB(26, 30, 38), KRRGB(34, 38, 48));
    else KRGlassFill(c, b, KRRGB(112, 122, 144), KRRGB(72, 80, 98), KRRGB(36, 41, 52), KRRGB(50, 56, 70));
    [[UIColor colorWithWhite:1 alpha:down ? 0.1 : 0.42] set]; CGContextFillRect(c, CGRectMake(b.origin.x, b.origin.y, b.size.width, 1));
    if (down) KRFillGradient(c, CGRectMake(b.origin.x, b.origin.y, b.size.width, 7), [UIColor colorWithWhite:0 alpha:0.45], [UIColor colorWithWhite:0 alpha:0]);
    CGContextRestoreGState(c);
    KRRoundRectPath(c, b, 8);
    [blue ? KRRGB(12, 28, 64) : KRRGB(6, 8, 12) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    CGRect inner = CGRectOffset(self.bounds, 0, down ? 1 : 0);
    /* embossed: a dark copy one point above */
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, [UIColor colorWithWhite:0 alpha:0.75].CGColor);
    [UIColor.whiteColor setFill];
    [[UIColor colorWithRed:0.93 green:0.95 blue:0.98 alpha:1] setFill];
    if (self.glyph != KRGlyphNone) [self drawGlyphIn:inner];
    CGContextRestoreGState(c);
    if (self.label.length)
        KRDrawText(self.label, CGRectMake(0, inner.origin.y + (inner.size.height - 16) / 2, inner.size.width, 16), KRFont(@"HelveticaNeue-Bold", 13),
                   [UIColor whiteColor], [UIColor colorWithWhite:0 alpha:0.7], -1, NSTextAlignmentCenter);
}

@end

#pragma mark - direction pad

#define PAD_OK_R (self.bounds.size.width * 0.205)

@implementation KRDPad

- (NSInteger)zoneAtPoint:(CGPoint)p {
    CGFloat r = self.bounds.size.width / 2, dx = p.x - r, dy = p.y - r, d = sqrt(dx * dx + dy * dy);
    if (d > r) return -1;
    if (d < PAD_OK_R) return 4;
    if (fabs(dx) > fabs(dy)) return dx < 0 ? 2 : 3;
    return dy < 0 ? 0 : 1;
}
- (BOOL)zoneRepeats:(NSInteger)z { return z != 4; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = CGRectInset(self.bounds, 3, 3);
    CGFloat R = b.size.width / 2;
    CGPoint ctr = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));

    /* chrome bezel with a light lip below */
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 2), 4, [UIColor colorWithWhite:0 alpha:0.9].CGColor);
    [KRRGB(10, 12, 16) setFill]; CGContextFillEllipseInRect(c, b);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, b); CGContextClip(c);
    static const CGFloat chrome[16] = {0.0, 0.94, 0.96, 1.0,   0.4, 0.55, 0.60, 0.68,   0.55, 0.22, 0.25, 0.31,   1.0, 0.70, 0.74, 0.82};
    KRFillGradient4(c, b, chrome);
    CGContextRestoreGState(c);
    /* the glass dish inside the bezel */
    CGRect dish = CGRectInset(b, 7, 7);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, dish); CGContextClip(c);
    KRGlassFill(c, dish, KRRGB(70, 78, 96), KRRGB(40, 46, 60), KRRGB(14, 17, 24), KRRGB(24, 28, 38));
    /* curved specular lens across the top of the dish */
    {
        CGRect lens = CGRectMake(dish.origin.x + 10, dish.origin.y + 3, dish.size.width - 20, dish.size.height * 0.42);
        CGContextSaveGState(c);
        CGContextAddEllipseInRect(c, lens); CGContextClip(c);
        KRFillGradient(c, lens, [UIColor colorWithWhite:1 alpha:0.30], [UIColor colorWithWhite:1 alpha:0.02]);
        CGContextRestoreGState(c);
    }
    /* pressed wedge */
    NSInteger pz = self.pressedZone;
    if (pz >= 0 && pz < 4) {
        static const double a0[4] = {-135, 45, 135, -45};
        CGContextMoveToPoint(c, ctr.x, ctr.y);
        CGContextAddArc(c, ctr.x, ctr.y, R, a0[pz] * M_PI / 180, (a0[pz] + 90) * M_PI / 180, 0);
        CGContextClosePath(c);
        [[UIColor colorWithRed:0.25 green:0.6 blue:1 alpha:0.55] setFill]; CGContextFillPath(c);
    }
    CGContextRestoreGState(c);
    [KRRGB(2, 3, 6) set]; CGContextSetLineWidth(c, 1.5); CGContextStrokeEllipseInRect(c, dish);
    [[UIColor colorWithWhite:0 alpha:0.9] set]; CGContextSetLineWidth(c, 1); CGContextStrokeEllipseInRect(c, b);

    /* the diagonal dividers: engraved */
    for (int i = 0; i < 4; i++) {
        double a = (45 + 90 * i) * M_PI / 180;
        CGPoint p0 = CGPointMake(ctr.x + cos(a) * PAD_OK_R, ctr.y + sin(a) * PAD_OK_R), p1 = CGPointMake(ctr.x + cos(a) * (R - 7), ctr.y + sin(a) * (R - 7));
        CGContextSetLineWidth(c, 1);
        [[UIColor colorWithWhite:0 alpha:0.85] set]; CGContextMoveToPoint(c, p0.x, p0.y); CGContextAddLineToPoint(c, p1.x, p1.y); CGContextStrokePath(c);
        [[UIColor colorWithWhite:1 alpha:0.14] set]; CGContextMoveToPoint(c, p0.x + 1, p0.y + 1); CGContextAddLineToPoint(c, p1.x + 1, p1.y + 1); CGContextStrokePath(c);
    }

    /* arrows, embossed */
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, [UIColor colorWithWhite:0 alpha:0.85].CGColor);
    [[UIColor colorWithRed:0.92 green:0.95 blue:1 alpha:1] setFill];
    CGFloat m = (R - 7 + PAD_OK_R) / 2, s = R * 0.1;
    CGContextMoveToPoint(c, ctr.x, ctr.y - m - s * 0.6); CGContextAddLineToPoint(c, ctr.x - s, ctr.y - m + s * 0.6); CGContextAddLineToPoint(c, ctr.x + s, ctr.y - m + s * 0.6); CGContextFillPath(c);
    CGContextMoveToPoint(c, ctr.x, ctr.y + m + s * 0.6); CGContextAddLineToPoint(c, ctr.x - s, ctr.y + m - s * 0.6); CGContextAddLineToPoint(c, ctr.x + s, ctr.y + m - s * 0.6); CGContextFillPath(c);
    CGContextMoveToPoint(c, ctr.x - m - s * 0.6, ctr.y); CGContextAddLineToPoint(c, ctr.x - m + s * 0.6, ctr.y - s); CGContextAddLineToPoint(c, ctr.x - m + s * 0.6, ctr.y + s); CGContextFillPath(c);
    CGContextMoveToPoint(c, ctr.x + m + s * 0.6, ctr.y); CGContextAddLineToPoint(c, ctr.x + m - s * 0.6, ctr.y - s); CGContextAddLineToPoint(c, ctr.x + m - s * 0.6, ctr.y + s); CGContextFillPath(c);
    CGContextRestoreGState(c);

    /* OK: a glass blue dome in its own chrome ring */
    CGRect ring = CGRectMake(ctr.x - PAD_OK_R + 2, ctr.y - PAD_OK_R + 2, (PAD_OK_R - 2) * 2, (PAD_OK_R - 2) * 2);
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 2), 3, [UIColor colorWithWhite:0 alpha:0.9].CGColor);
    [KRRGB(10, 12, 16) setFill]; CGContextFillEllipseInRect(c, ring);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, ring); CGContextClip(c);
    KRFillGradient4(c, ring, chrome);
    CGContextRestoreGState(c);
    CGRect ok = CGRectInset(ring, 3.5, 3.5);
    BOOL d = pz == 4;
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, ok); CGContextClip(c);
    KRGlassFill(c, ok, d ? KRRGB(70, 130, 220) : KRRGB(140, 190, 255), d ? KRRGB(40, 100, 200) : KRRGB(70, 140, 238), d ? KRRGB(16, 66, 160) : KRRGB(22, 88, 200), d ? KRRGB(30, 90, 190) : KRRGB(60, 140, 240));
    CGRect hi = CGRectMake(ok.origin.x + 5, ok.origin.y + 2, ok.size.width - 10, ok.size.height * 0.4);
    CGContextAddEllipseInRect(c, hi); CGContextClip(c);
    KRFillGradient(c, hi, [UIColor colorWithWhite:1 alpha:d ? 0.2 : 0.65], [UIColor colorWithWhite:1 alpha:0.05]);
    CGContextRestoreGState(c);
    [KRRGB(8, 30, 80) set]; CGContextSetLineWidth(c, 1); CGContextStrokeEllipseInRect(c, CGRectInset(ok, 0.5, 0.5));
    KRDrawText(@"OK", CGRectMake(ok.origin.x, ctr.y - 8 + (d ? 1 : 0) + 3, ok.size.width, 18), KRFont(@"HelveticaNeue-Bold", 16),
               [UIColor whiteColor], [UIColor colorWithRed:0 green:0.12 blue:0.4 alpha:0.8], -1, NSTextAlignmentCenter);
}

@end

#pragma mark - metallic slider

#define KNOB 26

@interface KRSlider ()
@property (nonatomic) BOOL interacting;
@end

@implementation KRSlider

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.opaque = NO; }
    return self;
}

- (void)setValue:(float)v {
    v = MAX(0, MIN(1, v));
    if (v == _value) return;
    _value = v;
    [self setNeedsDisplay];
}

- (CGFloat)knobX { return KNOB / 2 + _value * (self.bounds.size.width - KNOB); }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width, midY = self.bounds.size.height / 2, kx = [self knobX];
    CGRect groove = CGRectMake(KNOB / 2 - 4, midY - 4, w - KNOB + 8, 8);

    /* recessed groove */
    CGContextSaveGState(c);
    KRRoundRectPath(c, groove, 4); CGContextClip(c);
    KRFillGradient(c, groove, KRRGB(8, 10, 14), KRRGB(52, 58, 70));
    /* blue glass fill up to the knob */
    CGRect fill = groove; fill.size.width = kx - groove.origin.x;
    KRGlassFill(c, fill, KRRGB(150, 196, 255), KRRGB(84, 146, 244), KRRGB(30, 100, 220), KRRGB(60, 134, 238));
    [[UIColor colorWithWhite:0 alpha:0.4] set]; CGContextFillRect(c, CGRectMake(groove.origin.x, groove.origin.y, groove.size.width, 1.5));
    CGContextRestoreGState(c);
    KRRoundRectPath(c, CGRectInset(groove, 0.5, 0.5), 3.5); [KRRGB(2, 4, 8) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    [[UIColor colorWithWhite:1 alpha:0.16] set]; CGContextFillRect(c, CGRectMake(groove.origin.x + 4, CGRectGetMaxY(groove) + 0.5, groove.size.width - 8, 1));   /* light lip */

    /* chrome knob: banded metal, dished centre, rim, glow while held */
    CGRect k = CGRectMake(kx - KNOB / 2, midY - KNOB / 2, KNOB, KNOB);
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, self.interacting ? CGSizeZero : CGSizeMake(0, 2), self.interacting ? 10 : 4,
                                self.interacting ? [UIColor colorWithRed:0.3 green:0.7 blue:1 alpha:0.9].CGColor : [UIColor colorWithWhite:0 alpha:0.9].CGColor);
    [KRRGB(60, 66, 78) setFill]; CGContextFillEllipseInRect(c, k);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, k); CGContextClip(c);
    static const CGFloat metal[16] = {0.0, 0.98, 0.99, 1.0,   0.46, 0.62, 0.66, 0.72,   0.52, 0.30, 0.33, 0.38,   1.0, 0.80, 0.84, 0.90};
    KRFillGradient4(c, k, metal);
    CGContextRestoreGState(c);
    CGRect dish = CGRectInset(k, 5, 5);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, dish); CGContextClip(c);
    static const CGFloat dished[16] = {0.0, 0.42, 0.46, 0.52,   0.5, 0.64, 0.68, 0.74,   0.55, 0.86, 0.90, 0.95,   1.0, 0.96, 0.98, 1.0};
    KRFillGradient4(c, dish, dished);
    CGContextRestoreGState(c);
    [KRRGB(34, 40, 50) set]; CGContextSetLineWidth(c, 1); CGContextStrokeEllipseInRect(c, CGRectInset(k, 0.5, 0.5));
    [[UIColor colorWithWhite:0 alpha:0.35] set]; CGContextStrokeEllipseInRect(c, CGRectInset(dish, 0.5, 0.5));
    /* tiny blue LED in the middle */
    CGRect led = CGRectMake(kx - 2, midY - 2, 4, 4);
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeZero, 4, [UIColor colorWithRed:0.3 green:0.7 blue:1 alpha:1].CGColor);
    [KR_ACCENT setFill]; CGContextFillEllipseInRect(c, led);
    CGContextRestoreGState(c);
}

- (void)moveTo:(CGPoint)p {
    self.value = (float)((p.x - KNOB / 2) / (self.bounds.size.width - KNOB));
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    self.interacting = YES;
    [self moveTo:[t locationInView:self]];
    [self setNeedsDisplay];
    return YES;
}
- (BOOL)continueTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e { [self moveTo:[t locationInView:self]]; return YES; }
- (void)finish { self.interacting = NO; [self setNeedsDisplay]; [self sendActionsForControlEvents:UIControlEventEditingDidEnd]; }
- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e { [self finish]; }
- (void)cancelTrackingWithEvent:(UIEvent *)e { [self finish]; }

@end

#pragma mark - now playing

@interface KRNowPlayingView ()
@property (nonatomic, strong) UIImage *art;
@property (nonatomic, copy) NSString *artPath;
@property (nonatomic, strong) KRSlider *slider;
@property (nonatomic) NSTimeInterval holdUntil;      /* after a seek, ignore the old position the server still reports */
@end

@implementation KRNowPlayingView

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor]; self.opaque = NO;
        self.slider = [[KRSlider alloc] initWithFrame:CGRectZero];
        [self.slider addTarget:self action:@selector(scrubbing) forControlEvents:UIControlEventValueChanged];
        [self.slider addTarget:self action:@selector(seek) forControlEvents:UIControlEventEditingDidEnd];
        [self addSubview:self.slider];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.slider.frame = CGRectMake(52, self.bounds.size.height - 36, self.bounds.size.width - 52 - 52, 30);
}

- (void)scrubbing { [self setNeedsDisplay]; }

- (void)seek {
    KRClient *k = [KRClient shared];
    self.holdUntil = [NSDate timeIntervalSinceReferenceDate] + 2.5;
    if (k.playerID) [k call:@"Player.Seek" params:[NSDictionary dictionaryWithObjectsAndKeys:k.playerID, @"playerid",
                                                   [NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:self.slider.value * 100] forKey:@"percentage"], @"value", nil] done:nil];
}

- (void)update {
    KRClient *k = [KRClient shared];
    if (k.hasPlayer && k.thumb.length && ![k.thumb isEqual:self.artPath]) {
        self.artPath = k.thumb; self.art = nil;
        NSString *want = k.thumb;
        [k loadImage:want done:^(UIImage *im) { if ([want isEqual:self.artPath]) { self.art = im; [self setNeedsDisplay]; } }];
    }
    if (!k.hasPlayer) { self.artPath = nil; self.art = nil; }
    BOOL idle = !k.connected || !k.hasPlayer;
    self.slider.hidden = idle;
    if (!self.slider.interacting && [NSDate timeIntervalSinceReferenceDate] > self.holdUntil) self.slider.value = (float)(k.percent / 100.0);
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    KRClient *k = [KRClient shared];
    CGRect card = CGRectInset(self.bounds, 0, 3);
    KRPanel(c, card, 10, NO);

    NSString *title, *sub;
    if (!k.connected) { title = k.server ? [k.server objectForKey:@"name"] : @"No server"; sub = k.status ?: @"Open the Servers tab"; }
    else if (!k.hasPlayer) { title = @"Nothing playing"; sub = [k.server objectForKey:@"name"]; }
    else { title = k.title; sub = k.subtitle; }

    CGRect art = CGRectMake(card.origin.x + 10, card.origin.y + 8, 38, 38);
    CGContextSaveGState(c);
    KRRoundRectPath(c, art, 6); CGContextClip(c);
    if (self.art && k.hasPlayer) [self.art drawInRect:art];
    else {
        KRGlassFill(c, art, KRRGB(110, 124, 150), KRRGB(66, 78, 104), KRRGB(30, 38, 56), KRRGB(44, 56, 80));
        CGFloat cx = CGRectGetMidX(art), cy = CGRectGetMidY(art);
        CGContextSetShadowWithColor(c, CGSizeZero, 6, [UIColor colorWithRed:0.3 green:0.65 blue:1 alpha:0.9].CGColor);
        [KR_ACCENT setFill];
        if (k.hasPlayer) { CGContextMoveToPoint(c, cx - 6, cy - 9); CGContextAddLineToPoint(c, cx + 9, cy); CGContextAddLineToPoint(c, cx - 6, cy + 9); CGContextFillPath(c); }
        else CGContextFillEllipseInRect(c, CGRectMake(cx - 4, cy - 4, 8, 8));
    }
    CGContextRestoreGState(c);
    KRRoundRectPath(c, CGRectInset(art, 0.5, 0.5), 6); [KRRGB(6, 8, 12) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);

    CGFloat tx = art.origin.x + art.size.width + 12, tw = CGRectGetMaxX(card) - tx - 12;
    KRDrawText(title, CGRectMake(tx, card.origin.y + 8, tw, 20), KRFont(@"HelveticaNeue-Bold", 16), KR_TEXT, [UIColor colorWithWhite:0 alpha:0.8], -1, NSTextAlignmentLeft);
    if (sub.length) KRDrawText(sub, CGRectMake(tx, card.origin.y + 29, tw, 14), KRFont(@"HelveticaNeue", 12), KR_DIM, [UIColor colorWithWhite:0 alpha:0.7], -1, NSTextAlignmentLeft);

    if (k.connected && k.hasPlayer) {
        CGFloat y = self.bounds.size.height - 28;
        NSString *left = k.elapsedText, *right = k.totalText;
        if (self.slider.interacting && k.totalSeconds > 0) left = [KRClient clockText:self.slider.value * k.totalSeconds];
        KRDrawText(left, CGRectMake(card.origin.x + 8, y, 42, 14), KRFont(@"HelveticaNeue-Bold", 10.5), KR_ACCENT_HI, [UIColor colorWithWhite:0 alpha:0.8], -1, NSTextAlignmentCenter);
        KRDrawText(right, CGRectMake(CGRectGetMaxX(card) - 50, y, 42, 14), KRFont(@"HelveticaNeue-Bold", 10.5), KR_DIM, [UIColor colorWithWhite:0 alpha:0.8], -1, NSTextAlignmentCenter);
    }
}

@end
