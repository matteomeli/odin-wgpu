#+build js
package tutorial1_window

import "base:runtime"
import "core:log"
import "core:sys/wasm/js"

OS :: struct {
    initialized: bool,
}

os_init :: proc() {
    log.info("Application started.")

    ok := js.add_window_event_listener(.Resize, nil, size_callback)
    assert(ok)
}

// NOTE: frame loop is done by the odin.js repeatedly calling `step`.
os_run :: proc() {
    state.os.initialized = true

    log.info("WASM loop initialized.")
}

@(private="file", export)
step :: proc(dt: f32) -> bool {
    if !state.os.initialized {
        return true
    }

    frame(dt)

    return true
}

@(fini)
os_fini :: proc "contextless" () {
    context = runtime.default_context()
    js.remove_window_event_listener(.Resize, nil, size_callback)

    log.info("Application ended.")
}

@(private="file")
size_callback :: proc(e: js.Event) {
    resize()
}
