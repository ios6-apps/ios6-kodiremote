/* Just enough of UIKit for KRClient.m and KRNotifier.m to compile as a plain macOS command-line tool.
   Those two files only use UIImage and the become-active notification; everything else of the app is UI and is not tested here. */
#import <Foundation/Foundation.h>

@interface UIImage : NSObject
@property (nonatomic, readonly) NSData *data;
+ (UIImage *)imageWithData:(NSData *)data;   /* nil unless the data is a PNG */
@end

extern NSString *const UIApplicationDidBecomeActiveNotification;
