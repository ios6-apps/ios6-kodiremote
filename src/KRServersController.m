#import "KRServersController.h"
#import "KRPrompt.h"
#import "KRCards.h"
#import "KRChrome.h"
#import "KRClient.h"
#import "KRDiscovery.h"
#import "KRStyle.h"

@interface KRServersController () <KRScreen>
@property (nonatomic, strong) KRDiscovery *discovery;
@property (nonatomic, strong) NSArray *saved, *nearby;
@property (nonatomic) BOOL checking;
@end

@implementation KRServersController

- (NSString *)krTitle { return @"Servers"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:KRBackdropImage()];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = KR_CARD_H;

    UILabel *foot = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 96)];
    foot.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    foot.backgroundColor = [UIColor clearColor];
    foot.textAlignment = NSTextAlignmentCenter;
    foot.numberOfLines = 4;
    foot.font = KRFont(@"HelveticaNeue", 12);
    foot.textColor = KR_DIM;
    foot.text = @"Kodi needs  Settings > Services > Control >\nAllow remote control via HTTP  to be on.";
    self.tableView.tableFooterView = foot;

    self.discovery = [[KRDiscovery alloc] init];
    __unsafe_unretained KRServersController *me = self;
    self.discovery.onChange = ^{ [me rebuild]; };
    self.discovery.onScanDone = ^(NSInteger fresh, NSString *prefix) {
        if (fresh || me.discovery.found.count) return;
        [KRPrompt showTitle:@"No Kodi found" message:[NSString stringWithFormat:@"Nothing on %@x answers as Kodi on port 8080 or 80. In Kodi turn on Settings > Services > Control > Allow remote control via HTTP, then scan again. Or use Add by address if Kodi uses another port.", prefix]
                     fields:nil buttons:[NSArray arrayWithObject:@"OK"] handler:nil];
    };
    [self.discovery start];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuild) name:KRClientChanged object:nil];
    [self rebuild];
}

- (void)krWillShow { if (self.isViewLoaded) [self rebuild]; }

- (void)rebuild {
    self.saved = [KRClient savedServers];
    NSMutableArray *n = [NSMutableArray array];
    for (NSDictionary *f in self.discovery.found) {
        BOOL known = NO;
        for (NSDictionary *s in self.saved) if ([KRClient isSame:s as:f]) known = YES;
        if (!known) [n addObject:f];
    }
    self.nearby = n;
    [self.tableView reloadData];
}

#pragma mark table: 0 saved, 1 found nearby, 2 actions

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 3; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return s == 0 ? self.saved.count : s == 1 ? self.nearby.count : 2;
}

- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return [self tableView:t numberOfRowsInSection:s] && s < 2 ? 30 : 0; }

- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s { return 0.01; }

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    if (s >= 2 || ![self tableView:t numberOfRowsInSection:s]) return nil;
    return KRSectionHeader(s == 0 ? @"My servers" : @"Found on your network", t.bounds.size.width);
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    KRCardCell *cell = [t dequeueReusableCellWithIdentifier:@"server"];
    if (!cell) cell = [[KRCardCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"server"];
    cell.image = nil;
    cell.iconKind = 2;
    if (ip.section == 2) {
        BOOL scan = ip.row == 0;
        cell.title = scan ? (self.discovery.scanning ? @"Scanning…" : @"Scan network") : (self.checking ? @"Checking…" : @"Add by address");
        cell.subtitle = scan ? @"Looks for Kodi on port 8080 and 80" : @"Type an IP address or host name";
        cell.badge = KRAccessoryPlus;
    } else {
        NSDictionary *s = [(ip.section == 0 ? self.saved : self.nearby) objectAtIndex:ip.row];
        KRClient *k = [KRClient shared];
        BOOL cur = ip.section == 0 && k.server && [KRClient isSame:s as:k.server];
        cell.title = [s objectForKey:@"name"];
        NSString *addr = [NSString stringWithFormat:@"%@:%d", [s objectForKey:@"host"], [[s objectForKey:@"port"] intValue]];
        cell.subtitle = cur ? [NSString stringWithFormat:@"%@  ·  %@", addr, k.connected ? @"Connected" : (k.status ?: @"Connecting…")] : addr;
        cell.badge = cur && k.connected ? KRAccessoryCheck : ip.section == 1 ? KRAccessoryPlus : KRAccessoryNone;
    }
    [cell reloadCard];
    return cell;
}

- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip { return ip.section == 0; }

- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style == UITableViewCellEditingStyleDelete) { [KRClient removeServer:[self.saved objectAtIndex:ip.row]]; [self rebuild]; }
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 2) {
        if (ip.row == 0) { [self.discovery scanSubnet]; [self rebuild]; }
        else [self askAddress];
        return;
    }
    NSDictionary *s = [(ip.section == 0 ? self.saved : self.nearby) objectAtIndex:ip.row];
    [self use:s];
}

- (void)use:(NSDictionary *)s {
    [KRClient saveServer:s];
    [[KRClient shared] connectTo:s];
    [[KRRootController shared] selectTab:0];
}

- (void)askAddress {
    [KRPrompt showTitle:@"Add server" message:@"IP address or host name, optionally with :port (default 8080)"
                 fields:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"192.168.1.20", @"placeholder", [NSNumber numberWithBool:YES], @"url", nil]]
                buttons:[NSArray arrayWithObjects:@"Cancel", @"Connect", nil]
                handler:^(NSInteger i, NSArray *texts) {
        if (i == 0) return;
        NSString *text = [[texts objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!text.length) return;
        if ([text hasPrefix:@"http://"]) text = [text substringFromIndex:7];
        NSRange sl = [text rangeOfString:@"/"];
        if (sl.location != NSNotFound) text = [text substringToIndex:sl.location];
        NSArray *p = [text componentsSeparatedByString:@":"];
        int port = p.count > 1 ? [[p objectAtIndex:1] intValue] : 8080;
        [self check:[KRClient serverWithHost:[p objectAtIndex:0] port:port ?: 8080 name:[p objectAtIndex:0]] user:nil pass:nil];
    }];
}

/* probe first, so a wrong address or a switched-off web server is explained instead of silently saved */
- (void)check:(NSDictionary *)server user:(NSString *)user pass:(NSString *)pass {
    self.checking = YES;
    [self rebuild];
    NSString *host = [server objectForKey:@"host"];
    int port = [[server objectForKey:@"port"] intValue];
    [KRClient probeHost:host port:port user:user pass:pass done:^(int state, NSString *msg) {
        self.checking = NO;
        [self rebuild];
        if (state == 0) {
            NSMutableDictionary *s = [NSMutableDictionary dictionaryWithDictionary:server];
            if (user.length) { [s setObject:user forKey:@"user"]; [s setObject:pass ?: @"" forKey:@"pass"]; }
            [self use:s];
        } else if (state == 1) {
            [KRPrompt showTitle:user.length ? @"Wrong user name or password" : @"Kodi asks for a password" message:msg
                         fields:[NSArray arrayWithObjects:
                                 [NSDictionary dictionaryWithObjectsAndKeys:user.length ? user : @"kodi", @"text", @"user name", @"placeholder", nil],
                                 [NSDictionary dictionaryWithObjectsAndKeys:@"password", @"placeholder", [NSNumber numberWithBool:YES], @"secure", nil], nil]
                        buttons:[NSArray arrayWithObjects:@"Cancel", @"Connect", nil]
                        handler:^(NSInteger i, NSArray *texts) {
                if (i == 0) return;
                [self check:server user:[texts objectAtIndex:0] pass:[texts objectAtIndex:1]];
            }];
        } else {
            [KRPrompt showTitle:@"Can't reach Kodi" message:msg fields:nil
                        buttons:[NSArray arrayWithObjects:@"Cancel", @"Try again", nil]
                        handler:^(NSInteger i, NSArray *texts) { if (i == 1) [self askAddress]; }];
        }
    }];
}

@end
