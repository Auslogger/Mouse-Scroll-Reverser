#include "ScrollTap.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

// build a scroll event with every delta format filled in
static CGEventRef make_event(
    int64_t vertical_line,
    double vertical_fixed,
    int64_t vertical_point,
    int64_t horizontal_line,
    double horizontal_fixed,
    int64_t horizontal_point,
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
        kCGScrollWheelEventDeltaAxis2,
        horizontal_line
    );
    CGEventSetDoubleValueField(
        event,
        kCGScrollWheelEventFixedPtDeltaAxis2,
        horizontal_fixed
    );
    CGEventSetIntegerValueField(
        event,
        kCGScrollWheelEventPointDeltaAxis2,
        horizontal_point
    );

    CGEventSetIntegerValueField(
        event,
        kCGScrollWheelEventIsContinuous,
        continuous ? 1 : 0
    );
    return event;
}

static void test_disabled_filter_does_nothing(void) {
    // disabled means the event must stay untouched
    ScrollTap *tap = ScrollTapCreate();
    assert(tap != NULL);

    CGEventRef event = make_event(3, 3.5, 24, 0, 0.0, 0, false);
    assert(!ScrollTapProcessScrollEvent(tap, event));
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1
    ) == 3);

    CFRelease(event);
    ScrollTapDestroy(tap);
}

static void test_discrete_vertical_is_reversed(void) {
    // normal mouse wheels report discrete movement
    ScrollTap *tap = ScrollTapCreate();
    assert(tap != NULL);
    ScrollTapSetEnabled(tap, true);

    CGEventRef event = make_event(4, 2.5, 20, 3, 1.5, 12, false);
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

    /* Horizontal remains unchanged by default. */
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
    // continuous movement is treated as trackpad input
    ScrollTap *tap = ScrollTapCreate();
    assert(tap != NULL);
    ScrollTapSetEnabled(tap, true);

    CGEventRef event = make_event(2, 1.75, 14, -1, -0.5, -4, true);
    assert(!ScrollTapProcessScrollEvent(tap, event));
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1
    ) == 2);
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventPointDeltaAxis2
    ) == -4);
    assert(ScrollTapPassedThroughEventCount(tap) == 1);
    assert(ScrollTapGetLastInput(tap) ==
           ScrollTapLastInputContinuousPassedThrough);

    CFRelease(event);
    ScrollTapDestroy(tap);
}

int main(void) {
    // simple assertions keep the test binary dependency free
    test_disabled_filter_does_nothing();
    test_discrete_vertical_is_reversed();
    test_continuous_event_is_untouched();
    puts("ScrollTap tests passed.");
    return 0;
}

