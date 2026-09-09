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

    (void)ScrollTapStart(self.scrollTap);
    [self refreshMenuState];

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
        [self refreshMenuState];
    }
}

- (void)toggleEnabled:(id)sender {
    (void)sender;

    reversingEnabled = !reversingEnabled;
    [[NSUserDefaults standardUserDefaults]
        setBool:reversingEnabled
        forKey:EnabledPreferenceKey];
    ScrollTapSetEnabled(self.scrollTap, reversingEnabled);
    [self refreshMenuState];
}

- (void)refreshMenuState {
    const BOOL running = ScrollTapIsRunning(self.scrollTap);
    self.enabledMenuItem.state = running
        ? NSControlStateValueOn
        : NSControlStateValueOff;

    if (!reversingEnabled) {
        self.statusMenuItem.title = @"Status: Off";
    } else if (running) {
        self.statusMenuItem.title = @"Status: Running";
    } else {
        self.statusMenuItem.title = @"Status: Event tap is inactive";
    }
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

