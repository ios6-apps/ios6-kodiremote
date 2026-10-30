/* Tests of the app's networking core (KRClient, KRNotifier) against tools/mock_kodi.py, on the Mac.
   Usage: kr_tests <open mock port> <mock with user "kodi" / password "secret" port> <plain HTTP server that is not Kodi: port> <notifications 0|1>
   tests/run.sh starts the servers and builds this; see there. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "KRClient.h"

static int fails = 0, checks = 0;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; NSLog(@"FAIL line %d: %@", __LINE__, [NSString stringWithFormat:@"" __VA_ARGS__]); } } while (0)

static BOOL waitFor(NSTimeInterval timeout, BOOL (^cond)(void)) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!cond()) {
        if ([end timeIntervalSinceNow] < 0) return NO;
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return YES;
}

static NSString *mockURL(int port, NSString *path) { return [NSString stringWithFormat:@"http://127.0.0.1:%d%@", port, path]; }
static NSArray *mockLog(int port) {
    NSData *d = [NSData dataWithContentsOfURL:[NSURL URLWithString:mockURL(port, @"/mock/log")]];
    return d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL] : nil;
}
static NSDictionary *lastCall(int port, NSString *method) {
    for (NSDictionary *c in [mockLog(port) reverseObjectEnumerator]) if ([[c objectForKey:@"method"] isEqualToString:method]) return c;
    return nil;
}
static void post(int port, NSString *path, NSString *json) {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:mockURL(port, path)]];
    r.HTTPMethod = @"POST"; r.HTTPBody = [json dataUsingEncoding:NSUTF8StringEncoding];
    [NSURLConnection sendSynchronousRequest:r returningResponse:NULL error:NULL];
}
static NSDictionary *server(int port, NSString *user, NSString *pass) {
    NSMutableDictionary *s = [NSMutableDictionary dictionaryWithDictionary:[KRClient serverWithHost:@"127.0.0.1" port:port name:@"Test"]];
    if (user) { [s setObject:user forKey:@"user"]; [s setObject:pass forKey:@"pass"]; }
    return s;
}

static void testPureHelpers(void) {
    NSHTTPURLResponse *ok = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://x/"] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    NSHTTPURLResponse *denied = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://x/"] statusCode:401 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    NSError *cancelled = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUserCancelledAuthentication userInfo:nil];
    NSError *refused = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil];
    CHECK(KRHTTPStatus(ok, nil) == 200, "status of a 200");
    CHECK(KRHTTPStatus(denied, nil) == 401, "status of a 401");
    CHECK(KRHTTPStatus(nil, cancelled) == 401, "iOS 6 reports a 401 as -1012 without a response");
    CHECK(KRHTTPStatus(nil, refused) == 0, "a refused connection has no status");
    CHECK(KRHTTPStatus(nil, nil) == 0, "no response, no error");

    CHECK([[KRClient clockText:0] isEqualToString:@"0:00"], "%@", [KRClient clockText:0]);
    CHECK([[KRClient clockText:187] isEqualToString:@"3:07"], "%@", [KRClient clockText:187]);
    CHECK([[KRClient clockText:3723] isEqualToString:@"1:02:03"], "%@", [KRClient clockText:3723]);
}

static void testSavedServers(void) {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u removeObjectForKey:@"kr.servers"];
    CHECK([KRClient savedServers].count == 0, "starts empty");
    NSDictionary *a = [KRClient serverWithHost:@"10.0.0.5" port:8080 name:@"Den"];
    CHECK([[a objectForKey:@"name"] isEqualToString:@"Den"] && [[a objectForKey:@"user"] isEqualToString:@""], "defaults of a new server");
    CHECK([[[KRClient serverWithHost:@"10.0.0.5" port:8080 name:nil] objectForKey:@"name"] isEqualToString:@"10.0.0.5"], "name defaults to the host");
    [KRClient saveServer:a];
    [KRClient saveServer:[KRClient serverWithHost:@"10.0.0.5" port:8081 name:@"Den (other port)"]];
    CHECK([KRClient savedServers].count == 2, "same host, other port is another server");
    NSMutableDictionary *renamed = [NSMutableDictionary dictionaryWithDictionary:a];
    [renamed setObject:@"Living room" forKey:@"name"]; [renamed setObject:@"kodi" forKey:@"user"];
    [KRClient saveServer:renamed];
    NSArray *s = [KRClient savedServers];
    CHECK(s.count == 2 && [[[s objectAtIndex:0] objectForKey:@"name"] isEqualToString:@"Living room"] && [[[s objectAtIndex:0] objectForKey:@"user"] isEqualToString:@"kodi"], "saving again replaces in place");
    CHECK([KRClient isSame:a as:renamed], "same host and port is the same server whatever the name");
    CHECK(![KRClient isSame:a as:[s objectAtIndex:1]], "other port is not");
    [KRClient removeServer:a];
    s = [KRClient savedServers];
    CHECK(s.count == 1 && [[[s objectAtIndex:0] objectForKey:@"port"] intValue] == 8081, "remove matches host and port");
    [u removeObjectForKey:@"kr.servers"];
}

static void testProbe(int open, int auth, int notKodi) {
    __block int state = -1; __block NSString *msg = nil;
    void (^probe)(int, NSString *, NSString *) = ^(int port, NSString *user, NSString *pass) {
        state = -1; msg = nil;
        [KRClient probeHost:@"127.0.0.1" port:port user:user pass:pass done:^(int st, NSString *m) { state = st; msg = m; }];
        waitFor(10, ^BOOL { return state != -1; });
    };
    probe(open, nil, nil);
    CHECK(state == 0, "Kodi answers: state %d %@", state, msg);
    probe(auth, nil, nil);
    CHECK(state == 1, "Kodi wants a password: state %d %@", state, msg);
    probe(auth, @"kodi", @"wrong");
    CHECK(state == 1, "wrong password: state %d", state);
    probe(auth, @"kodi", @"secret");
    CHECK(state == 0, "right password: state %d %@", state, msg);
    probe(notKodi, nil, nil);
    CHECK(state == 2 && [msg rangeOfString:@"not Kodi"].location != NSNotFound, "something else answers: state %d %@", state, msg);
    probe(1, nil, nil);
    CHECK(state == 3 && [msg rangeOfString:@"Nothing is listening"].location != NSNotFound, "nothing listens: state %d %@", state, msg);
}

static void testClient(int open, BOOL notifications) {
    KRClient *k = [KRClient shared];
    post(open, @"/mock/reset", @"{}");
    [k connectTo:server(open, nil, nil)];
    CHECK(!k.connected && [k.status isEqualToString:@"Connecting…"], "connecting: %@", k.status);
    CHECK(waitFor(10, ^BOOL { return k.connected && k.hasPlayer && k.title.length; }), "connected with a player: %@", k.status);
    CHECK([k.title isEqualToString:@"Sintel"], "title %@", k.title);
    CHECK(k.volume == 60 && !k.muted, "volume %d muted %d", k.volume, k.muted);
    CHECK([k.playerID intValue] == 1 && !k.paused, "player %@ paused %d", k.playerID, k.paused);
    CHECK(k.percent > 20 && k.percent < 30 && [k.elapsedText hasPrefix:@"3:"], "position %@ %.1f%%", k.elapsedText, k.percent);
    CHECK([k.totalText isEqualToString:@"14:48"] && k.totalSeconds == 888, "total %@ %.0f", k.totalText, k.totalSeconds);
    CHECK([[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"kr.last"] objectForKey:@"host"] != nil, "last server remembered");

    [k input:@"Input.Up"];
    CHECK(waitFor(5, ^BOOL { return lastCall(open, @"Input.Up") != nil; }), "Input.Up reached Kodi");
    [k action:@"playpause"];
    NSDictionary *c = nil;
    CHECK(waitFor(5, ^BOOL { return lastCall(open, @"Input.ExecuteAction") != nil; }), "ExecuteAction reached Kodi");
    c = lastCall(open, @"Input.ExecuteAction");
    CHECK([[[c objectForKey:@"params"] objectForKey:@"action"] isEqualToString:@"playpause"], "action name %@", c);
    CHECK(waitFor(8, ^BOOL { return k.paused; }), "pause shows up in the next poll");
    [k action:@"mute"];
    CHECK(waitFor(8, ^BOOL { return k.muted; }), "mute shows up in the next poll");
    [k sendVolume:35];
    CHECK(k.volume == 35, "the volume follows at once");
    [k sendVolume:250];
    CHECK(k.volume == 100, "the volume is clamped: %d", k.volume);
    /* the two volume calls travel on separate connections and may reach the server in either order, so look at all of them */
    CHECK(waitFor(5, ^BOOL {
        for (NSDictionary *call in mockLog(open))
            if ([[call objectForKey:@"method"] isEqualToString:@"Application.SetVolume"] && [[[call objectForKey:@"params"] objectForKey:@"volume"] intValue] == 100) return YES;
        return NO;
    }), "SetVolume reached Kodi");

    __block NSString *err = nil; __block id res = nil; __block BOOL got = NO;
    [k call:@"No.Such" params:nil done:^(id r, NSString *e) { res = r; err = e; got = YES; }];
    CHECK(waitFor(5, ^BOOL { return got; }) && [err isEqualToString:@"Method not found."] && !res, "JSON-RPC error text is passed on: %@", err);
    got = NO; err = nil;
    [k call:@"Addons.GetAddons" params:[NSDictionary dictionaryWithObjectsAndKeys:@"video", @"content", nil] done:^(id r, NSString *e) { res = r; err = e; got = YES; }];
    CHECK(waitFor(5, ^BOOL { return got; }) && !err && [[res objectForKey:@"addons"] count] == 3, "add-on list: %@ %@", err, res);

    __block UIImage *img = nil;
    [k loadImage:@"image://demo-sintel/" done:^(UIImage *i) { img = i; }];
    CHECK(waitFor(5, ^BOOL { return img != nil; }), "cover art loads");
    __block UIImage *cached = nil;
    [k loadImage:@"image://demo-sintel/" done:^(UIImage *i) { cached = i; }];
    CHECK(cached == img, "second load comes from the cache, synchronously");

    if (notifications) {
        __block NSDictionary *info = nil; __block BOOL finished = NO;
        id t1 = [[NSNotificationCenter defaultCenter] addObserverForName:KRClientInputRequested object:nil queue:nil usingBlock:^(NSNotification *n) { info = n.userInfo; }];
        id t2 = [[NSNotificationCenter defaultCenter] addObserverForName:KRClientInputFinished object:nil queue:nil usingBlock:^(NSNotification *n) { finished = YES; }];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];   /* let the 9090 connection come up */
        /* braces and a quote inside the value must not confuse the object boundaries */
        post(open, @"/mock/notify", @"{\"method\":\"Input.OnInputRequested\",\"params\":{\"data\":{\"title\":\"Search\",\"type\":\"keyboard\",\"value\":\"{br\\\"ace}\"},\"sender\":\"xbmc\"}}");
        CHECK(waitFor(5, ^BOOL { return info != nil; }), "text box request arrives over 9090");
        CHECK([[info objectForKey:@"title"] isEqualToString:@"Search"] && [[info objectForKey:@"type"] isEqualToString:@"keyboard"] && [[info objectForKey:@"value"] isEqualToString:@"{br\"ace}"], "request content %@", info);
        post(open, @"/mock/notify", @"{\"method\":\"Input.OnInputFinished\",\"params\":{\"sender\":\"xbmc\"}}");
        CHECK(waitFor(5, ^BOOL { return finished; }), "text box closed arrives over 9090");
        [[NSNotificationCenter defaultCenter] removeObserver:t1]; [[NSNotificationCenter defaultCenter] removeObserver:t2];
    } else NSLog(@"skipped: notifications over 9090 (port 9090 was not free for the mock)");
}

