#import <UIKit/UIKit.h>

extern NSString *const KRClientChanged;      /* connection state or now-playing info changed */
extern NSString *const KRClientNeedsAuth;    /* the server answered 401 */
extern NSString *const KRClientInputRequested; /* Kodi opened a text box: userInfo title, type, value */
extern NSString *const KRClientInputFinished;  /* that text box closed again */

typedef void (^KRResultBlock)(id result, NSString *error);

/* HTTP status of a finished request. iOS 6 answers a 401 with no delegate to hand the challenge to by failing with "user cancelled authentication" (-1012) and no response, so that error counts as 401. */
static inline NSInteger KRHTTPStatus(NSURLResponse *resp, NSError *err) {
    if ([resp isKindOfClass:[NSHTTPURLResponse class]]) return [(NSHTTPURLResponse *)resp statusCode];
    return [err code] == NSURLErrorUserCancelledAuthentication ? 401 : 0;
}

/* Talks to one Kodi at a time over its JSON-RPC HTTP interface (Settings > Services > Control > "Allow remote control via HTTP").
   A server is a dictionary: name, host, port (NSNumber), user, pass. Saved servers live in NSUserDefaults. */
@interface KRClient : NSObject
+ (KRClient *)shared;

@property (nonatomic, strong, readonly) NSDictionary *server;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, copy, readonly) NSString *status;          /* "Connecting…", an error, or nil once connected */

/* now playing, refreshed every two seconds */
@property (nonatomic, readonly) BOOL hasPlayer, paused;
@property (nonatomic, copy, readonly) NSString *title, *subtitle, *thumb, *elapsedText, *totalText;
@property (nonatomic, readonly) double percent, totalSeconds;
@property (nonatomic, strong, readonly) NSNumber *playerID;      /* of the active player, nil when idle */
@property (nonatomic, readonly) int volume;                       /* 0...100 */
@property (nonatomic, readonly) BOOL muted;

- (void)connectTo:(NSDictionary *)server;       /* remembers it as the last used one */
- (void)reconnect;
- (void)call:(NSString *)method params:(NSDictionary *)params done:(KRResultBlock)done;
- (void)sendVolume:(int)v;
- (void)action:(NSString *)name;                /* Input.ExecuteAction, e.g. @"playpause" */
- (void)input:(NSString *)method;               /* Input.Up, Input.Select, ... */
- (void)loadImage:(NSString *)kodiPath done:(void (^)(UIImage *))done;   /* cached; done runs on the main thread */

/* One-off check of an address before it is saved. state: 0 Kodi answered, 1 Kodi wants a password, 2 something else answers, 3 nothing reachable */
+ (void)probeHost:(NSString *)host port:(int)port user:(NSString *)user pass:(NSString *)pass done:(void (^)(int state, NSString *message))done;

+ (NSString *)clockText:(double)seconds;   /* 3:07 or 1:02:03 */

+ (NSArray *)savedServers;
+ (void)saveServer:(NSDictionary *)server;      /* replaces a server with the same host and port */
+ (void)removeServer:(NSDictionary *)server;
+ (NSDictionary *)serverWithHost:(NSString *)host port:(int)port name:(NSString *)name;
+ (BOOL)isSame:(NSDictionary *)a as:(NSDictionary *)b;
@end
