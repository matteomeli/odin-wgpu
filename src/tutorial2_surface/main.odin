package tutorial2_surface

import "core:fmt"
import wgpu "vendor:wgpu"
import runtime "base:runtime"

APP_TITLE :: "Odin Wgpu"
APP_IDENTIFIER :: "com.app.odin-wgpu"
APP_VERSION :: "0.1.0"
APP_INITIAL_WINDOW_WIDTH :: 1920
APP_INITIAL_WINDOW_HEIGHT :: 1080

Frame_Result_Code :: enum {
    Ok,
    SurfaceNeedsUpdate,
    Error,
}

Frame_Error :: struct {
    message: string,
}

Frame_Result :: struct {
    code: Frame_Result_Code,
    error: Frame_Error,
}

State :: struct {
    ctx: runtime.Context,
    os: OS,

    last_tick: u64,

    instance: wgpu.Instance,
    surface: wgpu.Surface,
    surface_config: wgpu.SurfaceConfiguration,
    adapter: wgpu.Adapter,
    device: wgpu.Device,
    queue: wgpu.Queue,

    clear_color: wgpu.Color
}

state: State

init :: proc() {
    context = state.ctx

    state.clear_color = { 0.122, 0.129, 0.157, 1 }

    state.instance = wgpu.CreateInstance(nil)
    if state.instance == nil {
        panic("WebGPU is not supported")
    }

    state.surface = os_get_surface(state.instance)

    wgpu.InstanceRequestAdapter(
        state.instance,
        &{
            compatibleSurface = state.surface,
            featureLevel = .Core,
            powerPreference = .HighPerformance,
            backendType = .Vulkan,
        },
        { callback = on_adapter })

    on_adapter :: proc "c" (status: wgpu.RequestAdapterStatus, adapter: wgpu.Adapter, message: wgpu.StringView, userdata1: rawptr, userdata2: rawptr) {
        context = state.ctx

        if status != .Success || adapter == nil {
            fmt.panicf("wgpu.InstanceRequestAdapter error: [%v] %s", status, message)
        }
        state.adapter = adapter

        wgpu.AdapterRequestDevice(adapter, nil, { callback = on_device })
    }

    on_device :: proc "c" (status: wgpu.RequestDeviceStatus, device: wgpu.Device, message: wgpu.StringView, userdata1: rawptr, userdata2: rawptr) {
        context = state.ctx

        if status != .Success || device == nil {
            fmt.panicf("wgpu.AdapterRequestDevice error: [%v] %s", status, message)
        }
        state.device = device

        width, height := os_get_framebuffer_size()

        state.surface_config = {
            device = state.device,
            usage = { .RenderAttachment },
            format = .BGRA8Unorm,
            width = width,
            height = height,
            presentMode = .Fifo,
            alphaMode = .Opaque
        }
        wgpu.SurfaceConfigure(state.surface, &state.surface_config)

        state.queue = wgpu.DeviceGetQueue(state.device)

        os_ready()
    }
}

resize :: proc() {
    context = state.ctx

    state.surface_config.width, state.surface_config.height = os_get_framebuffer_size()
    wgpu.SurfaceConfigure(state.surface, &state.surface_config)
}

frame :: proc(dt: f32) -> Frame_Result {
    context = state.ctx

    surface_texture := wgpu.SurfaceGetCurrentTexture(state.surface)
    switch surface_texture.status {
    case .SuccessOptimal, .SuccessSuboptimal:
        // All good, could handle suboptimal here.
    case .Timeout, .Outdated, .Lost:
        // Skip this frame, and re-configure surface.
        if surface_texture.texture != nil {
            wgpu.TextureRelease(surface_texture.texture)
        }
        return Frame_Result { code = Frame_Result_Code.SurfaceNeedsUpdate }
    case .OutOfMemory, .DeviceLost, .Error:
        // Something went wrong, can't keep going.
        return Frame_Result {
            code = .Error,
            error = Frame_Error {
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
                clearValue = state.clear_color
            }
        }
    )

    wgpu.RenderPassEncoderEnd(render_pass)
    wgpu.RenderPassEncoderRelease(render_pass)

    command_buffer := wgpu.CommandEncoderFinish(command_encoder, nil)
    defer wgpu.CommandBufferRelease(command_buffer)

    wgpu.QueueSubmit(state.queue, { command_buffer })
    wgpu.SurfacePresent(state.surface)

    return Frame_Result { code = .Ok }
}

on_event :: proc(event: WindowEvent) {
    #partial switch event.kind {
        case .MouseMoved:
            state.clear_color.r = f64(event.mouse_moved.position.x) / f64(state.surface_config.width);
            state.clear_color.g = f64(event.mouse_moved.position.y) / f64(state.surface_config.height);
    }
}

fini :: proc() {
    wgpu.QueueRelease(state.queue)
    wgpu.DeviceRelease(state.device)
    wgpu.AdapterRelease(state.adapter)
    wgpu.SurfaceRelease(state.surface)
    wgpu.InstanceRelease(state.instance)
}

main :: proc() {
    state.ctx = context

    os_run()
}
