// Model the engine's BeforeWaiting callback under serial system requests.
// No input injection, accessibility permissions or user settings required.
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <unistd.h>

static CFRunLoopRef loop;
static CFRunLoopSourceRef source;
static CFRunLoopTimerRef frame_timer;
static dispatch_semaphore_t reply;
static int requests, frames;
static bool gate_frames;
static double begin;

static void request(void *unused) {
    requests++;
    dispatch_semaphore_signal(reply);
}
static void *client(void *unused) {
    usleep(40000);
    begin = CFAbsoluteTimeGetCurrent();
    for (int i = 0; i < 30; i++) {
        CFRunLoopSourceSignal(source);
        CFRunLoopWakeUp(loop);
        dispatch_semaphore_wait(reply, DISPATCH_TIME_FOREVER);
        usleep(200); // A separate client's next synchronous request.
    }
    fprintf(stdout,"%s: 30 serial requests %.1fms; %d rendered frames\n",gate_frames?"gated":"original",(CFAbsoluteTimeGetCurrent()-begin)*1000,frames);
    CFRunLoopStop(loop);
    CFRunLoopWakeUp(loop);
    return NULL;
}
int main(int argc, char **argv) { @autoreleasepool {
    gate_frames = argc > 1 && strcmp(argv[1], "gated") == 0;
    loop = CFRunLoopGetCurrent();
    reply = dispatch_semaphore_create(0);
    CFRunLoopSourceContext ctx = {0}; ctx.perform = request;
    source = CFRunLoopSourceCreate(NULL,0,&ctx);
    CFRunLoopAddSource(loop,source,kCFRunLoopCommonModes);
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(NULL,kCFRunLoopBeforeWaiting,true,0,^(CFRunLoopObserverRef o,CFRunLoopActivity a) {
        if (gate_frames && frame_timer) return;
        usleep(8000); // Stand in for a VSync-blocked render, not event handling.
        frames++;
        if (frame_timer) { CFRunLoopTimerInvalidate(frame_timer); CFRelease(frame_timer); }
        frame_timer=CFRunLoopTimerCreateWithHandler(NULL,CFAbsoluteTimeGetCurrent()+.008333,0,0,0,^(CFRunLoopTimerRef t) {
            CFRunLoopTimerInvalidate(frame_timer); CFRelease(frame_timer); frame_timer=NULL;
        });
        CFRunLoopAddTimer(loop,frame_timer,kCFRunLoopCommonModes);
    });
    CFRunLoopAddObserver(loop,observer,kCFRunLoopCommonModes);
    pthread_t thread; pthread_create(&thread,NULL,client,NULL);
    CFRunLoopRun(); pthread_join(thread,NULL);
    CFRunLoopRemoveObserver(loop,observer,kCFRunLoopCommonModes); CFRelease(observer);
    CFRunLoopRemoveSource(loop,source,kCFRunLoopCommonModes); CFRelease(source);
    if(frame_timer) { CFRunLoopTimerInvalidate(frame_timer); CFRelease(frame_timer); }
}}
