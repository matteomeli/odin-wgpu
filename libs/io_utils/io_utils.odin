package io_utils

read_entire_file_to_bytes :: proc "contextless" (path: string, cb: proc(bytes: []u8, ok: bool)) {
    _read_entire_file_to_bytes(path, cb)
}

read_entire_file_to_string :: proc "contextless" (path: string, cb: proc(text: string, ok: bool)) {
    _read_entire_file_to_string(path, cb)
}
