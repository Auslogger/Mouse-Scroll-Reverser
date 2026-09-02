#ifndef MOUSE_SCROLL_REVERSER_SCROLL_TAP_H
#define MOUSE_SCROLL_REVERSER_SCROLL_TAP_H

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>

typedef struct ScrollTap ScrollTap;

ScrollTap *ScrollTapCreate(void);
void ScrollTapDestroy(ScrollTap *tap);

bool ScrollTapStart(ScrollTap *tap);
void ScrollTapStop(ScrollTap *tap);
bool ScrollTapIsRunning(const ScrollTap *tap);
void ScrollTapSetEnabled(ScrollTap *tap, bool enabled);

bool ScrollTapProcessScrollEvent(ScrollTap *tap, CGEventRef event);

#endif

