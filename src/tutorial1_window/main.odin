package tutorial1_window

import "base:runtime"

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

resize :: proc "c" () {
    context = state.ctx

    width, height := os_get_framebuffer_size()

    // We will fill this in the next tutorials
}

frame :: proc "c" (dt: f32) {
    context = state.ctx

    // We will fill this in the next tutorials
}

main :: proc() {
    state.ctx = context

    os_init()

    os_run()
}
