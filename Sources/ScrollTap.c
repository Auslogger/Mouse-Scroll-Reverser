#include "ScrollTap.h"
#include <limits.h>
#include <stdatomic.h>
#include <stdlib.h>

// owns the event tap and its small amount of state
struct ScrollTap {
    // Core Graphics objects we must release
    CFMachPortRef event_tap;
    CFRunLoopSourceRef run_loop_source;

    // values shared with the menu bar code
    bool enabled;
    atomic_int disable_reason;

    // useful for status and tests
    uint64_t reversed_event_count;
    uint64_t passed_through_event_count;
    ScrollTapLastInput last_input;
};

static int64_t safely_negate_integer(int64_t value) {
    // scroll deltas are tiny, so avoiding signed overflow keeps this total
    return value == INT64_MIN ? INT64_MAX : -value;
}

static void reverse_axis(
    CGEventRef event,
    CGEventField line_delta,
    CGEventField fixed_delta,
    CGEventField point_delta
) {
    // Core Graphics stores the same movement in three formats
    const int64_t original_line = CGEventGetIntegerValueField(event, line_delta);
    const double original_fixed = CGEventGetDoubleValueField(event, fixed_delta);
    const int64_t original_point = CGEventGetIntegerValueField(event, point_delta);

    CGEventSetIntegerValueField(
        event,
        line_delta,
        safely_negate_integer(original_line)
    );
    CGEventSetDoubleValueField(
        event,
        fixed_delta,
        -original_fixed
    );
    CGEventSetIntegerValueField(
        event,
        point_delta,
        safely_negate_integer(original_point)
    );
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
        // continuous events are normally from a trackpad
        tap->passed_through_event_count += 1;
        tap->last_input = ScrollTapLastInputContinuousPassedThrough;
        return false;
    }

    // axis 1 is vertical, axis 2 stays unchanged
    reverse_axis(
        event,
        kCGScrollWheelEventDeltaAxis1,
        kCGScrollWheelEventFixedPtDeltaAxis1,
        kCGScrollWheelEventPointDeltaAxis1
    );

    tap->reversed_event_count += 1;
    tap->last_input = ScrollTapLastInputMouseWheelReversed;
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
        // tell the main loop the callback was too slow
        atomic_store_explicit(
            &tap->disable_reason,
            ScrollTapDisableReasonTimeout,
            memory_order_release
        );
        return event;
    }

    if (type == kCGEventTapDisabledByUserInput) {
        // let the main loop clean up after permission changes
        atomic_store_explicit(
            &tap->disable_reason,
            ScrollTapDisableReasonUserInput,
            memory_order_release
        );
        return event;
    }

    if (type == kCGEventScrollWheel) {
        (void)ScrollTapProcessScrollEvent(tap, event);
    }

    return event;
}

ScrollTap *ScrollTapCreate(void) {
    // calloc starts pointers and counters at zero
    ScrollTap *tap = calloc(1, sizeof(ScrollTap));
    if (tap != NULL) {
        atomic_init(&tap->disable_reason, ScrollTapDisableReasonNone);
    }
    return tap;
}

void ScrollTapStop(ScrollTap *tap) {
    if (tap == NULL) {
        return;
    }

    if (tap->run_loop_source != NULL) {
        // remove the source before releasing it
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            tap->run_loop_source,
            kCFRunLoopCommonModes
        );
        CFRelease(tap->run_loop_source);
        tap->run_loop_source = NULL;
    }

    if (tap->event_tap != NULL) {
        // invalidate the port so no more callbacks can arrive
        CGEventTapEnable(tap->event_tap, false);
        CFMachPortInvalidate(tap->event_tap);
        CFRelease(tap->event_tap);
        tap->event_tap = NULL;
    }

    atomic_store_explicit(
        &tap->disable_reason,
        ScrollTapDisableReasonNone,
        memory_order_release
    );
}

void ScrollTapDestroy(ScrollTap *tap) {
    if (tap == NULL) {
        return;
    }

    // stop owns all Core Foundation cleanup
    ScrollTapStop(tap);
    free(tap);
}

bool ScrollTapStart(ScrollTap *tap) {
    if (tap == NULL) {
        return false;
    }
    if (tap->event_tap != NULL) {
        // reuse a healthy tap but rebuild a disabled one
        if (CGEventTapIsEnabled(tap->event_tap)) {
            return true;
        }
        ScrollTapStop(tap);
    }

    atomic_store_explicit(
        &tap->disable_reason,
        ScrollTapDisableReasonNone,
        memory_order_release
    );

    // listen only for scroll wheel events
    const CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);

    // insert before apps receive the scroll event
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

    // the tap needs a run loop source to receive callbacks
    tap->run_loop_source = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault,
        tap->event_tap,
        0
    );
    if (tap->run_loop_source == NULL) {
        CFMachPortInvalidate(tap->event_tap);
        CFRelease(tap->event_tap);
        tap->event_tap = NULL;
        return false;
    }

    // common modes keep it active while menus are open
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
        // the saved choice controls whether events are changed
        tap->enabled = enabled;
    }
}

ScrollTapDisableReason ScrollTapConsumeDisableReason(ScrollTap *tap) {
    if (tap == NULL) {
        return ScrollTapDisableReasonNone;
    }

    // read and clear the callback signal in one step
    return (ScrollTapDisableReason)atomic_exchange_explicit(
        &tap->disable_reason,
        ScrollTapDisableReasonNone,
        memory_order_acq_rel
    );
}

uint64_t ScrollTapReversedEventCount(const ScrollTap *tap) {
    return tap == NULL ? 0 : tap->reversed_event_count;
}

uint64_t ScrollTapPassedThroughEventCount(const ScrollTap *tap) {
    return tap == NULL ? 0 : tap->passed_through_event_count;
}

ScrollTapLastInput ScrollTapGetLastInput(const ScrollTap *tap) {
    return tap == NULL ? ScrollTapLastInputNone : tap->last_input;
}
