package tutorial2_surface

import "base:runtime"
import "core:fmt"
import "core:sys/wasm/js"
import "vendor:wgpu"

OS :: struct {
    ready: bool,
}

os_init :: proc() {
    ok := js.add_window_event_listener(.Resize, nil, size_callback)
    assert(ok)

    init()
}

os_get_framebuffer_size :: proc() -> (width, height: u32) {
    rect := js.get_bounding_client_rect("odin-wgpu")
    dpi := js.device_pixel_ratio()
    return u32(f64(rect.width) * dpi), u32(f64(rect.height) * dpi)
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
    return wgpu.InstanceCreateSurface(
        instance,
        &wgpu.SurfaceDescriptor{
            nextInChain = &wgpu.SurfaceSourceCanvasHTMLSelector{
                sType = .SurfaceSourceCanvasHTMLSelector,
                selector = "#wgpu-canvas",
            },
        },
    )
}

os_mark_ready :: proc() {
    state.os.ready = true
}

os_run :: proc() {
    // NOTE: Frame loop is done by the odin.js repeatedly calling `step`.
}

@(private="file", export)
step :: proc(dt: f32) -> bool {
    if !state.os.ready {
        return true
    }

    frame_result := frame(dt)
    switch frame_result.code {
        case .Ok:
        case .SurfaceNeedsUpdate:
            resize()
        case .Error:
            fmt.panicf("Render error: {}", frame_result.error.message)
    }

    free_all(context.temp_allocator)

    return true
}

@(private="file", fini)
os_fini :: proc "contextless" () {
    context = runtime.default_context()
    js.remove_window_event_listener(.Resize, nil, size_callback)

    finish()
}

@(private="file")
size_callback :: proc(e: js.Event) {
    resize()
}
