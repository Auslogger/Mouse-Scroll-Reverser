#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>
#import <ServiceManagement/ServiceManagement.h>
#import "ScrollTap.h"

// values saved between launches
static NSString *const EnabledPreferenceKey = @"Enabled";
static NSString *const EnabledDefaultInitializedKey =
    @"EnabledDefaultInitializedForMenuOnlyVersion";

// permission can flicker briefly while macOS updates it
static const NSUInteger TrustedChecksRequiredForRecovery = 3;

@interface AppDelegate ()
// c wrapper around the Core Graphics event tap
@property(nonatomic) ScrollTap *scrollTap;

// menu bar controls and status
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *enabledMenuItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) NSMenuItem *accessibilityMenuItem;
@property(nonatomic, strong) NSMenuItem *loginMenuItem;
@property(nonatomic, strong) NSTimer *refreshTimer;

// state used while accessibility permission settles
@property(nonatomic) BOOL waitingForPermissionRecovery;
@property(nonatomic) NSUInteger consecutiveTrustedChecks;
@property(nonatomic) BOOL permissionPromptPending;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    // menu bar only with no dock icon
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{ EnabledPreferenceKey: @YES }];

    // turn reversal on once, then remember the user's choice
    if (![defaults boolForKey:EnabledDefaultInitializedKey]) {
        [defaults setBool:YES forKey:EnabledPreferenceKey];
        [defaults setBool:YES forKey:EnabledDefaultInitializedKey];
    }

    // create the filter before the first menu refresh
    self.scrollTap = ScrollTapCreate();
    [self buildStatusMenu];
    [self refreshState:nil];

    // keep permission, tap and menu state in sync
    self.refreshTimer = [NSTimer timerWithTimeInterval:0.2
                                                target:self
                                              selector:@selector(refreshState:)
                                              userInfo:nil
                                               repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.refreshTimer
                              forMode:NSRunLoopCommonModes];

    if ([self enabledPreference] && !AXIsProcessTrusted()) {
        // first launch is already an attempt to enable it
        [self scheduleAccessibilityPrompt];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;

    // stop callbacks before the app exits
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    ScrollTapDestroy(self.scrollTap);
    self.scrollTap = NULL;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                     hasVisibleWindows:(BOOL)hasVisibleWindows {
    (void)sender;
    (void)hasVisibleWindows;

    // reopening a menu bar app should show its menu
    [self refreshState:nil];
    [self.statusItem.button performClick:nil];
    return YES;
}

- (void)buildStatusMenu {
    self.statusItem = [[NSStatusBar systemStatusBar]
        statusItemWithLength:NSSquareStatusItemLength];

    // give the menu bar item an image before the first state refresh
    [self setStatusIconSymbol:@"arrow.up.arrow.down.circle.fill"
                  description:@"Mouse scroll reversal is starting"];

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Mouse Scroll Reverser"];

    // main on and off control
    self.enabledMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Reverse Mouse Scrolling"
               action:@selector(toggleEnabled:)
        keyEquivalent:@""];
    self.enabledMenuItem.target = self;
    [menu addItem:self.enabledMenuItem];

    // read-only view of the real tap state
    self.statusMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Status: Starting…"
               action:nil
        keyEquivalent:@""];
    self.statusMenuItem.enabled = NO;
    [menu addItem:self.statusMenuItem];

    // opens settings without showing another prompt
    self.accessibilityMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Open Accessibility Settings…"
               action:@selector(openAccessibilitySettings:)
        keyEquivalent:@""];
    self.accessibilityMenuItem.target = self;
    [menu addItem:self.accessibilityMenuItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // SMAppService handles the main app as a login item
    self.loginMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Start at Login"
               action:@selector(toggleLaunchAtLogin:)
        keyEquivalent:@""];
    self.loginMenuItem.target = self;
    [menu addItem:self.loginMenuItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc]
        initWithTitle:@"Quit Mouse Scroll Reverser"
               action:@selector(quit:)
        keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
}

- (BOOL)enabledPreference {
    return [[NSUserDefaults standardUserDefaults] boolForKey:EnabledPreferenceKey];
}

- (void)toggleEnabled:(id)sender {
    (void)sender;

    const BOOL trusted = AXIsProcessTrusted();
    const BOOL running = ScrollTapIsRunning(self.scrollTap);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (!trusted) {
        // no permission means this click is a retry
        [defaults setBool:YES forKey:EnabledPreferenceKey];
        self.waitingForPermissionRecovery = YES;
        self.consecutiveTrustedChecks = 0;
        [self refreshState:nil];
        [self scheduleAccessibilityPrompt];
        return;
    }

    if ([self enabledPreference] && !running) {
        // retry the filter without toggling the saved choice off
        self.waitingForPermissionRecovery = NO;
        self.consecutiveTrustedChecks = 0;
    } else {
        [defaults setBool:![self enabledPreference]
                   forKey:EnabledPreferenceKey];
    }

    [self refreshState:nil];
}

