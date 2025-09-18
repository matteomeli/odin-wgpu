package main

import "core:c"
import "core:fmt"
import SDL "vendor:sdl3"
import runtime "base:runtime"

APP_TITLE :: "Odin Wgpu"
APP_IDENTIFIER :: "com.app.odin-wgpu"
APP_VERSION :: "0.1.0"
APP_INITIAL_WINDOW_WIDTH :: 1920
APP_INITIAL_WINDOW_HEIGHT :: 1080

App :: struct {
    window: ^SDL.Window,
}

main :: proc() {
    SDL.EnterAppMainCallbacks(0, nil, app_init, app_iterate, app_event, app_quit)
}

app_init :: proc "c" (app_state: ^rawptr, argc: c.int, argv: [^]cstring) -> SDL.AppResult {
    context = runtime.default_context()
    app := new(App)
    app_state^ = rawptr(app)

    if !SDL.SetAppMetadata(APP_TITLE, APP_VERSION, APP_IDENTIFIER) {
        fmt.panicf("sdl.SetAppMetadata error: ", SDL.GetError())
    }

    if !SDL.Init({.VIDEO}) {
        fmt.panicf("sdl.Init error: ", SDL.GetError())
    }

    app.window = SDL.CreateWindow(
        APP_TITLE,
        APP_INITIAL_WINDOW_WIDTH,
        APP_INITIAL_WINDOW_HEIGHT,
        {.RESIZABLE, .HIGH_PIXEL_DENSITY})

    if app.window == nil {
        fmt.panicf("sdl.CreateWindow error: ", SDL.GetError())
    }

    return .CONTINUE
}

app_event :: proc "c" (app_state: rawptr, event: ^SDL.Event) -> SDL.AppResult {
    #partial switch event.type {
    case .QUIT:
        return .SUCCESS
    }

    return .CONTINUE;
}

app_iterate :: proc "c" (app_state: rawptr) -> SDL.AppResult {
    app := (^App)(app_state)

    return .CONTINUE
}

app_quit :: proc "c" (app_state: rawptr, result: SDL.AppResult) {
    app := (^App)(app_state)

    SDL.DestroyWindow(app.window)
    SDL.Quit()
}