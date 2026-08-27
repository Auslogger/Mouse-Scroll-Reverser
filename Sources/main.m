#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(void) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
        (void)delegate;
    }
    return 0;
}
