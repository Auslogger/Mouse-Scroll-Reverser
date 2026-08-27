#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>

static CFMachPortRef activeEventTap = NULL;
static bool reversingEnabled = true;
static NSString *const EnabledPreferenceKey = @"Enabled";

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
    if (type != kCGEventScrollWheel || !reversingEnabled) {
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

@interface AppDelegate ()
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *enabledMenuItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) NSTimer *retryTimer;
@property(nonatomic, assign) CFMachPortRef eventTap;
@property(nonatomic, assign) CFRunLoopSourceRef runLoopSource;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{ EnabledPreferenceKey: @YES }];
    reversingEnabled = [defaults boolForKey:EnabledPreferenceKey];

    [self buildMenu];
    [self requestAccessibilityPermission];

    if ([self startEventTap]) {
        self.statusMenuItem.title = @"Mouse wheel reversal is active";
    } else {
        self.statusMenuItem.title = @"Accessibility permission is required";
        self.statusItem.button.toolTip =
            @"Accessibility permission is required";
    }

    self.retryTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       target:self
                                                     selector:@selector(retryEventTap:)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;

    [self.retryTimer invalidate];
    self.retryTimer = nil;
    [self stopEventTap];
}

- (void)stopEventTap {
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

    self.enabledMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Reverse Mouse Scrolling"
        action:@selector(toggleEnabled:)
        keyEquivalent:@""];
    self.enabledMenuItem.target = self;
    self.enabledMenuItem.state = reversingEnabled
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    [menu addItem:self.enabledMenuItem];

    self.statusMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Starting mouse wheel reversal…"
        action:nil
        keyEquivalent:@""];
    self.statusMenuItem.enabled = NO;
    [menu addItem:self.statusMenuItem];

    NSMenuItem *accessibility = [[NSMenuItem alloc]
        initWithTitle:@"Open Accessibility Settings…"
        action:@selector(openAccessibilitySettings:)
        keyEquivalent:@""];
    accessibility.target = self;
    [menu addItem:accessibility];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [[NSMenuItem alloc]
        initWithTitle:@"Quit"
        action:@selector(quit:)
        keyEquivalent:@"q"];
    quit.target = self;
    [menu addItem:quit];
    self.statusItem.menu = menu;
}

- (void)retryEventTap:(NSTimer *)timer {
    (void)timer;

    if (self.eventTap == NULL && AXIsProcessTrusted() && [self startEventTap]) {
        self.statusMenuItem.title = reversingEnabled
            ? @"Mouse wheel reversal is active"
            : @"Mouse wheel reversal is off";
        self.statusItem.button.toolTip = @"Mouse Scroll Reverser";
    }
}

- (void)toggleEnabled:(id)sender {
    (void)sender;

    reversingEnabled = !reversingEnabled;
    [[NSUserDefaults standardUserDefaults]
        setBool:reversingEnabled
        forKey:EnabledPreferenceKey];
    self.enabledMenuItem.state = reversingEnabled
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    self.statusMenuItem.title = reversingEnabled
        ? @"Mouse wheel reversal is active"
        : @"Mouse wheel reversal is off";
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
        [self stopEventTap];
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

- (void)openAccessibilitySettings:(id)sender {
    (void)sender;

    NSURL *settingsURL = [NSURL URLWithString:
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:settingsURL];
}

- (void)quit:(id)sender {
    (void)sender;
    [NSApp terminate:nil];
}

@end

