#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(void) {
    @autoreleasepool {
        // create the shared app and connect the delegate
        NSApplication *application = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;

        // run until the user quits from the menu
        [application run];

        // keep the delegate alive through the run loop
        (void)delegate;
    }
    return 0;
}