static void testAuth(int auth) {
    KRClient *k = [KRClient shared];
    __block int asked = 0;
    id t = [[NSNotificationCenter defaultCenter] addObserverForName:KRClientNeedsAuth object:nil queue:nil usingBlock:^(NSNotification *n) { asked++; }];
    [k connectTo:server(auth, nil, nil)];
    CHECK(waitFor(8, ^BOOL { return asked > 0; }), "401 without credentials asks for them");
    CHECK(!k.connected && [k.status rangeOfString:@"password"].location != NSNotFound, "status %@", k.status);
    asked = 0;
    [k connectTo:server(auth, @"kodi", @"wrong")];
    CHECK(waitFor(8, ^BOOL { return asked > 0; }), "wrong password asks again");
    [k connectTo:server(auth, @"kodi", @"secret")];
    CHECK(waitFor(8, ^BOOL { return k.connected; }), "right credentials connect: %@", k.status);
    [[NSNotificationCenter defaultCenter] removeObserver:t];

    [k connectTo:server(1, nil, nil)];
    CHECK(waitFor(8, ^BOOL { return !k.connected && [k.status hasPrefix:@"Can't reach Kodi"]; }), "closed port: %@", k.status);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 5) { fprintf(stderr, "usage: kr_tests open-port auth-port not-kodi-port notifications(0|1)\n"); return 2; }
        int open = atoi(argv[1]), auth = atoi(argv[2]), notKodi = atoi(argv[3]);
        BOOL notifications = atoi(argv[4]) != 0;
        NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
        [u removeObjectForKey:@"kr.last"];
        testPureHelpers();
        testSavedServers();
        testProbe(open, auth, notKodi);
        testClient(open, notifications);
        testAuth(auth);
        [u removeObjectForKey:@"kr.last"]; [u removeObjectForKey:@"kr.servers"];
        NSLog(@"%d checks, %d failed", checks, fails);
    }
    return fails ? 1 : 0;
}
