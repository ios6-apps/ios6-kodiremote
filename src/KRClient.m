#import "KRClient.h"
#import "KRNotifier.h"

NSString *const KRClientChanged = @"KRClientChanged";
NSString *const KRClientNeedsAuth = @"KRClientNeedsAuth";
NSString *const KRClientInputRequested = @"KRClientInputRequested";
NSString *const KRClientInputFinished = @"KRClientInputFinished";

static NSString *Base64(NSData *d) {   /* NSData has no public base64 before iOS 7 */
    static const char *t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const unsigned char *b = d.bytes;
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < d.length; i += 3) {
        unsigned v = b[i] << 16 | (i + 1 < d.length ? b[i + 1] << 8 : 0) | (i + 2 < d.length ? b[i + 2] : 0);
        [s appendFormat:@"%c%c%c%c", t[v >> 18 & 63], t[v >> 12 & 63], i + 1 < d.length ? t[v >> 6 & 63] : '=', i + 2 < d.length ? t[v & 63] : '='];
    }
    return s;
}

static id nn(id o) { return o == [NSNull null] ? nil : o; }

static double KRSeconds(NSDictionary *t) {
    return [[t objectForKey:@"hours"] intValue] * 3600 + [[t objectForKey:@"minutes"] intValue] * 60 + [[t objectForKey:@"seconds"] intValue];
}

@interface KRClient ()
@property (nonatomic, strong) NSDictionary *server;
@property (nonatomic) BOOL connected, hasPlayer, paused;
@property (nonatomic, copy) NSString *status, *title, *subtitle, *thumb, *elapsedText, *totalText;
@property (nonatomic) double percent, totalSeconds;
@property (nonatomic, strong) NSNumber *playerID;
@property (nonatomic) int volume;
@property (nonatomic) BOOL muted;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL busy;
@property (nonatomic) NSInteger generation;     /* bumped on every (re)connect so late answers of the old server are dropped */
@property (nonatomic, strong) NSMutableDictionary *images;
@property (nonatomic, strong) KRNotifier *notifier;
@end

@implementation KRClient

+ (KRClient *)shared {
    static KRClient *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [[KRClient alloc] init]; });
    return c;
}

- (id)init {
    if ((self = [super init])) {
        self.images = [NSMutableDictionary dictionary];
        self.notifier = [[KRNotifier alloc] init];
        __unsafe_unretained KRClient *me = self;
        self.notifier.onEvent = ^(NSString *method, NSDictionary *params) {
            NSDictionary *d = [params objectForKey:@"data"];
            if ([method isEqualToString:@"Input.OnInputRequested"] && [d isKindOfClass:[NSDictionary class]])
                [[NSNotificationCenter defaultCenter] postNotificationName:KRClientInputRequested object:me userInfo:d];
            else if ([method isEqualToString:@"Input.OnInputFinished"])
                [[NSNotificationCenter defaultCenter] postNotificationName:KRClientInputFinished object:me];
        };
        self.status = @"No server selected";
        self.timer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(poll) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)changed { [[NSNotificationCenter defaultCenter] postNotificationName:KRClientChanged object:self]; }

- (void)connectTo:(NSDictionary *)server {
    self.server = server;
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u setObject:server forKey:@"kr.last"]; [u synchronize];
    [self reconnect];
}

- (void)reconnect {
    self.generation++;
    self.connected = NO; self.hasPlayer = NO; self.title = self.subtitle = self.thumb = self.elapsedText = self.totalText = nil; self.percent = 0; self.totalSeconds = 0; self.playerID = nil;
    self.status = self.server ? @"Connecting…" : @"No server selected";
    self.busy = NO;
    if (self.server) [self.notifier startWithHost:[self.server objectForKey:@"host"] port:9090]; else [self.notifier stop];
    [self changed];
    [self poll];
}

#pragma mark requests

- (NSMutableURLRequest *)requestFor:(NSString *)path timeout:(NSTimeInterval)t {
    NSDictionary *sv = self.server;
    NSString *url = [NSString stringWithFormat:@"http://%@:%d%@", [sv objectForKey:@"host"], [[sv objectForKey:@"port"] intValue], path];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:t];
    if ([[sv objectForKey:@"user"] length]) {
        NSString *cred = [NSString stringWithFormat:@"%@:%@", [sv objectForKey:@"user"], [sv objectForKey:@"pass"] ?: @""];
        [r setValue:[@"Basic " stringByAppendingString:Base64([cred dataUsingEncoding:NSUTF8StringEncoding])] forHTTPHeaderField:@"Authorization"];
    }
    return r;
}

