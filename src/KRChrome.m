#import "KRChrome.h"
#import "KRStyle.h"

#define NAV_H 44
#define TAB_H 49

#pragma mark - small controls

@interface KRBackButton : UIControl
@property (nonatomic, copy) NSString *label;
@end

@implementation KRBackButton
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    /* one path: a rounded body with a pointed left end */
    CGContextMoveToPoint(c, 12, 0.5);
    CGContextAddLineToPoint(c, w - 5.5, 0.5);
    CGContextAddArcToPoint(c, w - 0.5, 0.5, w - 0.5, 5.5, 5);
    CGContextAddLineToPoint(c, w - 0.5, h - 5.5);
    CGContextAddArcToPoint(c, w - 0.5, h - 0.5, w - 5.5, h - 0.5, 5);
    CGContextAddLineToPoint(c, 12, h - 0.5);
    CGContextAddLineToPoint(c, 0.5, h / 2);
    CGContextClosePath(c);
    CGPathRef path = CGContextCopyPath(c);
    CGContextSaveGState(c);
    CGContextClip(c);
    BOOL d = self.highlighted;
    if (d) KRGlassFill(c, self.bounds, KRRGB(34, 62, 112), KRRGB(24, 48, 94), KRRGB(14, 36, 80), KRRGB(24, 50, 96));
    else KRGlassFill(c, self.bounds, KRRGB(132, 168, 228), KRRGB(88, 128, 202), KRRGB(52, 92, 176), KRRGB(78, 118, 196));
    [[UIColor colorWithWhite:1 alpha:d ? 0.1 : 0.4] set]; CGContextFillRect(c, CGRectMake(0, 0, w, 1));
    CGContextRestoreGState(c);
    CGContextAddPath(c, path); CGPathRelease(path);
    [KRRGB(16, 30, 64) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    KRDrawText(self.label, CGRectMake(13, 7, w - 17, 16), KRFont(@"HelveticaNeue-Bold", 12.5), [UIColor whiteColor], [UIColor colorWithRed:0 green:0.1 blue:0.3 alpha:0.7], -1, NSTextAlignmentCenter);
}
@end

@interface KRSegmented ()
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) NSMutableArray *disabled;
@end

