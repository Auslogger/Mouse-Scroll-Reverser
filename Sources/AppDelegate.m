#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>
#import "ScrollTap.h"

static bool reversingEnabled = true;
static NSString *const EnabledPreferenceKey = @"Enabled";

@interface AppDelegate ()
@property(nonatomic) ScrollTap *scrollTap;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *enabledMenuItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) NSTimer *retryTimer;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{ EnabledPreferenceKey: @YES }];
    reversingEnabled = [defaults boolForKey:EnabledPreferenceKey];

    self.scrollTap = ScrollTapCreate();
    ScrollTapSetEnabled(self.scrollTap, reversingEnabled);
    [self buildMenu];
    [self requestAccessibilityPermission];

    if (ScrollTapStart(self.scrollTap)) {
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
    ScrollTapDestroy(self.scrollTap);
    self.scrollTap = NULL;
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

    if (!ScrollTapIsRunning(self.scrollTap) &&
        AXIsProcessTrusted() &&
        ScrollTapStart(self.scrollTap)) {
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
    ScrollTapSetEnabled(self.scrollTap, reversingEnabled);
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

