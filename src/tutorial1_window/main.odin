package tutorial1_window

import "base:runtime"
import log "core:log"

APP_TITLE :: "Odin Wgpu"
APP_IDENTIFIER :: "com.app.odin-wgpu"
APP_VERSION :: "0.1.0"
APP_INITIAL_WINDOW_WIDTH :: 1920
APP_INITIAL_WINDOW_HEIGHT :: 1080

state: struct {
    ctx: runtime.Context,
    os: OS,

    last_tick: u64,
}

/*
Handles window resize operations.
*/
resize :: proc "c" () {
    context = state.ctx

    // We will fill this in the next tutorials
}

/*
Contains the rendering instructions to generate each frame.
*/
frame :: proc "c" (dt: f32) {
    context = state.ctx

    // We will fill this in the next tutorials
}

main :: proc() {
    logger := log.create_console_logger()
    context.logger = logger

    state.ctx = context

    os_init()

    os_run()

    os_fini()

    log.destroy_console_logger(logger)
}
