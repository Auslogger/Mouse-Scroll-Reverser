#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>
#import <ServiceManagement/ServiceManagement.h>
#import "ScrollTap.h"

static bool reversingEnabled = true;
static NSString *const EnabledPreferenceKey = @"Enabled";

@interface AppDelegate ()
@property(nonatomic) ScrollTap *scrollTap;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *enabledMenuItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) NSMenuItem *accessibilityMenuItem;
@property(nonatomic, strong) NSMenuItem *loginMenuItem;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic) BOOL permissionPromptPending;
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
    [self scheduleAccessibilityPrompt];

    (void)ScrollTapStart(self.scrollTap);
    [self refreshMenuState];

    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                         target:self
                                                       selector:@selector(refreshState:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;

    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    ScrollTapDestroy(self.scrollTap);
    self.scrollTap = NULL;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                     hasVisibleWindows:(BOOL)hasVisibleWindows {
    (void)sender;
    (void)hasVisibleWindows;

    [self refreshState:nil];
    [self.statusItem.button performClick:nil];
    return YES;
}

- (void)buildMenu {
    self.statusItem = [[NSStatusBar systemStatusBar]
        statusItemWithLength:NSSquareStatusItemLength];
    [self setStatusIconSymbol:@"arrow.up.arrow.down.circle.fill"
                  description:@"Mouse scroll reversal is starting"];

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

    self.accessibilityMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Open Accessibility Settings…"
        action:@selector(openAccessibilitySettings:)
        keyEquivalent:@""];
    self.accessibilityMenuItem.target = self;
    [menu addItem:self.accessibilityMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];

    self.loginMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Start at Login"
        action:@selector(toggleLaunchAtLogin:)
        keyEquivalent:@""];
    self.loginMenuItem.target = self;
    [menu addItem:self.loginMenuItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [[NSMenuItem alloc]
        initWithTitle:@"Quit"
        action:@selector(quit:)
        keyEquivalent:@"q"];
    quit.target = self;
    [menu addItem:quit];
    self.statusItem.menu = menu;
}

- (void)refreshState:(NSTimer *)timer {
    (void)timer;

    ScrollTapSetEnabled(self.scrollTap, reversingEnabled);
    ScrollTapDisableReason disableReason =
        ScrollTapConsumeDisableReason(self.scrollTap);
    if (disableReason != ScrollTapDisableReasonNone) {
        // callbacks only signal; teardown stays on the main loop
        ScrollTapStop(self.scrollTap);
    }
    if (!AXIsProcessTrusted()) {
        // a disabled tap can still own its run loop source
        ScrollTapStop(self.scrollTap);
    } else if (reversingEnabled && !ScrollTapIsRunning(self.scrollTap)) {
        (void)ScrollTapStart(self.scrollTap);
    }
    [self refreshMenuState];
}

- (void)toggleEnabled:(id)sender {
    (void)sender;

    if (!AXIsProcessTrusted()) {
        reversingEnabled = true;
        [[NSUserDefaults standardUserDefaults]
            setBool:YES
            forKey:EnabledPreferenceKey];
        [self scheduleAccessibilityPrompt];
        [self refreshMenuState];
        return;
    }

    reversingEnabled = !reversingEnabled;
    [[NSUserDefaults standardUserDefaults]
        setBool:reversingEnabled
        forKey:EnabledPreferenceKey];
    ScrollTapSetEnabled(self.scrollTap, reversingEnabled);
    [self refreshMenuState];
}

- (void)toggleLaunchAtLogin:(id)sender {
    (void)sender;

    SMAppService *service = [SMAppService mainAppService];
    NSError *error = nil;
    BOOL succeeded = NO;
    if (service.status == SMAppServiceStatusEnabled) {
        succeeded = [service unregisterAndReturnError:&error];
    } else {
        succeeded = [service registerAndReturnError:&error];
    }

    if (!succeeded) {
        [self presentError:error title:@"Could Not Change Login Item"];
    }
}

- (void)presentError:(NSError *)error title:(NSString *)title {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = title;
    alert.informativeText = error.localizedDescription != nil
        ? error.localizedDescription
        : @"An unknown error occurred.";

    [NSApp activateIgnoringOtherApps:YES];
    [alert runModal];
}

- (void)refreshMenuState {
    const BOOL running = ScrollTapIsRunning(self.scrollTap);
    const BOOL permissionRequired =
        reversingEnabled && !AXIsProcessTrusted();
    self.enabledMenuItem.state = running
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    self.enabledMenuItem.title = permissionRequired
        ? @"Enable Reverse Mouse Scrolling…"
        : @"Reverse Mouse Scrolling";

    SMAppServiceStatus loginStatus = [SMAppService mainAppService].status;
    self.loginMenuItem.state = loginStatus == SMAppServiceStatusEnabled
        ? NSControlStateValueOn
        : NSControlStateValueOff;

    if (!reversingEnabled) {
        self.statusMenuItem.title = @"Status: Off";
    } else if (permissionRequired) {
        self.statusMenuItem.title =
            @"Status: Accessibility permission required";
    } else if (running) {
        self.statusMenuItem.title = @"Status: Running";
    } else {
        self.statusMenuItem.title = @"Status: Event tap is inactive";
    }

    [self updateStatusIconForEnabled:reversingEnabled
                  permissionRequired:permissionRequired
                             running:running];
}

- (void)updateStatusIconForEnabled:(BOOL)enabled
                permissionRequired:(BOOL)permissionRequired
                           running:(BOOL)running {
    if (permissionRequired) {
        [self setStatusIconSymbol:@"exclamationmark.triangle.fill"
                      description:@"Accessibility permission is required"];
    } else if (enabled && running) {
        [self setStatusIconSymbol:@"arrow.up.arrow.down.circle.fill"
                      description:@"Mouse scroll reversal is running"];
    } else if (enabled) {
        [self setStatusIconSymbol:@"exclamationmark.triangle.fill"
                      description:@"Mouse Scroll Reverser could not start"];
    } else {
        [self setStatusIconSymbol:@"pause.circle"
                      description:@"Mouse scroll reversal is off"];
    }
}

- (void)setStatusIconSymbol:(NSString *)symbolName
                description:(NSString *)description {
    NSStatusBarButton *button = self.statusItem.button;
    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName
                               accessibilityDescription:description];

    button.toolTip = description;
    if (image != nil) {
        // template images follow the current menu bar appearance
        image.template = YES;
        button.title = @"";
        button.image = image;
        button.imagePosition = NSImageOnly;
    } else {
        button.image = nil;
        button.title = @"↕";
    }
}

- (void)scheduleAccessibilityPrompt {
    if (self.permissionPromptPending || AXIsProcessTrusted()) {
        return;
    }

    // let the menu action finish before macOS presents its prompt
    self.permissionPromptPending = YES;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            self.permissionPromptPending = NO;
            if (!AXIsProcessTrusted()) {
                NSDictionary *options = @{
                    (__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES
                };
                (void)AXIsProcessTrustedWithOptions(
                    (__bridge CFDictionaryRef)options
                );
            }
        }
    );
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

