#import "KRCards.h"
#import "KRStyle.h"

@interface KRCardView : UIView
@property (nonatomic, weak) KRCardCell *cell;
@property (nonatomic) BOOL lit;
@end

@implementation KRCardView

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.opaque = NO; self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    KRCardCell *cell = self.cell;
    CGFloat w = self.bounds.size.width;
    CGRect card = CGRectMake(8, 5, w - 16, self.bounds.size.height - 10);
    KRPanel(c, card, 10, self.lit);

    CGFloat x = 20;
    CGRect tile = CGRectMake(20, card.origin.y + 8, 40, 40);
    if (cell.image || cell.iconKind >= 0) {
        CGContextSaveGState(c);
        KRRoundRectPath(c, tile, 8); CGContextClip(c);
        if (cell.image) { [cell.image drawInRect:tile]; }
        else {
            KRGlassFill(c, tile, KRRGB(110, 124, 150), KRRGB(66, 78, 104), KRRGB(30, 38, 56), KRRGB(44, 56, 80));
            UIImage *ic = KRTabIcon(cell.iconKind);
            CGRect ir = CGRectInset(tile, 5, 5);
            CGContextTranslateCTM(c, ir.origin.x, ir.origin.y + ir.size.height);
            CGContextScaleCTM(c, 1, -1);
            CGContextClipToMask(c, CGRectMake(0, 0, ir.size.width, ir.size.height), ic.CGImage);
            CGContextScaleCTM(c, 1, -1);
            CGContextTranslateCTM(c, -ir.origin.x, -(ir.origin.y + ir.size.height));
            KRFillGradient(c, ir, KRRGB(236, 246, 255), KRRGB(150, 196, 250));
        }
        CGContextRestoreGState(c);
        KRRoundRectPath(c, CGRectInset(tile, 0.5, 0.5), 7.5); [KRRGB(6, 8, 12) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
        x = 70;
    }
    CGFloat right = card.origin.x + card.size.width - (cell.badge == KRAccessoryNone ? 12 : 46);
    BOOL two = cell.subtitle.length > 0;
    KRDrawText(cell.title, CGRectMake(x, card.origin.y + (two ? 9 : 17), right - x, 20), KRFont(@"HelveticaNeue-Bold", 16), KR_TEXT, [UIColor colorWithWhite:0 alpha:0.8], -1, NSTextAlignmentLeft);
    if (two) KRDrawText(cell.subtitle, CGRectMake(x, card.origin.y + 30, right - x, 16), KRFont(@"HelveticaNeue", 12), KR_DIM, [UIColor colorWithWhite:0 alpha:0.7], -1, NSTextAlignmentLeft);

    if (cell.badge != KRAccessoryNone) {
        CGRect pill = CGRectMake(CGRectGetMaxX(card) - 38, CGRectGetMidY(card) - 12, 24, 24);
        CGFloat cx = CGRectGetMidX(pill), cy = CGRectGetMidY(pill);
        BOOL blue = cell.badge != KRAccessoryPlus;
        CGContextSaveGState(c);
        CGContextAddEllipseInRect(c, pill); CGContextClip(c);
        if (blue) KRGlassFill(c, pill, KRRGB(150, 196, 255), KRRGB(84, 146, 244), KRRGB(30, 100, 220), KRRGB(60, 134, 238));
        else KRGlassFill(c, pill, KRRGB(112, 122, 144), KRRGB(72, 80, 98), KRRGB(36, 41, 52), KRRGB(50, 56, 70));
        CGContextRestoreGState(c);
        [[UIColor colorWithWhite:1 alpha:0.18] set]; CGContextSetLineWidth(c, 1); CGContextStrokeEllipseInRect(c, CGRectOffset(CGRectInset(pill, 0.5, 0.5), 0, 1));
        [KRRGB(4, 8, 16) set]; CGContextStrokeEllipseInRect(c, CGRectInset(pill, 0.5, 0.5));
        [[UIColor whiteColor] set];
        CGContextSetLineWidth(c, 2.2); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
        CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, [UIColor colorWithWhite:0 alpha:0.5].CGColor);
        if (cell.badge == KRAccessoryCheck) { CGContextMoveToPoint(c, cx - 5, cy); CGContextAddLineToPoint(c, cx - 1.5, cy + 4); CGContextAddLineToPoint(c, cx + 5.5, cy - 4); }
        else if (cell.badge == KRAccessoryPlus) { CGContextMoveToPoint(c, cx - 5, cy); CGContextAddLineToPoint(c, cx + 5, cy); CGContextMoveToPoint(c, cx, cy - 5); CGContextAddLineToPoint(c, cx, cy + 5); }
        else { CGContextMoveToPoint(c, cx - 2, cy - 5); CGContextAddLineToPoint(c, cx + 3, cy); CGContextAddLineToPoint(c, cx - 2, cy + 5); }
        CGContextStrokePath(c);
    }
}
@end

@interface KRCardCell ()
@property (nonatomic, strong) KRCardView *card;
@end

@implementation KRCardCell
@synthesize title = _title, subtitle = _subtitle;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:style reuseIdentifier:rid])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.card = [[KRCardView alloc] initWithFrame:self.contentView.bounds];
        self.card.cell = self;
        [self.contentView addSubview:self.card];
        self.iconKind = -1;
    }
    return self;
}
- (void)reloadCard { [self.card setNeedsDisplay]; }
- (void)setHighlighted:(BOOL)h animated:(BOOL)a { [super setHighlighted:h animated:a]; self.card.lit = h; [self.card setNeedsDisplay]; }
- (void)layoutSubviews { [super layoutSubviews]; self.card.frame = self.contentView.bounds; }
@end

UIView *KRSectionHeader(NSString *text, CGFloat width) {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 30)];
    v.backgroundColor = [UIColor clearColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(18, 8, width - 36, 18)];
    l.backgroundColor = [UIColor clearColor];
    l.text = [text uppercaseString];
    l.font = KRFont(@"HelveticaNeue-Bold", 12);
    l.textColor = KRRGB(188, 198, 214);
    l.shadowColor = [UIColor colorWithWhite:0 alpha:0.8];
    l.shadowOffset = CGSizeMake(0, -1);
    [v addSubview:l];
    return v;
}
