#import "KRNotifier.h"
#import <UIKit/UIKit.h>

@interface KRNotifier () <NSStreamDelegate>
@property (nonatomic, strong) NSInputStream *in;
@property (nonatomic, strong) NSOutputStream *out;
@property (nonatomic, strong) NSMutableData *buf;
@property (nonatomic, copy) NSString *host;
@property (nonatomic) int port;
@property (nonatomic) NSInteger generation;
@end

@implementation KRNotifier

- (id)init {
    if ((self = [super init])) {
        /* the socket is dead after the app slept in the background */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(woke) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)woke { if (self.host) [self open]; }

- (void)startWithHost:(NSString *)host port:(int)port {
    self.host = host; self.port = port;
    [self open];
}

- (void)stop { self.host = nil; self.generation++; [self close]; }

- (void)close {
    self.in.delegate = nil; self.out.delegate = nil;
    [self.in close]; [self.out close];
    [self.in removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.out removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.in = nil; self.out = nil;
}

- (void)open {
    [self close];
    if (!self.host) return;
    self.generation++;
    self.buf = [NSMutableData data];
    CFReadStreamRef r = NULL; CFWriteStreamRef w = NULL;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)self.host, (UInt32)self.port, &r, &w);
    if (!r || !w) { if (r) CFRelease(r); if (w) CFRelease(w); [self retryLater]; return; }
    self.in = (__bridge_transfer NSInputStream *)r;
    self.out = (__bridge_transfer NSOutputStream *)w;
    self.in.delegate = self;
    [self.in scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.out scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.in open]; [self.out open];
}

- (void)retryLater {
    NSInteger gen = self.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 6 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (gen == self.generation && self.host) [self open];
    });
}

- (void)stream:(NSStream *)s handleEvent:(NSStreamEvent)e {
    if (s != self.in) return;
    switch (e) {
        case NSStreamEventHasBytesAvailable: {
            uint8_t chunk[2048];
            NSInteger n;
            while (self.in.hasBytesAvailable && (n = [self.in read:chunk maxLength:sizeof chunk]) > 0) [self.buf appendBytes:chunk length:n];
            [self drain];
            break;
        }
        case NSStreamEventErrorOccurred: case NSStreamEventEndEncountered:
            [self close];
            [self retryLater];
            break;
        default: break;
    }
}

/* the stream is a run of JSON objects with nothing between them: cut at the matching closing brace */
- (void)drain {
    const unsigned char *p = self.buf.bytes;
    NSUInteger len = self.buf.length, start = 0, depth = 0, used = 0;
    BOOL inStr = NO, esc = NO;
    for (NSUInteger i = 0; i < len; i++) {
        unsigned char ch = p[i];
        if (inStr) { if (esc) esc = NO; else if (ch == '\\') esc = YES; else if (ch == '"') inStr = NO; continue; }
        if (ch == '"') inStr = YES;
        else if (ch == '{') { if (depth++ == 0) start = i; }
        else if (ch == '}' && depth > 0 && --depth == 0) {
            NSData *obj = [NSData dataWithBytes:p + start length:i - start + 1];
            used = i + 1;
            id json = [NSJSONSerialization JSONObjectWithData:obj options:0 error:NULL];
            NSString *m = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"method"] : nil;
            if (m && self.onEvent) self.onEvent(m, [json objectForKey:@"params"]);
        }
    }
    if (used) [self.buf replaceBytesInRange:NSMakeRange(0, used) withBytes:NULL length:0];
    if (self.buf.length > 1 << 20) [self.buf setLength:0];
}

@end
