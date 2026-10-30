#import <UIKit/UIKit.h>

/* In-app replacement for UIAlertView: same look as the rest of the app, and it still shows on devices where a tweak
   (noalerts) swallows UIAlertView. fields: array of dictionaries with @"text", @"placeholder", @"secure" (NSNumber), @"url" (NSNumber).
   buttons: titles, the first one cancels. The handler gets the tapped button index and the text of every field. */
typedef void (^KRPromptHandler)(NSInteger button, NSArray *texts);

@interface KRPrompt : UIView
+ (KRPrompt *)showTitle:(NSString *)title message:(NSString *)message fields:(NSArray *)fields buttons:(NSArray *)buttons handler:(KRPromptHandler)handler;
- (void)dismiss;   /* closes it without calling the handler */
@end
