package tutorial2_surface

WindowEventKind :: enum u32 {
    MouseMoved,
}

CommonWindowEvent :: struct {
    kind: WindowEventKind
}

MouseMoved :: struct {
    using commonWindowEvent: CommonWindowEvent,
    position: [2]f64,
}

WindowEvent :: struct #raw_union {
    kind: WindowEventKind,
    mouse_moved: MouseMoved
}