@implementation KRSegmented
- (id)initWithItems:(NSArray *)items {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 148, 28)])) {
        self.items = items;
        self.disabled = [NSMutableArray array];
        for (NSUInteger i = 0; i < items.count; i++) [self.disabled addObject:[NSNumber numberWithBool:NO]];
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}
- (void)setSelectedIndex:(NSInteger)i { _selectedIndex = i; [self setNeedsDisplay]; }
- (void)setEnabled:(BOOL)on forIndex:(NSInteger)i { [self.disabled replaceObjectAtIndex:i withObject:[NSNumber numberWithBool:!on]]; [self setNeedsDisplay]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGFloat sw = b.size.width / self.items.count;
    CGContextSaveGState(c);
    KRRoundRectPath(c, CGRectInset(b, 0.5, 0.5), 6); CGContextClip(c);
    for (NSUInteger i = 0; i < self.items.count; i++) {
        CGRect seg = CGRectMake(i * sw, 0, sw, b.size.height);
        if ((NSInteger)i == self.selectedIndex) {
            KRGlassFill(c, seg, KRRGB(132, 168, 228), KRRGB(88, 128, 202), KRRGB(52, 92, 176), KRRGB(78, 118, 196));
            [[UIColor colorWithWhite:0 alpha:0.35] set]; CGContextFillRect(c, CGRectMake(seg.origin.x, 0, seg.size.width, 2));   /* pressed-in shade at the top */
        } else {
            KRGlassFill(c, seg, KRRGB(104, 112, 128), KRRGB(66, 73, 88), KRRGB(36, 41, 52), KRRGB(48, 54, 66));
        }
        [[UIColor colorWithWhite:1 alpha:(NSInteger)i == self.selectedIndex ? 0.12 : 0.3] set]; CGContextFillRect(c, CGRectMake(seg.origin.x, 0, seg.size.width, 1));
        if (i > 0) { [KRRGB(8, 12, 20) set]; CGContextFillRect(c, CGRectMake(seg.origin.x, 0, 1, b.size.height)); }
    }
    CGContextRestoreGState(c);
    KRRoundRectPath(c, CGRectInset(b, 0.5, 0.5), 6);
    [KRRGB(8, 12, 20) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    for (NSUInteger i = 0; i < self.items.count; i++) {
        BOOL off = [[self.disabled objectAtIndex:i] boolValue], sel = (NSInteger)i == self.selectedIndex;
        UIColor *col = off ? KRRGB(112, 120, 136) : [UIColor whiteColor];
        KRDrawText([self.items objectAtIndex:i], CGRectMake(i * sw, 6, sw, 16), KRFont(@"HelveticaNeue-Bold", 12.5), col,
                   sel ? [UIColor colorWithRed:0 green:0.1 blue:0.3 alpha:0.7] : [UIColor colorWithWhite:0 alpha:0.6], -1, NSTextAlignmentCenter);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    CGPoint p = [[touches anyObject] locationInView:self];
    NSInteger i = MIN((NSInteger)self.items.count - 1, MAX(0, (NSInteger)(p.x / (self.bounds.size.width / self.items.count))));
    if ([[self.disabled objectAtIndex:i] boolValue] || i == self.selectedIndex) return;
    self.selectedIndex = i;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
@end

#pragma mark - bars

@interface KRShadowView : UIView
@property (nonatomic) BOOL flip;
@end
@implementation KRShadowView
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.userInteractionEnabled = NO; } return self; }
- (void)drawRect:(CGRect)r {
    KRFillGradient(UIGraphicsGetCurrentContext(), self.bounds, [UIColor colorWithWhite:0 alpha:self.flip ? 0 : 0.55], [UIColor colorWithWhite:0 alpha:self.flip ? 0.55 : 0]);
}
@end

@interface KRNavBar : UIView
@property (nonatomic, strong) KRBackButton *back;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *titleView, *rightView;
- (void)setTitle:(NSString *)t titleView:(UIView *)tv rightView:(UIView *)rv showBack:(BOOL)b;
@end

@implementation KRNavBar
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor];
        self.back = [[KRBackButton alloc] initWithFrame:CGRectMake(6, 7, 58, 30)];
        self.back.backgroundColor = [UIColor clearColor];
        self.back.label = @"Back";
        [self addSubview:self.back];
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = KR_TEXT;
        self.titleLabel.font = KRFont(@"HelveticaNeue-Bold", 20);
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.7];
        self.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [self addSubview:self.titleLabel];
    }
    return self;
}
- (void)setTitle:(NSString *)t titleView:(UIView *)tv rightView:(UIView *)rv showBack:(BOOL)b {
    if (self.titleView != tv) { [self.titleView removeFromSuperview]; self.titleView = tv; if (tv) [self addSubview:tv]; }
    if (self.rightView != rv) { [self.rightView removeFromSuperview]; self.rightView = rv; if (rv) [self addSubview:rv]; }
    self.titleLabel.text = t;
    self.titleLabel.hidden = tv != nil;
    self.back.hidden = !b;
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    CGFloat w = self.bounds.size.width;
    self.titleLabel.frame = CGRectMake(72, 0, w - 144, NAV_H - 2);
    self.titleView.center = CGPointMake(w / 2, NAV_H / 2 - 1);
    CGRect r = self.rightView.bounds;
    self.rightView.frame = CGRectMake(w - 8 - r.size.width, (NAV_H - r.size.height) / 2 - 1, r.size.width, r.size.height);
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    KRGlassFill(c, b, KRRGB(112, 124, 148), KRRGB(74, 84, 106), KRRGB(40, 47, 62), KRRGB(30, 36, 48));
    [[UIColor colorWithWhite:1 alpha:0.4] set]; CGContextFillRect(c, CGRectMake(0, 0, b.size.width, 1));
    [KRRGB(6, 9, 14) set]; CGContextFillRect(c, CGRectMake(0, NAV_H - 1, b.size.width, 1));
}
@end

@interface KRTabBar : UIView
@property (nonatomic, strong) NSArray *names, *icons;
@property (nonatomic) NSInteger selected;
@property (nonatomic, copy) void (^onSelect)(NSInteger);
@end

