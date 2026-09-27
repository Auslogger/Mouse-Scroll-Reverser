#ifndef MOUSE_SCROLL_REVERSER_SCROLL_TAP_H
#define MOUSE_SCROLL_REVERSER_SCROLL_TAP_H

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct ScrollTap ScrollTap;

typedef enum ScrollTapLastInput {
    ScrollTapLastInputNone = 0,
    ScrollTapLastInputMouseWheelReversed,
    ScrollTapLastInputContinuousPassedThrough
} ScrollTapLastInput;

typedef enum ScrollTapDisableReason {
    ScrollTapDisableReasonNone = 0,
    ScrollTapDisableReasonTimeout,
    ScrollTapDisableReasonUserInput
} ScrollTapDisableReason;

ScrollTap *ScrollTapCreate(void);
void ScrollTapDestroy(ScrollTap *tap);

bool ScrollTapStart(ScrollTap *tap);
void ScrollTapStop(ScrollTap *tap);
bool ScrollTapIsRunning(const ScrollTap *tap);
void ScrollTapSetEnabled(ScrollTap *tap, bool enabled);
ScrollTapDisableReason ScrollTapConsumeDisableReason(ScrollTap *tap);

uint64_t ScrollTapReversedEventCount(const ScrollTap *tap);
uint64_t ScrollTapPassedThroughEventCount(const ScrollTap *tap);
ScrollTapLastInput ScrollTapGetLastInput(const ScrollTap *tap);

bool ScrollTapProcessScrollEvent(ScrollTap *tap, CGEventRef event);

#endif

