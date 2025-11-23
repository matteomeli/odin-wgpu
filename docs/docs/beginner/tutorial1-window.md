# Dependencies and the Window

In this tutorial we want to support both web and native targets. Odin's `wgpu` supports WASM by providing wrappers around the browser native WebGPU API, while for all other targets [wgpu-native](https://github.com/gfx-rs/wgpu-native) is used.

## Native

For native targets, just using an `import "vendor:wgpu"` statement in your Odin program will suffice. WGPU needs a target surface to attach to and doesn't provide itself a way to do it, because obtaining a surface is platform dependent. WGPU is only an API that concern itself with GPU functionality, it doesn't provide any interface with the underlying OS, like window management, input handing, events, etc. Odin provides two options for that, SDL and GLFW. We will go with SDL latest version, SDL3, using a `import "vendor:sdl3"` statement in our program. Odin also provides a *glue* package to gel together WGPU and SDL which allows to obtain a `wgpu.Surface` that can be consumed by WGPU from a pointer to a `SDL.Window`. We will do this using an `import "vendor:wgpu/sdl3glue"` statement in our program.

Odin doesn't have a package management system and using libraries usually just means to have `import` statements in the program. In order to link our program to SDL3 correctly though, we will have to copy manually the file SDL3.dll from `<Odin SDK path>\vendor\sdl3\` into the output folder where your programs is built into, e.g. `bin`. The output folder can be specified passing a `-out` switch to Odin compiler.

## WASM

For WASM, the process is a little more involved. The program has to be built with a function table to enable callbacks, this is done passing `-extra-linker-flags:"--export-table"` to the compiler. To instruct the compiler to target WAS use the `-target:js_wasm32` switch. The program entry point will be a html file, and it could be helpful to have a build script to avoid having to write by hand all the right flags to the compiler all the time.

To make this easy while following along the tutorial, an `index.html` file and a Powershell script to build for WASM is provided.

## Create project

Make sure is Odin properly installed in your system. Then, creating an Odin project is as simple as creating a folder. Odin programs consist of packages. A package is a directory of Odin code files, all of which have the same package declaration at the top. Odin doesn't dictate a specific folder organization, so we will go for a root folder `odin_wgpu` for the project, and a `src` folder within it for all the code of the various tutorials. `tutorial1_window` will be the name of this first tutorial.

```
$ mkdir odin_wgpu/src/tutorial1_window
$ cd odin_wgpu/src/tutorial1_window
```

Inside the `odin_wgpu/src/tutorial1_window` folder than create a file `main.odin` in your favourite IDE. For now, just paste the code below:

```odinlang
package main

import "core:fmt"

main :: proc() {
    fmt.println("Hellope!")
}
```

To build and run the program:

```
$ cd odin_wgpu
$ odin.exe run ./src/tutorial1_window -out:bin/tutorial1_window.exe
Hellope!
```
If you see the output presented above, everything is set up correctly.

At this point you can decide yourself what IDE you want to use, or don't use one at all, and how to compile the program. I have used free Jetbrains' IDE [IntelliJ Idea](https://www.jetbrains.com/idea/) with the awesome [Odin plugin](https://plugins.jetbrains.com/plugin/22933-odin-support) to create this tutorial series. Another option is [VS Code](https://code.visualstudio.com/) with the [Odin Language Server](https://marketplace.visualstudio.com/items?itemName=DanielGavin.ols) plugin. Or anything else you like.

## Scaffolding the code

We are going to need a place to put all of our state, so let's create a `State` struct and add a global variable `state` of that type. We also define a few constants for our application.

```odinlang title="main.odin" linenums="1"
package tutorial1_window

import "base:runtime"

APP_TITLE :: "Odin Wgpu"
APP_IDENTIFIER :: "com.app.odin-wgpu"
APP_VERSION :: "0.1.0"
APP_INITIAL_WINDOW_WIDTH :: 1920
APP_INITIAL_WINDOW_HEIGHT :: 1080

State :: struct {
    ctx: runtime.Context,
    os: OS,
    last_tick: u64,
}

state: State
```
We also create the scaffolding functions where we will add all the WGPU calls.

```odinlang title="main.odin" linenums="1"
init :: proc() {
    // We will fill this in the next tutorials
}

resize :: proc() {
    // We will fill this in the next tutorials
}

frame :: proc(dt: f32) {
    // We will fill this in the next tutorials
}

fini :: proc() {
    // We will fill this in the next tutorials
}
```
You might have noticed one of the member variables of the `State` struct is declared as `OS` but it's not defined here. We define it in a file that will contain everything that is SDL specific.

```odinlang title="os_sdl3.odin" linenums="1"
package tutorial1_window

import "core:c"
import SDL "vendor:sdl3"
import fmt "core:fmt"

OS :: struct {
    window: ^SDL.Window,
}

os_init :: proc() {
    fmt.println("Application started.")
}

os_run :: proc() {
    SDL.EnterAppMainCallbacks(0, nil, app_init, app_iterate, app_event, app_quit)
}

os_fini :: proc() {
    fmt.println("Application ended.")
}

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

    fmt.println("SDL Window created.")

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
                fmt.panicf("sdl.PushEvent error: ", SDL.GetError())
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
```

Finally, we orchestrate everything from the `main` function.

```odinlang
main :: proc() {
    state.ctx = context

    os_init()

    os_run()

    os_fini()
}
```

This is the simple start of our program leading up to the `main` function.

## Logger

```odinlang
main :: proc() {
    logger := log.create_console_logger()
    context.logger = logger

    state.ctx = context

    os_init()

    os_run()

    os_fini()

    log.destroy_console_logger(logger)
}
```

```odinlang
import log "core:log"

os_init :: proc() {
    log.info("Application started.")
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
```

## Compile and run

## Add support for the web

## Demo

TODO: How to embed a demo in here?

TODO: Add link to the source code
