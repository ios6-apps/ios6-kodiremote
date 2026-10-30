#import <UIKit/UIKit.h>
#import "KRChrome.h"
#import "KRClient.h"
#import "KRRemoteController.h"
#import "KRAddonsController.h"
#import "KRServersController.h"
#import "KRPrompt.h"

@interface KRAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic) BOOL asking;
@property (nonatomic, strong) KRPrompt *inputPrompt;
@end

@implementation KRAppDelegate

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [app setStatusBarStyle:UIStatusBarStyleBlackOpaque];
    [app setIdleTimerDisabled:NO];
    NSArray *tabs = [NSArray arrayWithObjects:
        [NSDictionary dictionaryWithObjectsAndKeys:@"Remote", @"title", [NSNumber numberWithInt:0], @"icon", [[KRRemoteController alloc] init], @"vc", nil],
        [NSDictionary dictionaryWithObjectsAndKeys:@"Add-ons", @"title", [NSNumber numberWithInt:1], @"icon", [[KRAddonsController alloc] initWithStyle:UITableViewStylePlain], @"vc", nil],
        [NSDictionary dictionaryWithObjectsAndKeys:@"Servers", @"title", [NSNumber numberWithInt:2], @"icon", [[KRServersController alloc] initWithStyle:UITableViewStylePlain], @"vc", nil], nil];
    KRRootController *root = [[KRRootController alloc] initWithTabs:tabs];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(needsAuth) name:KRClientNeedsAuth object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputRequested:) name:KRClientInputRequested object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputFinished) name:KRClientInputFinished object:nil];

    NSDictionary *last = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"kr.last"];
#ifdef KR_PREVIEW   /* simulator: KR_HOST=host:port connects to that server, KR_TAB picks the tab */
    if (getenv("KR_HOST")) {
        NSArray *p = [[NSString stringWithUTF8String:getenv("KR_HOST")] componentsSeparatedByString:@":"];
        last = [KRClient serverWithHost:[p objectAtIndex:0] port:[[p objectAtIndex:1] intValue] name:getenv("KR_NAME") ? [NSString stringWithUTF8String:getenv("KR_NAME")] : @"Living Room"];
        [KRClient saveServer:last];
    }
    if (getenv("KR_TAB")) [root selectTab:atoi(getenv("KR_TAB"))];
    if (getenv("KR_PROMPT")) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [KRPrompt showTitle:@"Add server" message:@"IP address or host name, optionally with :port (default 8080)"
                     fields:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"192.168.1.20", @"placeholder", nil]]
                    buttons:[NSArray arrayWithObjects:@"Cancel", @"Connect", nil] handler:nil];
    });
#endif
    if (last) [[KRClient shared] connectTo:last];
    else [root selectTab:2];   /* nothing yet: start on the server list */
    return YES;
}

/* Kodi opened a text box (search, password…): offer it on the phone, whichever tab is showing */
- (void)inputRequested:(NSNotification *)n {
    NSString *type = [[n.userInfo objectForKey:@"type"] description] ?: @"keyboard";
    BOOL secret = [type rangeOfString:@"password"].location != NSNotFound;
    if (!secret && ![type isEqualToString:@"keyboard"] && ![type isEqualToString:@"number"] && ![type isEqualToString:@"ipaddress"]) return;   /* date, time: use Kodi's own */
    [self.inputPrompt dismiss];
    NSString *title = [[n.userInfo objectForKey:@"title"] description];
    NSMutableDictionary *field = [NSMutableDictionary dictionaryWithObject:[[n.userInfo objectForKey:@"value"] description] ?: @"" forKey:@"text"];
    if (secret) [field setObject:[NSNumber numberWithBool:YES] forKey:@"secure"];
    if ([type isEqualToString:@"number"] || [type isEqualToString:@"ipaddress"]) [field setObject:[NSNumber numberWithBool:YES] forKey:@"url"];
    __unsafe_unretained KRAppDelegate *me = self;
    self.inputPrompt = [KRPrompt showTitle:title.length ? title : @"Kodi asks for text" message:nil fields:[NSArray arrayWithObject:field]
                                   buttons:[NSArray arrayWithObjects:@"Cancel", @"Send", nil]
                                   handler:^(NSInteger i, NSArray *texts) {
        me.inputPrompt = nil;
        if (i == 0) { [[KRClient shared] input:@"Input.Back"]; return; }
        [[KRClient shared] call:@"Input.SendText" params:[NSDictionary dictionaryWithObjectsAndKeys:[texts objectAtIndex:0], @"text", [NSNumber numberWithBool:YES], @"done", nil] done:nil];
    }];
}

/* answered on the TV, or cancelled there */
- (void)inputFinished { [self.inputPrompt dismiss]; self.inputPrompt = nil; }

- (void)needsAuth {
    if (self.asking) return;
    self.asking = YES;
    [KRPrompt showTitle:@"Kodi asks for a password" message:@"Same user name and password as in Kodi's web server settings"
                 fields:[NSArray arrayWithObjects:
                         [NSDictionary dictionaryWithObjectsAndKeys:@"kodi", @"text", @"user name", @"placeholder", nil],
                         [NSDictionary dictionaryWithObjectsAndKeys:@"password", @"placeholder", [NSNumber numberWithBool:YES], @"secure", nil], nil]
                buttons:[NSArray arrayWithObjects:@"Cancel", @"Connect", nil]
                handler:^(NSInteger i, NSArray *texts) {
        self.asking = NO;
        if (i == 0) return;
        NSMutableDictionary *s = [NSMutableDictionary dictionaryWithDictionary:[KRClient shared].server];
        [s setObject:[texts objectAtIndex:0] forKey:@"user"];
        [s setObject:[texts objectAtIndex:1] forKey:@"pass"];
        [KRClient saveServer:s];
        [[KRClient shared] connectTo:s];
    }];
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([KRAppDelegate class]));
    }
}
