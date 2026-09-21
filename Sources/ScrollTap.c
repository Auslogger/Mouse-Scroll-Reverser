#include "ScrollTap.h"
#include <stdatomic.h>
#include <stdlib.h>

struct ScrollTap {
    CFMachPortRef event_tap;
    CFRunLoopSourceRef run_loop_source;
    bool enabled;
    atomic_bool disabled_by_timeout;
};

static void reverse_axis(
    CGEventRef event,
    CGEventField line_delta,
    CGEventField fixed_delta,
    CGEventField point_delta
) {
    const int64_t original_line = CGEventGetIntegerValueField(event, line_delta);
    const double original_fixed = CGEventGetDoubleValueField(event, fixed_delta);
    const int64_t original_point = CGEventGetIntegerValueField(event, point_delta);

    CGEventSetIntegerValueField(event, line_delta, -original_line);
    CGEventSetDoubleValueField(event, fixed_delta, -original_fixed);
    CGEventSetIntegerValueField(event, point_delta, -original_point);
}

bool ScrollTapProcessScrollEvent(ScrollTap *tap, CGEventRef event) {
    if (tap == NULL || event == NULL || !tap->enabled) {
        return false;
    }

    const bool is_continuous = CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventIsContinuous
    ) != 0;
    if (is_continuous) {
        return false;
    }

    reverse_axis(
        event,
        kCGScrollWheelEventDeltaAxis1,
        kCGScrollWheelEventFixedPtDeltaAxis1,
        kCGScrollWheelEventPointDeltaAxis1
    );
    return true;
}

static CGEventRef scroll_event_callback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void *user_info
) {
    (void)proxy;

    ScrollTap *tap = user_info;
    if (tap == NULL) {
        return event;
    }
    if (type == kCGEventTapDisabledByTimeout) {
        // leave cleanup and restart to the main application loop
        atomic_store(&tap->disabled_by_timeout, true);
        return event;
    }
    if (type == kCGEventScrollWheel) {
        (void)ScrollTapProcessScrollEvent(tap, event);
    }
    return event;
}

ScrollTap *ScrollTapCreate(void) {
    ScrollTap *tap = calloc(1, sizeof(ScrollTap));
    if (tap != NULL) {
        atomic_init(&tap->disabled_by_timeout, false);
    }
    return tap;
}

void ScrollTapStop(ScrollTap *tap) {
    if (tap == NULL) {
        return;
    }

    if (tap->run_loop_source != NULL) {
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            tap->run_loop_source,
            kCFRunLoopCommonModes
        );
        CFRelease(tap->run_loop_source);
        tap->run_loop_source = NULL;
    }
    if (tap->event_tap != NULL) {
        CFMachPortInvalidate(tap->event_tap);
        CFRelease(tap->event_tap);
        tap->event_tap = NULL;
    }
    atomic_store(&tap->disabled_by_timeout, false);
}

void ScrollTapDestroy(ScrollTap *tap) {
    if (tap != NULL) {
        ScrollTapStop(tap);
        free(tap);
    }
}

bool ScrollTapStart(ScrollTap *tap) {
    if (tap == NULL) {
        return false;
    }
    if (tap->event_tap != NULL) {
        if (CGEventTapIsEnabled(tap->event_tap)) {
            return true;
        }
        ScrollTapStop(tap);
    }

    const CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
    tap->event_tap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        mask,
        scroll_event_callback,
        tap
    );
    if (tap->event_tap == NULL) {
        return false;
    }

    tap->run_loop_source = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault,
        tap->event_tap,
        0
    );
    if (tap->run_loop_source == NULL) {
        ScrollTapStop(tap);
        return false;
    }

    CFRunLoopAddSource(
        CFRunLoopGetMain(),
        tap->run_loop_source,
        kCFRunLoopCommonModes
    );
    CGEventTapEnable(tap->event_tap, true);
    if (!CGEventTapIsEnabled(tap->event_tap)) {
        ScrollTapStop(tap);
        return false;
    }
    return true;
}

bool ScrollTapIsRunning(const ScrollTap *tap) {
    return tap != NULL &&
           tap->event_tap != NULL &&
           CGEventTapIsEnabled(tap->event_tap);
}

void ScrollTapSetEnabled(ScrollTap *tap, bool enabled) {
    if (tap != NULL) {
        tap->enabled = enabled;
    }
}