- (void)call:(NSString *)method params:(NSDictionary *)params done:(KRResultBlock)done {
    if (!self.server) { if (done) done(nil, @"No server selected"); return; }
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"2.0", @"jsonrpc", method, @"method", [NSNumber numberWithInt:1], @"id", nil];
    if (params) [body setObject:params forKey:@"params"];
    NSMutableURLRequest *r = [self requestFor:@"/jsonrpc" timeout:4];
    [r setHTTPMethod:@"POST"];
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [r setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:NULL]];
    NSInteger gen = self.generation;
    [NSURLConnection sendAsynchronousRequest:r queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (gen != self.generation) return;
        NSInteger code = KRHTTPStatus(resp, err);
        if (![method isEqualToString:@"Application.GetProperties"] && ![method isEqualToString:@"Player.GetProperties"] && ![method isEqualToString:@"Player.GetItem"] && ![method isEqualToString:@"Player.GetActivePlayers"])
            NSLog(@"KRcall %@ -> HTTP %ld err=%ld", method, (long)code, (long)[err code]);   /* never the body or the credentials */
        if (code == 401) {
            [[NSNotificationCenter defaultCenter] postNotificationName:KRClientNeedsAuth object:self];
            if (done) done(nil, @"Wrong or missing user name / password");
            return;
        }
        if (err || !data) {
            if (done) done(nil, [err code] == NSURLErrorTimedOut ? @"No answer. Is Kodi running and on the same network?" :
                           @"Can't reach Kodi. In Kodi enable Settings > Services > Control > Allow remote control via HTTP.");
            return;
        }
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if (![json isKindOfClass:[NSDictionary class]]) { if (done) done(nil, @"That doesn't look like Kodi."); return; }
        NSDictionary *e = nn([json objectForKey:@"error"]);
        if (e) { if (done) done(nil, nn([e objectForKey:@"message"]) ?: @"Kodi error"); return; }
        if (done) done(nn([json objectForKey:@"result"]) ?: [NSNull null], nil);
    }];
}

+ (void)probeHost:(NSString *)host port:(int)port user:(NSString *)user pass:(NSString *)pass done:(void (^)(int, NSString *))done {
    NSString *url = [NSString stringWithFormat:@"http://%@:%d/jsonrpc", host, port];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:6];
    r.HTTPMethod = @"POST";
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    r.HTTPBody = [@"{\"jsonrpc\":\"2.0\",\"method\":\"JSONRPC.Ping\",\"id\":1}" dataUsingEncoding:NSUTF8StringEncoding];
    if (user.length) {
        NSString *cred = [NSString stringWithFormat:@"%@:%@", user, pass ?: @""];
        [r setValue:[@"Basic " stringByAppendingString:Base64([cred dataUsingEncoding:NSUTF8StringEncoding])] forHTTPHeaderField:@"Authorization"];
    }
    [NSURLConnection sendAsynchronousRequest:r queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSInteger code = KRHTTPStatus(resp, err);
        NSString *where = [NSString stringWithFormat:@"%@:%d", host, port];
        if (code == 401) { done(1, [NSString stringWithFormat:@"Kodi at %@ asks for a user name and password.", where]); return; }
        if (code) {
            NSString *body = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
            if (code == 200 && [body rangeOfString:@"pong"].location != NSNotFound) { done(0, nil); return; }
            done(2, [NSString stringWithFormat:@"Something answers at %@ (HTTP %ld) but it is not Kodi's remote control. Kodi's port is set in Settings > Services > Control, 8080 by default.", where, (long)code]);
            return;
        }
        NSString *why = [err code] == NSURLErrorTimedOut ? @"No answer in 6 seconds. Check the address, and that the phone and Kodi are on the same Wi-Fi."
            : [NSString stringWithFormat:@"Nothing is listening at %@ (%@). In Kodi turn on Settings > Services > Control > Allow remote control via HTTP.", where, [err localizedDescription]];
        done(3, why);
    }];
}

- (void)sendVolume:(int)v {
    self.volume = MAX(0, MIN(100, v));
    [self call:@"Application.SetVolume" params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:self.volume] forKey:@"volume"] done:nil];
}

+ (NSString *)clockText:(double)sec {
    int t = (int)sec, h = t / 3600, m = t / 60 % 60, s = t % 60;
    return h ? [NSString stringWithFormat:@"%d:%02d:%02d", h, m, s] : [NSString stringWithFormat:@"%d:%02d", m, s];
}

- (void)action:(NSString *)name { [self call:@"Input.ExecuteAction" params:[NSDictionary dictionaryWithObject:name forKey:@"action"] done:nil]; }
- (void)input:(NSString *)method { [self call:method params:nil done:nil]; }

#pragma mark polling

