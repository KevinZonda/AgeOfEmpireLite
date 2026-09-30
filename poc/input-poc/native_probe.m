// Diagnostic only: observe HID/session state and AppKit delivery. Never inject events.
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#include <pthread.h>
#include <unistd.h>

static FILE *out;
static double wall(void) { return CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970; }
static void *poll_pointer(void *unused) {
    int oldH = -1, oldS = -1;
    CGPoint oldP = CGPointMake(-1e9, -1e9);
    double previous = wall();
    for (;;) {
        @autoreleasepool {
            double now = wall();
            int h = CGEventSourceButtonState(kCGEventSourceStateHIDSystemState, kCGMouseButtonLeft);
            int s = CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft);
            CGEventRef e = CGEventCreate(NULL);
            CGPoint p = CGEventGetLocation(e);
            CFRelease(e);
            if (h != oldH || s != oldS || !CGPointEqualToPoint(p, oldP) || now - previous > .05) {
                fprintf(out, "{\"t\":%.6f,\"layer\":\"quartz\",\"hid\":%d,\"session\":%d,\"x\":%.2f,\"y\":%.2f,\"poll_gap_ms\":%.3f}\n", now,h,s,p.x,p.y,(now-previous)*1000);
                oldH = h; oldS = s; oldP = p;
            }
            previous = now;
        }
        usleep(2000);
    }
    return NULL;
}
__attribute__((constructor)) static void start_probe(void) {
    const char *path = getenv("AOE_NATIVE_TRACE");
    if (!path) return;
    out = fopen(path, "w");
    if (!out) return;
    setvbuf(out, NULL, _IOLBF, 0);
    pthread_t thread;
    pthread_create(&thread, NULL, poll_pointer, NULL);
    pthread_detach(thread);
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp | NSEventMaskMouseMoved | NSEventMaskLeftMouseDragged) handler:^NSEvent *(NSEvent *e) {
            CGPoint p = e.locationInWindow;
            fprintf(out, "{\"t\":%.6f,\"layer\":\"appkit\",\"type\":%lu,\"age_ms\":%.3f,\"buttons\":%lu,\"x\":%.2f,\"y\":%.2f}\n", wall(), (unsigned long)e.type, (NSProcessInfo.processInfo.systemUptime-e.timestamp)*1000, (unsigned long)NSEvent.pressedMouseButtons,p.x,p.y);
            return e;
        }];
    });
}
