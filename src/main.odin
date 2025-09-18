package main

import "core:c"
import "core:fmt"
import SDL "vendor:sdl3"
import "vendor:wgpu/sdl3glue"
import wgpu "vendor:wgpu"
import runtime "base:runtime"

APP_TITLE :: "Odin Wgpu"
APP_IDENTIFIER :: "com.app.odin-wgpu"
APP_VERSION :: "0.1.0"
APP_INITIAL_WINDOW_WIDTH :: 1920
APP_INITIAL_WINDOW_HEIGHT :: 1080

App :: struct {
    window: ^SDL.Window,
    instance: wgpu.Instance,
    surface: wgpu.Surface,
    adapter: wgpu.Adapter,
    device: wgpu.Device,
    queue: wgpu.Queue,
    surface_config: wgpu.SurfaceConfiguration,
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

    app.instance = wgpu.CreateInstance(nil)
    if app.instance == nil {
        panic("WebGPU is not supported")
    }

    app.surface = get_surface(app.instance, app.window)

    wgpu.InstanceRequestAdapter(
        app.instance,
        &{
            compatibleSurface = app.surface,
            featureLevel = .Core,
            powerPreference = .HighPerformance,
            backendType = .Vulkan
        },
        { callback = on_adapter, userdata1 = rawptr(app) })

    on_adapter :: proc "c" (status: wgpu.RequestAdapterStatus, adapter: wgpu.Adapter, message: wgpu.StringView, userdata1: rawptr, userdata2: rawptr) {
        context = runtime.default_context()

        app := (^App)(userdata1)

        if status != .Success || adapter == nil {
            fmt.panicf("wgpu.InstanceRequestAdapter error: [%v] %s", status, message)
        }
        app.adapter = adapter

        wgpu.AdapterRequestDevice(app.adapter, nil, { callback = on_device, userdata1 = rawptr(app) })
    }

    on_device :: proc "c" (status: wgpu.RequestDeviceStatus, device: wgpu.Device, message: wgpu.StringView, userdata1: rawptr, userdata2: rawptr) {
        context = runtime.default_context()

        app := (^App)(userdata1)

        if status != .Success || device == nil {
            fmt.panicf("wgpu.AdapterRequestDevice error: [%v] %s", status, message)
        }
        app.device = device

        width, height := get_framebuffer_size(app.window)

        app.surface_config = {
            device = app.device,
            usage = { .RenderAttachment },
            format = .BGRA8UnormSrgb,
            width = width,
            height = height,
            presentMode = .Fifo,
            alphaMode = .Opaque
        }
        wgpu.SurfaceConfigure(app.surface, &app.surface_config)

        app.queue = wgpu.DeviceGetQueue(app.device)
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
    context = runtime.default_context()

    app := (^App)(app_state)

    surface_texture := wgpu.SurfaceGetCurrentTexture(app.surface)
    switch surface_texture.status {
    case .SuccessOptimal, .SuccessSuboptimal:
        // All good, could handle suboptimal here.
    case .Timeout, .Outdated, .Lost:
        // Skip this frame, and re-configure surface.
        if surface_texture.texture != nil {
            wgpu.TextureRelease(surface_texture.texture)
            return .CONTINUE
        }
    case .OutOfMemory, .DeviceLost, .Error:
        fmt.panicf("wgpu.SurfaceGetCurrentTexture error (status = %v)", surface_texture.status)
    }
    defer wgpu.TextureRelease(surface_texture.texture)

    frame := wgpu.TextureCreateView(surface_texture.texture, nil)
    defer wgpu.TextureViewRelease(frame)

    command_encoder := wgpu.DeviceCreateCommandEncoder(app.device, nil)
    defer wgpu.CommandEncoderRelease(command_encoder)

    render_pass := wgpu.CommandEncoderBeginRenderPass(
        command_encoder, &wgpu.RenderPassDescriptor{
            colorAttachmentCount = 1,
            colorAttachments = &wgpu.RenderPassColorAttachment{
                view = frame,
                loadOp = .Clear,
                storeOp = .Store,
                depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
                clearValue = { 0.39, 0.58, 0.93, 1 }    // Cornflower Blue
            }
        }
    )

    wgpu.RenderPassEncoderEnd(render_pass)
    wgpu.RenderPassEncoderRelease(render_pass)

    command_buffer := wgpu.CommandEncoderFinish(command_encoder, nil)
    defer wgpu.CommandBufferRelease(command_buffer)

    wgpu.QueueSubmit(app.queue, { command_buffer })
    wgpu.SurfacePresent(app.surface)

    return .CONTINUE
}

app_quit :: proc "c" (app_state: rawptr, result: SDL.AppResult) {
    app := (^App)(app_state)

    wgpu.QueueRelease(app.queue)
    wgpu.DeviceRelease(app.device)
    wgpu.AdapterRelease(app.adapter)
    wgpu.SurfaceRelease(app.surface)
    wgpu.InstanceRelease(app.instance)

    SDL.DestroyWindow(app.window)
    SDL.Quit()
}

get_surface :: proc(instance: wgpu.Instance, window: ^SDL.Window) -> wgpu.Surface {
    return sdl3glue.GetSurface(instance, window)
}

get_framebuffer_size :: proc(window: ^SDL.Window) -> (width, height: u32) {
    w, h: i32
    SDL.GetWindowSizeInPixels(window, &w, &h)
    return u32(w), u32(h)
}