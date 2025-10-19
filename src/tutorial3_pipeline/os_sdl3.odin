#+build !js
package tutorial3_pipeline

import      "core:c"
import      "core:fmt"
import SDL  "vendor:sdl3"
import      "vendor:wgpu/sdl3glue"
import      "vendor:wgpu"

OS :: struct {
    window: ^SDL.Window,
}

os_get_framebuffer_size :: proc() -> (width, height: u32) {
    w, h: i32
    SDL.GetWindowSizeInPixels(state.os.window, &w, &h)
    return u32(w), u32(h)
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
    return sdl3glue.GetSurface(instance, state.os.window)
}

os_run :: proc() {
    SDL.EnterAppMainCallbacks(0, nil, app_init, app_iterate, app_event, app_quit)
}

os_ready :: proc() {}

app_init :: proc "c" (app_state: ^rawptr, argc: c.int, argv: [^]cstring) -> SDL.AppResult {
    context = state.ctx

    if !SDL.SetAppMetadata(APP_TITLE, APP_VERSION, APP_IDENTIFIER) {
        fmt.panicf("sdl.SetAppMetadata error: ", SDL.GetError())
    }

    if !SDL.Init({.VIDEO}) {
        fmt.panicf("sdl.Init error: ", SDL.GetError())
    }

    state.os.window = SDL.CreateWindow(
        APP_TITLE,
        APP_INITIAL_WINDOW_WIDTH,
        APP_INITIAL_WINDOW_HEIGHT,
        {.RESIZABLE, .HIGH_PIXEL_DENSITY})

    if state.os.window == nil {
        fmt.panicf("sdl.CreateWindow error: ", SDL.GetError())
    }

    state.last_tick = SDL.GetPerformanceCounter()

    init()

    return .CONTINUE
}

app_event :: proc "c" (app_state: rawptr, event: ^SDL.Event) -> SDL.AppResult {
    context = state.ctx

    #partial switch event.type {
    case .QUIT:
        return .SUCCESS
    case .KEY_DOWN, .KEY_UP:
        if event.key.key == SDL.K_ESCAPE {
            quit_event: SDL.Event
            quit_event.type = .QUIT
            if !SDL.PushEvent(&quit_event) {
                fmt.panicf("sdl.PushEvent error: ", SDL.GetError())
            }
        }
    case .MOUSE_MOTION:
        mouse_moved := WindowEvent {
            mouse_moved = MouseMoved {
                kind = .MouseMoved,
                position = { f64(event.motion.x), f64(event.motion.y) }
            }
        }
        window_event(mouse_moved)
    case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
        resize()
    }

    return .CONTINUE;
}

app_iterate :: proc "c" (app_state: rawptr) -> SDL.AppResult {
    context = state.ctx

    now := SDL.GetPerformanceCounter()
    dt := f32((now - state.last_tick) * 1000) / f32(SDL.GetPerformanceFrequency())
    state.last_tick = now

    frame_result : = frame(dt)
    switch frame_result.code {
        case .Ok:
        case .SurfaceNeedsUpdate:
            fmt.println("resize 2")
            resize()
        case .Error:
            fmt.panicf("Render error: {}", frame_result.error.message)
    }

    free_all(context.temp_allocator)

    return .CONTINUE
}

app_quit :: proc "c" (app_state: rawptr, result: SDL.AppResult) {
    context = state.ctx

    finish()

    SDL.DestroyWindow(state.os.window)
    SDL.Quit()
}