- (void)poll {
    if (!self.server || self.busy) return;
    self.busy = YES;
    NSInteger gen = self.generation;
    [self call:@"Application.GetProperties" params:[NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:@"volume", @"muted", nil] forKey:@"properties"] done:^(id app, NSString *appErr) {
      if (gen != self.generation) return;
      if (!appErr && [app isKindOfClass:[NSDictionary class]]) {
          self.volume = [[app objectForKey:@"volume"] intValue];
          self.muted = [[app objectForKey:@"muted"] boolValue];
      }
      [self call:@"Player.GetActivePlayers" params:nil done:^(id result, NSString *err) {
        if (gen != self.generation) return;
        if (appErr || err) {
            err = err ?: appErr;
            self.busy = NO;
            if (self.connected || ![self.status isEqualToString:err]) { self.connected = NO; self.hasPlayer = NO; self.status = err; [self changed]; }
            return;
        }
        BOOL was = self.connected;
        self.connected = YES; self.status = nil;
        NSArray *players = [result isKindOfClass:[NSArray class]] ? result : nil;
        if (!players.count) {
            BOOL had = self.hasPlayer;
            self.hasPlayer = NO; self.playerID = nil; self.busy = NO;
            if (had || !was) [self changed];
            return;
        }
        NSNumber *pid = [[players objectAtIndex:0] objectForKey:@"playerid"];
        self.playerID = pid;
        [self call:@"Player.GetItem" params:[NSDictionary dictionaryWithObjectsAndKeys:pid, @"playerid",
                                             [NSArray arrayWithObjects:@"title", @"artist", @"album", @"showtitle", @"season", @"episode", @"thumbnail", nil], @"properties", nil]
              done:^(id item, NSString *e1) {
            if (gen != self.generation) return;
            NSDictionary *it = [[item isKindOfClass:[NSDictionary class]] ? item : nil objectForKey:@"item"];
            [self call:@"Player.GetProperties" params:[NSDictionary dictionaryWithObjectsAndKeys:pid, @"playerid",
                                                       [NSArray arrayWithObjects:@"speed", @"percentage", @"time", @"totaltime", nil], @"properties", nil]
                  done:^(id props, NSString *e2) {
                if (gen != self.generation) return;
                self.busy = NO;
                NSString *title = nn([it objectForKey:@"title"]);
                if (!title.length) title = nn([it objectForKey:@"label"]);
                NSString *sub = nil;
                NSArray *artists = nn([it objectForKey:@"artist"]);
                if ([artists isKindOfClass:[NSArray class]] && artists.count) sub = [artists componentsJoinedByString:@", "];
                if (!sub.length) sub = nn([it objectForKey:@"showtitle"]);
                if ([[it objectForKey:@"season"] intValue] > 0) sub = [NSString stringWithFormat:@"%@  S%02dE%02d", sub ?: @"", [[it objectForKey:@"season"] intValue], [[it objectForKey:@"episode"] intValue]];
                if (!sub.length) sub = nn([it objectForKey:@"album"]);
                NSDictionary *p = [props isKindOfClass:[NSDictionary class]] ? props : nil;
                self.hasPlayer = YES;
                self.title = title.length ? title : @"Playing";
                self.subtitle = sub;
                self.thumb = nn([it objectForKey:@"thumbnail"]);
                self.paused = [[p objectForKey:@"speed"] intValue] == 0;
                self.percent = [[p objectForKey:@"percentage"] doubleValue];
                self.totalSeconds = KRSeconds([p objectForKey:@"totaltime"]);
                self.elapsedText = [KRClient clockText:KRSeconds([p objectForKey:@"time"])];
                self.totalText = [KRClient clockText:self.totalSeconds];
                [self changed];
            }];
        }];
      }];
    }];
}

#pragma mark images

- (void)loadImage:(NSString *)path done:(void (^)(UIImage *))done {
    if (!path.length || !self.server) return;
    UIImage *hit = [self.images objectForKey:path];
    if (hit) { done(hit); return; }
    NSString *esc = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)path, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
    NSMutableURLRequest *r = [self requestFor:[@"/image/" stringByAppendingString:esc] timeout:8];
    NSInteger gen = self.generation;
    [NSURLConnection sendAsynchronousRequest:r queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (gen != self.generation || err || !data) return;
        UIImage *im = [UIImage imageWithData:data];
        if (!im) return;
        [self.images setObject:im forKey:path];
        done(im);
    }];
}

#pragma mark saved servers

+ (NSArray *)savedServers { return [[NSUserDefaults standardUserDefaults] arrayForKey:@"kr.servers"] ?: [NSArray array]; }

+ (BOOL)isSame:(NSDictionary *)a as:(NSDictionary *)b {
    return [[a objectForKey:@"host"] isEqual:[b objectForKey:@"host"]] && [[a objectForKey:@"port"] intValue] == [[b objectForKey:@"port"] intValue];
}

+ (void)saveServer:(NSDictionary *)server {
    NSMutableArray *a = [NSMutableArray array];
    BOOL done = NO;
    for (NSDictionary *s in [self savedServers]) {
        if ([self isSame:s as:server]) { [a addObject:server]; done = YES; } else [a addObject:s];
    }
    if (!done) [a addObject:server];
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u setObject:a forKey:@"kr.servers"]; [u synchronize];
}

+ (void)removeServer:(NSDictionary *)server {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *s in [self savedServers]) if (![self isSame:s as:server]) [a addObject:s];
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u setObject:a forKey:@"kr.servers"]; [u synchronize];
}

+ (NSDictionary *)serverWithHost:(NSString *)host port:(int)port name:(NSString *)name {
    return [NSDictionary dictionaryWithObjectsAndKeys:host, @"host", [NSNumber numberWithInt:port], @"port", name ?: host, @"name", @"", @"user", @"", @"pass", nil];
}

@end
