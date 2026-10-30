#import <Foundation/Foundation.h>

/* Finds Kodi on the local network: Bonjour (Kodi announces itself when "Announce services to other systems" is on, the default)
   plus an optional sweep of the Wi-Fi interface's /24 subnet for Kodi's web server on ports 8080 and 80. Found servers are dictionaries like KRClient's. */
@interface KRDiscovery : NSObject
@property (nonatomic, strong, readonly) NSArray *found;
@property (nonatomic, readonly) BOOL scanning;
@property (nonatomic, copy) void (^onChange)(void);
- (void)start;          /* Bonjour, keeps running */
- (void)scanSubnet;
@property (nonatomic, copy) void (^onScanDone)(NSInteger newlyFound, NSString *prefix);
@end
