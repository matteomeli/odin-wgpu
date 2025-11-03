#+build !js
package tutorial1_window

import "core:c"
import SDL "vendor:sdl3"
import log "core:log"

OS :: struct {
    window: ^SDL.Window,
}

os_init :: proc() {
    log.info("Application started.")
}

os_run :: proc() {
    SDL.EnterAppMainCallbacks(0, nil, app_init, app_iterate, app_event, app_quit)
}

os_fini :: proc() {
    log.info("Application ended.")
}

app_init :: proc "c" (app_state: ^rawptr, argc: c.int, argv: [^]cstring) -> SDL.AppResult {
    context = state.ctx

    if !SDL.SetAppMetadata(APP_TITLE, APP_VERSION, APP_IDENTIFIER) {
        log.panicf("sdl.SetAppMetadata error: ", SDL.GetError())
    }

    if !SDL.Init({.VIDEO}) {
        log.panicf("sdl.Init error: ", SDL.GetError())
    }

    state.os.window = SDL.CreateWindow(
        APP_TITLE,
        APP_INITIAL_WINDOW_WIDTH,
        APP_INITIAL_WINDOW_HEIGHT,
        {.RESIZABLE, .HIGH_PIXEL_DENSITY})

    if state.os.window == nil {
        log.panicf("sdl.CreateWindow error: ", SDL.GetError())
    }

    log.info("SDL Window created.")

    state.last_tick = SDL.GetPerformanceCounter()

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
                log.panicf("sdl.PushEvent error: ", SDL.GetError())
            }
        }
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

    frame(dt)

    return .CONTINUE
}

app_quit :: proc "c" (app_state: rawptr, result: SDL.AppResult) {
    context = state.ctx

    SDL.DestroyWindow(state.os.window)
    SDL.Quit()
}