@implementation KRTabBar
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.opaque = YES; } return self; }
- (void)setSelected:(NSInteger)s { _selected = s; [self setNeedsDisplay]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGFloat w = b.size.width;
    KRGlassFill(c, b, KRRGB(78, 84, 98), KRRGB(46, 50, 60), KRRGB(16, 18, 24), KRRGB(24, 27, 34));
    [[UIColor colorWithWhite:1 alpha:0.32] set]; CGContextFillRect(c, CGRectMake(0, 0, w, 1));
    [KRRGB(4, 5, 8) set]; CGContextFillRect(c, CGRectMake(0, 1, w, 1));

    NSArray *names = self.names;
    NSInteger n = names.count;
    CGFloat iw = w / n;
    for (int i = 0; i < n; i++) {
        BOOL sel = i == self.selected;
        CGRect cell = CGRectMake(i * iw, 0, iw, TAB_H);
        if (sel) {   /* a glass plate behind the active tab */
            CGRect plate = CGRectInset(CGRectMake(cell.origin.x, 4, iw, TAB_H - 7), 5, 0);
            CGContextSaveGState(c);
            KRRoundRectPath(c, plate, 7); CGContextClip(c);
            KRGlassFill(c, plate, KRRGB(120, 134, 164), KRRGB(78, 90, 118), KRRGB(40, 48, 68), KRRGB(52, 62, 86));
            [[UIColor colorWithWhite:0 alpha:0.3] set]; CGContextFillRect(c, CGRectMake(plate.origin.x, plate.origin.y, plate.size.width, 2));
            CGContextRestoreGState(c);
            KRRoundRectPath(c, CGRectInset(plate, 0.5, 0.5), 6.5);
            [KRRGB(4, 6, 12) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
        }
        /* icon: gradient poured through the glyph's alpha mask */
        UIImage *ic = KRTabIcon([[self.icons objectAtIndex:i] intValue]);
        CGRect ir = CGRectMake(cell.origin.x + (iw - 24) / 2, 8, 24, 24);
        CGContextSaveGState(c);
        CGContextTranslateCTM(c, ir.origin.x, ir.origin.y + 24);
        CGContextScaleCTM(c, 1, -1);
        CGContextClipToMask(c, CGRectMake(0, 0, 24, 24), ic.CGImage);
        CGContextScaleCTM(c, 1, -1);
        CGContextTranslateCTM(c, -ir.origin.x, -(ir.origin.y + 24));
        CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, [UIColor colorWithWhite:0 alpha:0.8].CGColor);
        if (sel) KRFillGradient(c, ir, KRRGB(190, 232, 255), KRRGB(56, 156, 255));
        else KRFillGradient(c, ir, KRRGB(170, 178, 192), KRRGB(104, 112, 128));
        CGContextRestoreGState(c);
        KRDrawText([names objectAtIndex:i], CGRectMake(cell.origin.x, 32, iw, 12), KRFont(@"HelveticaNeue-Bold", 10),
                   sel ? [UIColor whiteColor] : KRRGB(140, 148, 164), [UIColor colorWithWhite:0 alpha:0.8], -1, NSTextAlignmentCenter);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    NSInteger i = MIN((NSInteger)self.names.count - 1, MAX(0, (NSInteger)([[touches anyObject] locationInView:self].x / (self.bounds.size.width / self.names.count))));
    if (self.onSelect) self.onSelect(i);
}
@end

#pragma mark - root controller

static __unsafe_unretained KRRootController *gRoot;

@interface KRRootController () {
    NSMutableArray *_stacks;
    NSInteger _tab;
    KRNavBar *_nav;
    UIView *_content, *_strip;
    KRTabBar *_tabs;
    NSArray *_tabs0;
    KRShadowView *_shadowTop, *_shadowBottom;
    CGFloat _top;
}
@end

@implementation KRRootController

+ (KRRootController *)shared { return gRoot; }

- (id)initWithTabs:(NSArray *)tabs {
    if ((self = [super init])) {
        gRoot = self;
        _tabs0 = tabs;
        _stacks = [NSMutableArray array];
        for (NSDictionary *t in tabs) [_stacks addObject:[NSMutableArray arrayWithObject:[t objectForKey:@"vc"]]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    _strip = [[UIView alloc] init];
    _strip.backgroundColor = [UIColor blackColor];
    _content = [[UIView alloc] init];
    _content.clipsToBounds = YES;
    _content.backgroundColor = [UIColor colorWithPatternImage:KRBackdropImage()];
    _nav = [[KRNavBar alloc] init];
    [_nav.back addTarget:self action:@selector(pop) forControlEvents:UIControlEventTouchUpInside];
    _tabs = [[KRTabBar alloc] init];
    _tabs.names = [_tabs0 valueForKey:@"title"];
    _tabs.icons = [_tabs0 valueForKey:@"icon"];
    __unsafe_unretained KRRootController *me = self;
    _tabs.onSelect = ^(NSInteger i) { [me selectTab:i]; };
    _shadowTop = [[KRShadowView alloc] init];
    _shadowBottom = [[KRShadowView alloc] init];
    _shadowBottom.flip = YES;
    for (UIView *v in [NSArray arrayWithObjects:_content, _shadowTop, _shadowBottom, _nav, _tabs, _strip, nil]) [self.view addSubview:v];
#ifdef KR_PREVIEW
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, 320, 16)];
    t.text = @"9:41"; t.textAlignment = NSTextAlignmentCenter; t.backgroundColor = [UIColor clearColor];
    t.textColor = [UIColor whiteColor]; t.font = [UIFont boldSystemFontOfSize:12];
    [_strip addSubview:t];
#endif
    [self showTop];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    /* iOS 6 puts the root view below the status bar already; later systems extend it underneath (and the simulator preview offsets it) */
    CGRect inWindow = [self.view convertRect:self.view.bounds toView:nil];
    _top = fabs(inWindow.origin.y - 20) < 1 ? 0 : 20;   /* iOS 6: view starts at y=20 */
    CGFloat w = b.size.width, h = b.size.height;
    _strip.frame = CGRectMake(0, 0, w, _top);
    _nav.frame = CGRectMake(0, _top, w, NAV_H);
    _tabs.frame = CGRectMake(0, h - TAB_H, w, TAB_H);
    _content.frame = CGRectMake(0, _top + NAV_H, w, h - _top - NAV_H - TAB_H);
    _shadowTop.frame = CGRectMake(0, _top + NAV_H, w, 6);
    _shadowBottom.frame = CGRectMake(0, h - TAB_H - 6, w, 6);
    [_nav setNeedsDisplay]; [_tabs setNeedsDisplay];
    for (NSArray *st in _stacks) { UIViewController *vc = st.lastObject; if (vc.isViewLoaded && vc.view.superview) vc.view.frame = _content.bounds; }
}

- (NSMutableArray *)stack { return [_stacks objectAtIndex:_tab]; }

- (void)showTop {
    UIViewController *vc = [self stack].lastObject;
    if (vc.parentViewController != self) [self addChildViewController:vc];
    UIView *v = vc.view;
    v.frame = _content.bounds;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_content addSubview:v];
    [vc didMoveToParentViewController:self];
    if ([vc respondsToSelector:@selector(krWillShow)]) [(id<KRScreen>)vc krWillShow];
    _tabs.selected = _tab;
    [self refreshBar];
}

