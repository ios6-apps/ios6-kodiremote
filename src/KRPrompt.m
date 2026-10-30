#import "KRPrompt.h"
#import "KRStyle.h"

@interface KRPromptButton : UIControl
@property (nonatomic, copy) NSString *title;
@property (nonatomic) BOOL primary;
@end

@implementation KRPromptButton
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) self.backgroundColor = [UIColor clearColor]; return self; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = CGRectInset(self.bounds, 0.5, 0.5);
    BOOL on = self.highlighted;
    UIColor *top = self.primary ? (on ? KRRGB(30, 100, 190) : KRRGB(96, 170, 250)) : (on ? KRRGB(40, 50, 68) : KRRGB(104, 118, 142));
    UIColor *bot = self.primary ? (on ? KRRGB(20, 70, 150) : KRRGB(24, 104, 214)) : (on ? KRRGB(24, 32, 46) : KRRGB(52, 64, 86));
    KRGlossRoundRect(c, b, 7, top, bot, KRRGB(10, 14, 22));
    KRDrawText(self.title, CGRectMake(4, (b.size.height - 20) / 2, b.size.width - 8, 22), KRFont(@"HelveticaNeue-Bold", 16), [UIColor whiteColor], [UIColor colorWithWhite:0 alpha:0.6], -1, NSTextAlignmentCenter);
}
@end

@interface KRPrompt () <UITextFieldDelegate>
@property (nonatomic, copy) KRPromptHandler handler;
@property (nonatomic, strong) NSMutableArray *inputs;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, copy) NSString *title, *message;
@end

@implementation KRPrompt

+ (KRPrompt *)showTitle:(NSString *)title message:(NSString *)message fields:(NSArray *)fields buttons:(NSArray *)buttons handler:(KRPromptHandler)handler {
    UIWindow *w = [[UIApplication sharedApplication] keyWindow] ?: [[[UIApplication sharedApplication] windows] lastObject];
    if (!w) return nil;
    KRPrompt *p = [[KRPrompt alloc] initWithFrame:w.bounds];
    p.title = title; p.message = message; p.handler = handler;
    [p build:fields buttons:buttons];
    [w addSubview:p];
    p.alpha = 0;
    [UIView animateWithDuration:0.18 animations:^{ p.alpha = 1; }];
    UITextField *first = [p.inputs firstObject];
    [first becomeFirstResponder];
    return p;
}

- (void)dismiss {
    self.handler = nil;
    [self endEditing:YES];
    [UIView animateWithDuration:0.15 animations:^{ self.alpha = 0; } completion:^(BOOL done) { [self removeFromSuperview]; }];
}

- (void)build:(NSArray *)fields buttons:(NSArray *)buttons {
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    CGFloat pw = 280, y = 16;
    CGSize ms = [self.message sizeWithFont:KRFont(@"HelveticaNeue", 14) constrainedToSize:CGSizeMake(pw - 36, 200) lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat ph = 16 + 24 + 8 + (self.message.length ? ms.height + 12 : 0) + fields.count * 42 + 46 + 16;
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width - pw) / 2, 54, pw, ph)];
    panel.backgroundColor = [UIColor clearColor];
    self.panel = panel;
    [self addSubview:panel];

    UIImageView *bg = [[UIImageView alloc] initWithFrame:panel.bounds];
    UIGraphicsBeginImageContextWithOptions(panel.bounds.size, NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 4), 12, [UIColor colorWithWhite:0 alpha:0.8].CGColor);
    KRGlossRoundRect(c, CGRectInset(panel.bounds, 4, 4), 10, KRRGB(58, 70, 92), KRRGB(20, 26, 38), KRRGB(150, 168, 196));
    CGContextRestoreGState(c);
    bg.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [panel addSubview:bg];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(18, y, pw - 36, 24)];
    t.text = self.title; t.textAlignment = NSTextAlignmentCenter; t.backgroundColor = [UIColor clearColor];
    t.font = KRFont(@"HelveticaNeue-Bold", 18); t.textColor = KR_TEXT; t.shadowColor = [UIColor blackColor]; t.shadowOffset = CGSizeMake(0, -1);
    [panel addSubview:t];
    y += 24 + 8;
    if (self.message.length) {
        UILabel *m = [[UILabel alloc] initWithFrame:CGRectMake(18, y, pw - 36, ms.height)];
        m.text = self.message; m.numberOfLines = 0; m.textAlignment = NSTextAlignmentCenter; m.backgroundColor = [UIColor clearColor];
        m.font = KRFont(@"HelveticaNeue", 14); m.textColor = KR_DIM;
        [panel addSubview:m];
        y += ms.height + 12;
    }
    self.inputs = [NSMutableArray array];
    for (NSDictionary *d in fields) {
        UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(18, y, pw - 36, 32)];
        f.borderStyle = UITextBorderStyleRoundedRect;
        f.text = [d objectForKey:@"text"]; f.placeholder = [d objectForKey:@"placeholder"];
        f.secureTextEntry = [[d objectForKey:@"secure"] boolValue];
        f.keyboardType = [[d objectForKey:@"url"] boolValue] ? UIKeyboardTypeURL : UIKeyboardTypeDefault;
        f.autocorrectionType = UITextAutocorrectionTypeNo;
        f.autocapitalizationType = UITextAutocapitalizationTypeNone;
        f.clearButtonMode = UITextFieldViewModeWhileEditing;
        f.returnKeyType = (f == nil) ? UIReturnKeyDefault : UIReturnKeyGo;
        f.font = [UIFont systemFontOfSize:16];
        f.delegate = self;
        [panel addSubview:f];
        [self.inputs addObject:f];
        y += 42;
    }
    CGFloat bw = (pw - 36 - 10 * (buttons.count - 1)) / buttons.count;
    for (NSUInteger i = 0; i < buttons.count; i++) {
        KRPromptButton *b = [[KRPromptButton alloc] initWithFrame:CGRectMake(18 + i * (bw + 10), y + 4, bw, 38)];
        b.title = [buttons objectAtIndex:i]; b.primary = i > 0; b.tag = i;
        [b addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [panel addSubview:b];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)f {
    NSUInteger i = [self.inputs indexOfObject:f];
    if (i + 1 < self.inputs.count) { [[self.inputs objectAtIndex:i + 1] becomeFirstResponder]; return NO; }
    [self finish:1];
    return NO;
}

- (void)tapped:(UIControl *)b { [self finish:b.tag]; }

- (void)finish:(NSInteger)idx {
    NSMutableArray *texts = [NSMutableArray array];
    for (UITextField *f in self.inputs) [texts addObject:f.text ?: @""];
    KRPromptHandler h = self.handler;
    self.handler = nil;
    [self endEditing:YES];
    [UIView animateWithDuration:0.15 animations:^{ self.alpha = 0; } completion:^(BOOL done) { [self removeFromSuperview]; }];
    if (h) h(idx, texts);
}

@end
