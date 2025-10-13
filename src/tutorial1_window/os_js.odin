package tutorial1_window

import "base:runtime"
import "core:sys/wasm/js"

OS :: struct {
    initialized: bool,
}

os_init :: proc() {
    ok := js.add_window_event_listener(.Resize, nil, size_callback)
    assert(ok)
}

// NOTE: frame loop is done by the odin.js repeatedly calling `step`.
os_run :: proc() {
    state.os.initialized = true
}

@(private="file", export)
step :: proc(dt: f32) -> bool {
    if !state.os.initialized {
        return true
    }

    frame(dt)

    return true
}

@(private="file", fini)
os_fini :: proc "contextless" () {
    context = runtime.default_context()
    js.remove_window_event_listener(.Resize, nil, size_callback)
}

@(private="file")
size_callback :: proc(e: js.Event) {
    resize()
}
