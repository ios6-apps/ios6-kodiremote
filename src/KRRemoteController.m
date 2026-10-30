#import "KRRemoteController.h"
#import "KRControls.h"
#import "KRClient.h"
#import "KRChrome.h"
#import "KRStyle.h"
#import "KRPrompt.h"

@interface KRRemoteController () <KRScreen>
@property (nonatomic, strong) KRNowPlayingView *now;
@property (nonatomic, strong) KRDPad *dpad;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, strong) KRSlider *volume;
@property (nonatomic, strong) KRButton *mute, *keys;
@property (nonatomic) NSTimeInterval volumeHold, volumeSent;
@end

@implementation KRRemoteController

- (NSString *)krTitle {
    NSDictionary *s = [KRClient shared].server;
    return s ? [s objectForKey:@"name"] : @"Kodi Remote";
}

- (KRButton *)button:(NSString *)label glyph:(KRGlyph)g repeats:(BOOL)rep key:(NSString *)key {
    KRButton *b = [[KRButton alloc] initWithFrame:CGRectZero];
    b.label = label; b.glyph = g; b.repeats = rep;
    b.accessibilityLabel = label ?: key;
    b.key = key;
    [b addTarget:self action:@selector(pressed:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:b];
    [self.buttons addObject:b];
    return b;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithPatternImage:KRBackdropImage()];
    self.buttons = [NSMutableArray array];

    self.now = [[KRNowPlayingView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.now];
    self.dpad = [[KRDPad alloc] initWithFrame:CGRectMake(0, 0, 196, 196)];
    [self.dpad addTarget:self action:@selector(dpadPressed) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.dpad];

    /* rows: navigation, transport, volume; the key is the Kodi call each one makes */
    [self button:@"Back" glyph:KRGlyphNone repeats:NO key:@"Input.Back"];
    [self button:nil glyph:KRGlyphPlayPause repeats:NO key:@"playpause"];
    [self button:@"Home" glyph:KRGlyphNone repeats:NO key:@"Input.Home"];

    self.mute = [self button:nil glyph:KRGlyphMute repeats:NO key:@"mute"];
    /* lives in the title bar, so the remote itself keeps its room */
    self.keys = [[KRButton alloc] initWithFrame:CGRectMake(0, 0, 54, 30)];
    self.keys.glyph = KRGlyphKeyboard; self.keys.key = @"keyboard"; self.keys.accessibilityLabel = @"Type text";
    [self.keys addTarget:self action:@selector(pressed:) forControlEvents:UIControlEventValueChanged];

    self.volume = [[KRSlider alloc] initWithFrame:CGRectZero];
    [self.volume addTarget:self action:@selector(volumeMoved) forControlEvents:UIControlEventValueChanged];
    [self.volume addTarget:self action:@selector(volumeDone) forControlEvents:UIControlEventEditingDidEnd];
    [self.view addSubview:self.volume];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changed) name:KRClientChanged object:nil];
    [self changed];
}

- (UIView *)krRightView { return self.keys; }

/* Kodi only takes text while one of its own text boxes (search, password, rename) is open on screen */
- (void)typeText {
    [KRPrompt showTitle:@"Type into Kodi" message:@"Open a text box in Kodi first (search, password…), then send what you type here."
                 fields:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"text", @"placeholder", nil]]
                buttons:[NSArray arrayWithObjects:@"Cancel", @"Send", nil]
                handler:^(NSInteger i, NSArray *texts) {
        NSString *text = [texts objectAtIndex:0];
        if (i == 0 || !text.length) return;
        [[KRClient shared] call:@"Input.SendText" params:[NSDictionary dictionaryWithObjectsAndKeys:text, @"text", [NSNumber numberWithBool:YES], @"done", nil] done:^(id result, NSString *err) {
            if (!err) return;
            [KRPrompt showTitle:@"Kodi didn't take it" message:[err stringByAppendingString:@"\n\nIs a text box open in Kodi?"] fields:nil
                        buttons:[NSArray arrayWithObjects:@"Cancel", @"Try again", nil]
                        handler:^(NSInteger j, NSArray *t) { if (j == 1) [self typeText]; }];
        }];
    }];
}

- (void)changed {
    KRClient *k = [KRClient shared];
    [self.now update];
    self.mute.latched = k.muted;
    if (!self.volume.interacting && [NSDate timeIntervalSinceReferenceDate] > self.volumeHold) self.volume.value = k.volume / 100.0f;
    [[KRRootController shared] refreshBar];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    /* like a hand-held remote: a slim now-playing strip, then the pad takes everything the three keys and the volume row leave */
    CGFloat nowH = 84, keyH = 54, volH = 34, gap = 8;
    CGFloat pad = MIN(w - 24, h - nowH - keyH - volH - 4 * gap - 4);
    CGFloat total = nowH + gap + pad + gap + keyH + gap + volH;
    CGFloat y = MAX(4, floor((h - total) / 2));
    self.now.frame = CGRectMake(8, y, w - 16, nowH);
    y += nowH + gap;
    self.dpad.frame = CGRectMake(floor((w - pad) / 2), y, pad, pad);
    y += pad + gap;
    {   /* Back, a wider Play/Pause in the middle, Home */
        CGFloat g = 8, side = floor((w - 16 - 2 * g) * 0.3), mid = w - 16 - 2 * g - 2 * side;
        [[self.buttons objectAtIndex:0] setFrame:CGRectMake(8, y, side, keyH)];
        [[self.buttons objectAtIndex:1] setFrame:CGRectMake(8 + side + g, y, mid, keyH)];
        [[self.buttons objectAtIndex:2] setFrame:CGRectMake(8 + side + g + mid + g, y, side, keyH)];
    }
    y += keyH + gap;
    self.mute.frame = CGRectMake(8, y, 50, volH);
    self.volume.frame = CGRectMake(70, y + 2, w - 70 - 14, 30);
}

- (void)dpadPressed {
    static NSString *const calls[5] = {@"Input.Up", @"Input.Down", @"Input.Left", @"Input.Right", @"Input.Select"};
    NSInteger z = self.dpad.zone;
    if (z >= 0 && z < 5) [[KRClient shared] input:calls[z]];
}

/* the slider drags the volume live (at most about 8 updates a second), then keeps its own value for a moment so the poll doesn't snap it back */
- (void)volumeMoved {
    self.volumeHold = [NSDate timeIntervalSinceReferenceDate] + 2;
    if (self.volumeHold - 2 - self.volumeSent < 0.12) return;
    self.volumeSent = self.volumeHold - 2;
    [[KRClient shared] sendVolume:(int)lroundf(self.volume.value * 100)];
}

- (void)volumeDone { [[KRClient shared] sendVolume:(int)lroundf(self.volume.value * 100)]; }

- (void)pressed:(KRButton *)b {
    NSString *key = b.key;
    if ([key isEqualToString:@"keyboard"]) { [self typeText]; return; }
    if ([key hasPrefix:@"Input."]) [[KRClient shared] input:key];
    else [[KRClient shared] action:key];
}

@end
