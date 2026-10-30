#import <Foundation/Foundation.h>

/* Kodi pushes events (a text box opened or closed on screen) over its JSON-RPC TCP port, 9090 by default
   (Settings > Services > Control > "Allow remote control by applications on other systems").
   One notification per event: method is e.g. @"Input.OnInputRequested", params the event's own dictionary. */
@interface KRNotifier : NSObject
@property (nonatomic, copy) void (^onEvent)(NSString *method, NSDictionary *params);
- (void)startWithHost:(NSString *)host port:(int)port;
- (void)stop;
@end