- (void)refreshBar {
    UIViewController *vc = [self stack].lastObject;
    id<KRScreen> s = (id<KRScreen>)vc;
    NSString *t = [s respondsToSelector:@selector(krTitle)] ? [s krTitle] : nil;
    UIView *tv = [s respondsToSelector:@selector(krTitleView)] ? [s krTitleView] : nil;
    UIView *rv = [s respondsToSelector:@selector(krRightView)] ? [s krRightView] : nil;
    [_nav setTitle:t titleView:tv rightView:rv showBack:[self stack].count > 1];
}

- (void)selectTab:(NSInteger)tab {
    if (tab == _tab) {
        while ([self stack].count > 1) [self popImmediately];   /* tapping the active tab returns to its list */
        return;
    }
    [[[self stack].lastObject view] removeFromSuperview];
    _tab = tab;
    [self showTop];
}

- (void)popImmediately {
    NSMutableArray *st = [self stack];
    UIViewController *gone = st.lastObject;
    [gone willMoveToParentViewController:nil];
    [gone.view removeFromSuperview];
    [gone removeFromParentViewController];
    [st removeLastObject];
    [self showTop];
}

- (void)push:(UIViewController *)vc {
    NSMutableArray *st = [self stack];
    UIViewController *old = st.lastObject;
    CGFloat w = _content.bounds.size.width;
    [st addObject:vc];
    [self addChildViewController:vc];
    UIView *v = vc.view;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.frame = CGRectOffset(_content.bounds, w, 0);
    [_content addSubview:v];
    [vc didMoveToParentViewController:self];
    [self refreshBar];
    [UIView animateWithDuration:0.3 animations:^{
        v.frame = self->_content.bounds;
        old.view.frame = CGRectOffset(self->_content.bounds, -w / 3, 0);
    } completion:^(BOOL f) {
        [old.view removeFromSuperview];
        old.view.frame = self->_content.bounds;
    }];
}

- (void)pop {
    NSMutableArray *st = [self stack];
    if (st.count < 2) return;
    UIViewController *gone = st.lastObject, *prev = [st objectAtIndex:st.count - 2];
    CGFloat w = _content.bounds.size.width;
    if ([prev respondsToSelector:@selector(krWillShow)]) [(id<KRScreen>)prev krWillShow];
    prev.view.frame = CGRectOffset(_content.bounds, -w / 3, 0);
    [_content insertSubview:prev.view belowSubview:gone.view];
    [st removeLastObject];
    [self refreshBar];
    [UIView animateWithDuration:0.3 animations:^{
        gone.view.frame = CGRectOffset(self->_content.bounds, w, 0);
        prev.view.frame = self->_content.bounds;
    } completion:^(BOOL f) {
        [gone willMoveToParentViewController:nil];
        [gone.view removeFromSuperview];
        [gone removeFromParentViewController];
    }];
}

- (BOOL)shouldAutorotate { return NO; }
- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

@end
