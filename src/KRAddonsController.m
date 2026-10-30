#import "KRAddonsController.h"
#import "KRCards.h"
#import "KRChrome.h"
#import "KRClient.h"
#import "KRStyle.h"

@interface KRAddonsController () <KRScreen>
@property (nonatomic, strong) KRSegmented *seg;
@property (nonatomic, strong) NSMutableDictionary *lists;      /* content kind -> addons */
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, copy) NSString *openedID;
@end

@implementation KRAddonsController

static NSArray *Kinds(void) { return [NSArray arrayWithObjects:@"video", @"audio", @"executable", nil]; }

- (NSString *)krTitle { return @"Add-ons"; }
- (UIView *)krTitleView { return self.seg; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.lists = [NSMutableDictionary dictionary];
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:KRBackdropImage()];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = KR_CARD_H;
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = KR_ACCENT;
    [self.refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];

    self.seg = [[KRSegmented alloc] initWithItems:[NSArray arrayWithObjects:@"Video", @"Music", @"Apps", nil]];
    [self.seg addTarget:self action:@selector(switched) forControlEvents:UIControlEventValueChanged];

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 90)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.status.backgroundColor = [UIColor clearColor];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.numberOfLines = 4;
    self.status.font = KRFont(@"HelveticaNeue", 14);
    self.status.textColor = KR_DIM;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionChanged) name:KRClientChanged object:nil];
    [self reload];
}

- (void)krWillShow { if (self.isViewLoaded && ![self current].count) [self reload]; }

- (NSString *)kind { return [Kinds() objectAtIndex:self.seg.selectedIndex]; }
- (NSArray *)current { return [self.lists objectForKey:[self kind]]; }

- (void)connectionChanged {
    static BOOL was;
    BOOL now = [KRClient shared].connected;
    if (now && !was) { [self.lists removeAllObjects]; [self reload]; }
    was = now;
    if (!now) [self show];
}

- (void)switched {
    if (![self current]) [self reload]; else [self show];
}

- (void)show {
    NSArray *a = [self current];
    KRClient *k = [KRClient shared];
    if (!k.connected) { self.status.text = k.server ? [NSString stringWithFormat:@"Not connected.\n%@", k.status ?: @""] : @"No server selected.\nOpen the Servers tab."; }
    else if (!a) self.status.text = @"Loading…";
    else self.status.text = a.count ? nil : @"No add-ons of this kind are installed.";
    self.tableView.tableHeaderView = self.status.text ? self.status : nil;
    [self.tableView reloadData];
}

- (void)reload {
    KRClient *k = [KRClient shared];
    NSString *kind = [self kind];
    if (!k.connected) { [self.refreshControl endRefreshing]; [self show]; return; }
    [k call:@"Addons.GetAddons" params:[NSDictionary dictionaryWithObjectsAndKeys:kind, @"content", [NSNumber numberWithBool:YES], @"enabled",
                                        [NSArray arrayWithObjects:@"name", @"summary", @"thumbnail", nil], @"properties", nil]
       done:^(id result, NSString *err) {
        [self.refreshControl endRefreshing];
        if (err) { self.status.text = [NSString stringWithFormat:@"Couldn't load add-ons.\n%@", err]; self.tableView.tableHeaderView = self.status; return; }
        NSArray *a = [result isKindOfClass:[NSDictionary class]] ? [result objectForKey:@"addons"] : nil;
        NSMutableArray *list = [NSMutableArray arrayWithArray:[a isKindOfClass:[NSArray class]] ? a : [NSArray array]];
        [list sortUsingComparator:^NSComparisonResult(NSDictionary *x, NSDictionary *y) {
            return [[x objectForKey:@"name"] caseInsensitiveCompare:[y objectForKey:@"name"]];
        }];
        [self.lists setObject:list forKey:kind];
        [self show];
    }];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [self current].count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    KRCardCell *cell = [t dequeueReusableCellWithIdentifier:@"addon"];
    if (!cell) cell = [[KRCardCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"addon"];
    NSDictionary *a = [[self current] objectAtIndex:ip.row];
    NSString *thumb = [a objectForKey:@"thumbnail"];
    cell.title = [a objectForKey:@"name"];
    cell.subtitle = [a objectForKey:@"summary"];
    cell.image = nil;
    cell.iconKind = 1;
    cell.badge = KRAccessoryGo;
    [cell reloadCard];
    if ([thumb length]) {
        [[KRClient shared] loadImage:thumb done:^(UIImage *im) {
            if (![cell.title isEqual:[a objectForKey:@"name"]]) return;   /* the cell was reused meanwhile */
            cell.image = im; [cell reloadCard];
        }];
    }
    return cell;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *a = [[self current] objectAtIndex:ip.row];
    NSString *aid = [a objectForKey:@"addonid"];
    KRClient *k = [KRClient shared];
    NSString *kind = [self kind];
    if ([kind isEqualToString:@"executable"])
        [k call:@"Addons.ExecuteAddon" params:[NSDictionary dictionaryWithObject:aid forKey:@"addonid"] done:nil];
    else   /* video / music add-ons open as their plugin folder in the matching Kodi window */
        [k call:@"GUI.ActivateWindow" params:[NSDictionary dictionaryWithObjectsAndKeys:[kind isEqualToString:@"video"] ? @"videos" : @"music", @"window",
                                              [NSArray arrayWithObject:[NSString stringWithFormat:@"plugin://%@/", aid]], @"parameters", nil] done:nil];
    [[KRRootController shared] selectTab:0];   /* straight to the remote to steer it */
}

@end
