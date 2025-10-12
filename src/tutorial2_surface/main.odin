package tutorial2_surface

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

State :: struct {
    window: ^SDL.Window,
    instance: wgpu.Instance,
    surface: wgpu.Surface,
    adapter: wgpu.Adapter,
    device: wgpu.Device,
    queue: wgpu.Queue,
    surface_config: wgpu.SurfaceConfiguration,
}

state_init :: proc(state: ^State) {
    if !SDL.SetAppMetadata(APP_TITLE, APP_VERSION, APP_IDENTIFIER) {
        fmt.panicf("sdl.SetAppMetadata error: ", SDL.GetError())
    }

    if !SDL.Init({.VIDEO}) {
        fmt.panicf("sdl.Init error: ", SDL.GetError())
    }

    state.window = SDL.CreateWindow(
        APP_TITLE,
        APP_INITIAL_WINDOW_WIDTH,
        APP_INITIAL_WINDOW_HEIGHT,
        {.RESIZABLE, .HIGH_PIXEL_DENSITY})

    if state.window == nil {
        fmt.panicf("sdl.CreateWindow error: ", SDL.GetError())
    }

    state.instance = wgpu.CreateInstance(nil)
    if state.instance == nil {
        panic("WebGPU is not supported")
    }

    state.surface = get_surface(state.instance, state.window)

    wgpu.InstanceRequestAdapter(
        state.instance,
        &{
            compatibleSurface = state.surface,
            featureLevel = .Core,
            powerPreference = .HighPerformance,
            backendType = .Vulkan,
        },
        { callback = on_adapter, userdata1 = rawptr(state) })

    on_adapter :: proc "c" (status: wgpu.RequestAdapterStatus, adapter: wgpu.Adapter, message: wgpu.StringView, userdata1: rawptr, userdata2: rawptr) {
        context = runtime.default_context()

        app := (^State)(userdata1)

        if status != .Success || adapter == nil {
            fmt.panicf("wgpu.InstanceRequestAdapter error: [%v] %s", status, message)
        }
        app.adapter = adapter

        wgpu.AdapterRequestDevice(app.adapter, nil, { callback = on_device, userdata1 = rawptr(app) })
    }

    on_device :: proc "c" (status: wgpu.RequestDeviceStatus, device: wgpu.Device, message: wgpu.StringView, userdata1: rawptr, userdata2: rawptr) {
        context = runtime.default_context()

        state := (^State)(userdata1)

        if status != .Success || device == nil {
            fmt.panicf("wgpu.AdapterRequestDevice error: [%v] %s", status, message)
        }
        state.device = device

        width, height := get_framebuffer_size(state.window)

        state.surface_config = {
            device = state.device,
            usage = { .RenderAttachment },
            format = .BGRA8UnormSrgb,
            width = width,
            height = height,
            presentMode = .Fifo,
            alphaMode = .Opaque
        }
        wgpu.SurfaceConfigure(state.surface, &state.surface_config)

        state.queue = wgpu.DeviceGetQueue(state.device)
    }
}

state_key :: proc(state: ^State, event: SDL.KeyboardEvent) {
    if event.key == SDL.K_ESCAPE {
        quit_event: SDL.Event
        quit_event.type = .QUIT
        if !SDL.PushEvent(&quit_event) {
            fmt.panicf("sdl.PushEvent error: ", SDL.GetError())
        }
    }
}

Render_Result_Code :: enum {
    Ok,
    SurfaceNeedsUpdate,
    Error,
}

Render_Error :: struct {
    message: string,
}

Render_Result :: struct {
    code: Render_Result_Code,
    error: Render_Error,
}

state_render :: proc(state: ^State) -> Render_Result {
    surface_texture := wgpu.SurfaceGetCurrentTexture(state.surface)
    switch surface_texture.status {
    case .SuccessOptimal, .SuccessSuboptimal:
        // All good, could handle suboptimal here.
    case .Timeout, .Outdated, .Lost:
        // Skip this frame, and re-configure surface.
        if surface_texture.texture != nil {
            wgpu.TextureRelease(surface_texture.texture)
        }
        return Render_Result { code = Render_Result_Code.SurfaceNeedsUpdate }
    case .OutOfMemory, .DeviceLost, .Error:
        // Something went wrong, can't keep going.
        return Render_Result {
            code = .Error,
            error = Render_Error {
                message = fmt.tprintf("wgpu.SurfaceGetCurrentTexture error (status = %v)", surface_texture.status)
            }
        }
    }
    defer wgpu.TextureRelease(surface_texture.texture)

    frame := wgpu.TextureCreateView(surface_texture.texture, nil)
    defer wgpu.TextureViewRelease(frame)

    command_encoder := wgpu.DeviceCreateCommandEncoder(state.device, nil)
    defer wgpu.CommandEncoderRelease(command_encoder)

    render_pass := wgpu.CommandEncoderBeginRenderPass(
        command_encoder,
        &wgpu.RenderPassDescriptor{
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

    wgpu.QueueSubmit(state.queue, { command_buffer })
    wgpu.SurfacePresent(state.surface)

    return Render_Result { code = .Ok }
}

state_resize :: proc(state: ^State, width, height: u32) {
    state.surface_config.width, state.surface_config.height = width, height
    wgpu.SurfaceConfigure(state.surface, &state.surface_config)
}

state_quit :: proc(state: ^State) {
    wgpu.QueueRelease(state.queue)
    wgpu.DeviceRelease(state.device)
    wgpu.AdapterRelease(state.adapter)
    wgpu.SurfaceRelease(state.surface)
    wgpu.InstanceRelease(state.instance)

    SDL.DestroyWindow(state.window)
}

app_init :: proc "c" (app_state: ^rawptr, argc: c.int, argv: [^]cstring) -> SDL.AppResult {
    context = runtime.default_context()
    state := new(State)
    app_state^ = rawptr(state)

    state_init(state)

    return .CONTINUE
}

app_event :: proc "c" (app_state: rawptr, event: ^SDL.Event) -> SDL.AppResult {
    context = runtime.default_context()

    state := (^State)(app_state)

    #partial switch event.type {
    case .QUIT:
        return .SUCCESS
    case .KEY_DOWN, .KEY_UP:
        state_key(state, event.key)
    case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
        width, height := get_framebuffer_size(state.window)
        state_resize(state, width, height)
    }

    return .CONTINUE;
}

app_iterate :: proc "c" (app_state: rawptr) -> SDL.AppResult {
    context = runtime.default_context()

    state := (^State)(app_state)

    render_result := state_render(state)
    switch render_result.code {
    case .Ok:
    case .SurfaceNeedsUpdate:
        width, height := get_framebuffer_size(state.window)
        state_resize(state, width, height)
    case .Error:
        fmt.panicf("Render error: {}", render_result.error.message)
    }

    free_all(context.temp_allocator)

    return .CONTINUE
}

app_quit :: proc "c" (app_state: rawptr, result: SDL.AppResult) {
    context = runtime.default_context()

    state := (^State)(app_state)

    state_quit(state)

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

main :: proc() {
    SDL.EnterAppMainCallbacks(0, nil, app_init, app_iterate, app_event, app_quit)
}