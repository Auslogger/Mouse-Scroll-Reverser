#ifndef MOUSE_SCROLL_REVERSER_SCROLL_TAP_H
#define MOUSE_SCROLL_REVERSER_SCROLL_TAP_H

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>
#include <stdint.h>

// keep the implementation private from the menu bar code
typedef struct ScrollTap ScrollTap;

// last kind of scroll input seen by the filter
typedef enum ScrollTapLastInput {
    ScrollTapLastInputNone = 0,
    ScrollTapLastInputMouseWheelReversed,
    ScrollTapLastInputContinuousPassedThrough
} ScrollTapLastInput;

// why macOS stopped the event tap
typedef enum ScrollTapDisableReason {
    ScrollTapDisableReasonNone = 0,
    ScrollTapDisableReasonTimeout,
    ScrollTapDisableReasonUserInput
} ScrollTapDisableReason;

// lifetime
ScrollTap *ScrollTapCreate(void);
void ScrollTapDestroy(ScrollTap *tap);

// event tap state
bool ScrollTapStart(ScrollTap *tap);
void ScrollTapStop(ScrollTap *tap);
bool ScrollTapIsRunning(const ScrollTap *tap);

// saved setting and callback state
void ScrollTapSetEnabled(ScrollTap *tap, bool enabled);
ScrollTapDisableReason ScrollTapConsumeDisableReason(ScrollTap *tap);

// small counters used for status and testing
uint64_t ScrollTapReversedEventCount(const ScrollTap *tap);
uint64_t ScrollTapPassedThroughEventCount(const ScrollTap *tap);
ScrollTapLastInput ScrollTapGetLastInput(const ScrollTap *tap);

// public so tests can pass in synthetic events
bool ScrollTapProcessScrollEvent(ScrollTap *tap, CGEventRef event);

#endif
