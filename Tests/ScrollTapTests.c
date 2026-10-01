#include "ScrollTap.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

static CGEventRef make_event(
    int64_t vertical_line,
    double vertical_fixed,
    int64_t vertical_point,
    int64_t horizontal_line,
    bool continuous
) {
    CGEventRef event = CGEventCreateScrollWheelEvent(
        NULL,
        kCGScrollEventUnitLine,
        2,
        (int32_t)vertical_line,
        (int32_t)horizontal_line
    );
    assert(event != NULL);
    CGEventSetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1,
        vertical_line
    );
    CGEventSetDoubleValueField(
        event,
        kCGScrollWheelEventFixedPtDeltaAxis1,
        vertical_fixed
    );
    CGEventSetIntegerValueField(
        event,
        kCGScrollWheelEventPointDeltaAxis1,
        vertical_point
    );
    CGEventSetIntegerValueField(
        event,
        kCGScrollWheelEventIsContinuous,
        continuous ? 1 : 0
    );
    return event;
}

static void test_disabled_filter_does_nothing(void) {
    ScrollTap *tap = ScrollTapCreate();
    assert(tap != NULL);

    CGEventRef event = make_event(3, 3.5, 24, 0, false);
    assert(!ScrollTapProcessScrollEvent(tap, event));
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1
    ) == 3);

    CFRelease(event);
    ScrollTapDestroy(tap);
}

static void test_discrete_vertical_is_reversed(void) {
    ScrollTap *tap = ScrollTapCreate();
    assert(tap != NULL);
    ScrollTapSetEnabled(tap, true);

    CGEventRef event = make_event(4, 2.5, 20, 3, false);
    assert(ScrollTapProcessScrollEvent(tap, event));
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1
    ) == -4);
    assert(fabs(CGEventGetDoubleValueField(
        event,
        kCGScrollWheelEventFixedPtDeltaAxis1
    ) - (-2.5)) < 0.0001);
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventPointDeltaAxis1
    ) == -20);
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis2
    ) == 3);
    assert(ScrollTapReversedEventCount(tap) == 1);
    assert(ScrollTapGetLastInput(tap) ==
           ScrollTapLastInputMouseWheelReversed);

    CFRelease(event);
    ScrollTapDestroy(tap);
}

static void test_continuous_event_is_untouched(void) {
    ScrollTap *tap = ScrollTapCreate();
    assert(tap != NULL);
    ScrollTapSetEnabled(tap, true);

    CGEventRef event = make_event(2, 1.75, 14, -1, true);
    assert(!ScrollTapProcessScrollEvent(tap, event));
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1
    ) == 2);
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis2
    ) == -1);
    assert(ScrollTapPassedThroughEventCount(tap) == 1);
    assert(ScrollTapGetLastInput(tap) ==
           ScrollTapLastInputContinuousPassedThrough);

    CFRelease(event);
    ScrollTapDestroy(tap);
}

int main(void) {
    test_disabled_filter_does_nothing();
    test_discrete_vertical_is_reversed();
    test_continuous_event_is_untouched();
    puts("ScrollTap tests passed.");
    return 0;
}

