#import <UIKit/UIKit.h>

NSString *const UIApplicationDidBecomeActiveNotification = @"UIApplicationDidBecomeActiveNotification";

@implementation UIImage
+ (UIImage *)imageWithData:(NSData *)data {
    static const unsigned char magic[8] = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'};
    if (data.length < 8 || memcmp(data.bytes, magic, 8)) return nil;
    UIImage *i = [[UIImage alloc] init];
    i->_data = data;
    return i;
}
@end
