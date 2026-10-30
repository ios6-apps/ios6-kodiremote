#import "KRDiscovery.h"
#import "KRClient.h"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <netinet/in.h>

@interface KRDiscovery () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (nonatomic, strong) NSMutableArray *list, *browsers, *pending, *jobs;
@property (nonatomic) BOOL scanning;
@property (nonatomic) NSInteger outstanding, foundBefore;
@end

@implementation KRDiscovery

- (NSArray *)found { return self.list; }

- (id)init {
    if ((self = [super init])) {
        self.list = [NSMutableArray array];
        self.browsers = [NSMutableArray array];
        self.pending = [NSMutableArray array];
    }
    return self;
}

- (void)changed { if (self.onChange) self.onChange(); }

- (void)add:(NSString *)host port:(int)port name:(NSString *)name {
    NSDictionary *s = [KRClient serverWithHost:host port:port name:name];
    for (NSDictionary *f in self.list) if ([KRClient isSame:f as:s]) return;
    [self.list addObject:s];
    [self changed];
}

#pragma mark Bonjour

- (void)start {
    if (self.browsers.count) return;
    for (NSString *type in [NSArray arrayWithObjects:@"_xbmc-jsonrpc-h._tcp.", @"_xbmc-web._tcp.", nil]) {
        NSNetServiceBrowser *b = [[NSNetServiceBrowser alloc] init];
        b.delegate = self;
        [b searchForServicesOfType:type inDomain:@"local."];
        [self.browsers addObject:b];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)b didFindService:(NSNetService *)s moreComing:(BOOL)more {
    [self.pending addObject:s];
    s.delegate = self;
    [s resolveWithTimeout:6];
}

- (void)netServiceDidResolveAddress:(NSNetService *)s {
    for (NSData *a in s.addresses) {
        const struct sockaddr *sa = a.bytes;
        if (sa->sa_family != AF_INET) continue;
        char buf[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &((const struct sockaddr_in *)sa)->sin_addr, buf, sizeof buf);
        [self add:[NSString stringWithUTF8String:buf] port:(int)s.port name:s.name];
        break;
    }
    [self.pending removeObject:s];
}

- (void)netService:(NSNetService *)s didNotResolve:(NSDictionary *)e { [self.pending removeObject:s]; }

#pragma mark subnet sweep

- (NSString *)localPrefix {   /* "192.168.1." of the Wi-Fi interface */
    NSString *prefix = nil;
    struct ifaddrs *list, *p;
    if (getifaddrs(&list) != 0) return nil;
    for (p = list; p; p = p->ifa_next) {
        if (p->ifa_addr && p->ifa_addr->sa_family == AF_INET && !strcmp(p->ifa_name, "en0")) {
            char buf[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &((struct sockaddr_in *)p->ifa_addr)->sin_addr, buf, sizeof buf);
            NSString *ip = [NSString stringWithUTF8String:buf];
            NSRange r = [ip rangeOfString:@"." options:NSBackwardsSearch];
            prefix = [ip substringToIndex:r.location + 1];
        }
    }
    freeifaddrs(list);
    return prefix;
}

/* at most 24 probes in flight: hundreds of simultaneous connections make iOS 6 time most of them out, the real Kodi included */
- (void)scanSubnet {
    if (self.scanning) return;
    NSString *prefix = [self localPrefix];
    if (!prefix) return;
    self.scanning = YES;
    self.foundBefore = (NSInteger)self.list.count;
    NSMutableArray *jobs = [NSMutableArray array];
    for (int k = 0; k < 2; k++)
        for (int i = 1; i <= 254; i++) [jobs addObject:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@%d", prefix, i], [NSNumber numberWithInt:k ? 80 : 8080], nil]];
    self.jobs = jobs;
    self.outstanding = 0;
    [self changed];
    for (int w = 0; w < 24; w++) [self scanNext:prefix];
}

- (void)scanNext:(NSString *)prefix {
    if (!self.jobs.count) {
        if (self.outstanding == 0 && self.scanning) {
            self.scanning = NO;
            [self changed];
            if (self.onScanDone) self.onScanDone((NSInteger)self.list.count - self.foundBefore, prefix);
        }
        return;
    }
    NSArray *job = [self.jobs objectAtIndex:0];
    [self.jobs removeObjectAtIndex:0];
    NSString *ip = [job objectAtIndex:0];
    int port = [[job objectAtIndex:1] intValue];
    self.outstanding++;
    NSString *q = @"/jsonrpc?request=%7B%22jsonrpc%22%3A%222.0%22%2C%22method%22%3A%22JSONRPC.Ping%22%2C%22id%22%3A1%7D";
    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%d%@", ip, port, q]]
                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.5];
    [NSURLConnection sendAsynchronousRequest:r queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSInteger code = KRHTTPStatus(resp, err);
        NSString *body = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        BOOL pong = !err && [body rangeOfString:@"pong"].location != NSNotFound;
        if (pong || (code == 401 && port == 8080)) [self add:ip port:port name:[@"Kodi " stringByAppendingString:ip]];
        self.outstanding--;
        [self scanNext:prefix];
    }];
}

@end