- (void)toggleLaunchAtLogin:(id)sender {
    (void)sender;

    // register or remove this app bundle as a login item
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
    [self refreshState:nil];
}

- (void)scheduleAccessibilityPrompt {
    // avoid duplicate prompts while one is already queued
    if (self.permissionPromptPending || AXIsProcessTrusted()) {
        return;
    }

    // let the current menu action finish before macOS shows its prompt
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

    // jump directly to the accessibility privacy page
    NSURL *settingsURL = [NSURL URLWithString:
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    if (settingsURL != nil) {
        [[NSWorkspace sharedWorkspace] openURL:settingsURL];
    }
}

- (void)quit:(id)sender {
    (void)sender;
    [NSApp terminate:nil];
}

- (void)refreshState:(NSTimer *)timer {
    (void)timer;

    // take one snapshot of the current app and macOS state
    const BOOL enabled = [self enabledPreference];
    const BOOL trusted = AXIsProcessTrusted();
    const ScrollTapDisableReason disableReason =
        ScrollTapConsumeDisableReason(self.scrollTap);

    ScrollTapSetEnabled(self.scrollTap, enabled);

    if (disableReason != ScrollTapDisableReasonNone) {
        // never restart inside the callback or input can lock up
        ScrollTapStop(self.scrollTap);
        if (disableReason == ScrollTapDisableReasonUserInput) {
            self.waitingForPermissionRecovery = YES;
            self.consecutiveTrustedChecks = 0;
        }
    }

    if (!trusted) {
        self.waitingForPermissionRecovery = YES;
        self.consecutiveTrustedChecks = 0;

        // a disabled tap can still own its port and run loop source
        ScrollTapStop(self.scrollTap);
    } else if (self.waitingForPermissionRecovery) {
        // wait for a few stable checks before starting again
        self.consecutiveTrustedChecks += 1;
        if (self.consecutiveTrustedChecks >=
            TrustedChecksRequiredForRecovery) {
            self.waitingForPermissionRecovery = NO;
            self.consecutiveTrustedChecks = 0;
        }
    } else {
        self.consecutiveTrustedChecks = 0;
    }

    BOOL started = YES;
    if (!enabled) {
        // the user's off choice always wins
        ScrollTapStop(self.scrollTap);
        self.waitingForPermissionRecovery = NO;
        self.consecutiveTrustedChecks = 0;
    } else if (trusted && !self.waitingForPermissionRecovery) {
        // start only after permission looks stable
        if (!ScrollTapIsRunning(self.scrollTap)) {
            started = ScrollTapStart(self.scrollTap);
        }
    }

    const BOOL running = ScrollTapIsRunning(self.scrollTap);
    const BOOL permissionRequired = enabled && !trusted;
    const BOOL recoveringPermission = enabled && trusted && self.waitingForPermissionRecovery;

    // the checkmark shows the real tap state
    self.enabledMenuItem.state = running ? NSControlStateValueOn : NSControlStateValueOff;
    self.enabledMenuItem.title = permissionRequired
        ? @"Enable Reverse Mouse Scrolling…"
        : @"Reverse Mouse Scrolling";

    // read the login item state directly from macOS
    SMAppServiceStatus loginStatus = [SMAppService mainAppService].status;
    self.loginMenuItem.state = loginStatus == SMAppServiceStatusEnabled
        ? NSControlStateValueOn
        : NSControlStateValueOff;

    if (!enabled) {
        self.statusMenuItem.title = @"Status: Off";
    } else if (permissionRequired) {
        self.statusMenuItem.title =
            @"Status: Accessibility permission required";
    } else if (recoveringPermission) {
        self.statusMenuItem.title =
            @"Status: Confirming Accessibility permission…";
    } else if (running) {
        self.statusMenuItem.title = @"Status: Running";
    } else {
        self.statusMenuItem.title = started
            ? @"Status: Event tap is inactive"
            : @"Status: Unable to start event tap";
    }

    // always leave settings available for manual changes
    self.accessibilityMenuItem.hidden = NO;
    [self updateStatusIconForEnabled:enabled
                  permissionRequired:(permissionRequired || recoveringPermission)
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
        // a fallback if a symbol is unavailable on a macOS release
        button.image = nil;
        button.title = @"↕";
    }
}

- (void)presentError:(NSError *)error title:(NSString *)title {
    // login item failures need a visible message
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = title;
    NSString *message = error.localizedDescription;
    alert.informativeText = message != nil ? message : @"An unknown error occurred.";

    [NSApp activateIgnoringOtherApps:YES];
    [alert runModal];
}

@end
