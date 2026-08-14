#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>

static CFMachPortRef activeEventTap = NULL;

static void reverseVerticalScroll(CGEventRef event) {
    int64_t lineDelta = CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1
    );
    double fixedDelta = CGEventGetDoubleValueField(
        event,
        kCGScrollWheelEventFixedPtDeltaAxis1
    );
    int64_t pointDelta = CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventPointDeltaAxis1
    );

    CGEventSetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1,
        -lineDelta
    );
    CGEventSetDoubleValueField(
        event,
        kCGScrollWheelEventFixedPtDeltaAxis1,
        -fixedDelta
    );
    CGEventSetIntegerValueField(
        event,
        kCGScrollWheelEventPointDeltaAxis1,
        -pointDelta
    );
}

static CGEventRef scrollEventCallback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void *userInfo
) {
    (void)proxy;

    (void)userInfo;

    if (type == kCGEventTapDisabledByTimeout && activeEventTap != NULL) {
        CGEventTapEnable(activeEventTap, true);
        return event;
    }

    if (type != kCGEventScrollWheel) {
        return event;
    }

    bool isContinuous = CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventIsContinuous
    ) != 0;

    if (!isContinuous) {
        reverseVerticalScroll(event);
    }

    return event;
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, assign) CFMachPortRef eventTap;
@property(nonatomic, assign) CFRunLoopSourceRef runLoopSource;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self buildMenu];
    [self requestAccessibilityPermission];

    if (![self startEventTap]) {
        self.statusItem.button.toolTip =
            @"Accessibility permission is required";
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;

    if (self.runLoopSource != NULL) {
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            self.runLoopSource,
            kCFRunLoopCommonModes
        );
        CFRelease(self.runLoopSource);
        self.runLoopSource = NULL;
    }

    if (self.eventTap != NULL) {
        CFMachPortInvalidate(self.eventTap);
        CFRelease(self.eventTap);
        self.eventTap = NULL;
        activeEventTap = NULL;
    }
}

- (void)buildMenu {
    self.statusItem = [[NSStatusBar systemStatusBar]
        statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = [NSImage
        imageWithSystemSymbolName:@"arrow.up.arrow.down"
        accessibilityDescription:@"Mouse Scroll Reverser"];

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Mouse Scroll Reverser"];
    NSMenuItem *status = [[NSMenuItem alloc]
        initWithTitle:@"Mouse wheel reversal is active"
        action:nil
        keyEquivalent:@""];
    status.enabled = NO;
    [menu addItem:status];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [[NSMenuItem alloc]
        initWithTitle:@"Quit"
        action:@selector(quit:)
        keyEquivalent:@"q"];
    quit.target = self;
    [menu addItem:quit];
    self.statusItem.menu = menu;
}

- (void)requestAccessibilityPermission {
    NSDictionary *options = @{
        (__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES
    };
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (BOOL)startEventTap {
    CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
    self.eventTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        mask,
        scrollEventCallback,
        NULL
    );
    if (self.eventTap == NULL) {
        return NO;
    }
    activeEventTap = self.eventTap;

    self.runLoopSource = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault,
        self.eventTap,
        0
    );
    if (self.runLoopSource == NULL) {
        CFRelease(self.eventTap);
        self.eventTap = NULL;
        activeEventTap = NULL;
        return NO;
    }

    CFRunLoopAddSource(
        CFRunLoopGetMain(),
        self.runLoopSource,
        kCFRunLoopCommonModes
    );

    CGEventTapEnable(self.eventTap, true);
    return YES;
}

- (void)quit:(id)sender {
    (void)sender;
    [NSApp terminate:nil];
}

@end

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
