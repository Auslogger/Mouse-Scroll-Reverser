#include "ScrollTap.h"

#include <assert.h>
#include <stdio.h>

static CGEventRef make_discrete_event(int64_t vertical_delta) {
    CGEventRef event = CGEventCreateScrollWheelEvent(
        NULL,
        kCGScrollEventUnitLine,
        1,
        (int32_t)vertical_delta
    );
    assert(event != NULL);
    CGEventSetIntegerValueField(
        event,
        kCGScrollWheelEventIsContinuous,
        0
    );
    return event;
}

static void test_discrete_vertical_is_reversed(void) {
    ScrollTap *tap = ScrollTapCreate();
    assert(tap != NULL);
    ScrollTapSetEnabled(tap, true);

    CGEventRef event = make_discrete_event(4);
    assert(ScrollTapProcessScrollEvent(tap, event));
    assert(CGEventGetIntegerValueField(
        event,
        kCGScrollWheelEventDeltaAxis1
    ) == -4);

    CFRelease(event);
    ScrollTapDestroy(tap);
}

int main(void) {
    test_discrete_vertical_is_reversed();
    puts("ScrollTap tests passed.");
    return 0;
}

