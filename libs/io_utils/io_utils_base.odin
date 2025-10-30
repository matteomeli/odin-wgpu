#+build !js
#+private
package io_utils

import "core:os"
import "base:runtime"

_read_entire_file_to_bytes :: proc "contextless" (path: string, cb: proc(bytes: []u8, ok: bool)) {
    context = runtime.default_context()
    bytes, ok := os.read_entire_file(path)
    if !ok || bytes == nil || len(bytes) == 0 {
        cb(nil, false)
        return
    }
    cb(bytes, true)
}

_read_entire_file_to_string :: proc "contextless" (path: string, cb: proc(text: string, ok: bool)) {
    context = runtime.default_context()
    bytes, ok := os.read_entire_file(path)
    if !ok || bytes == nil || len(bytes) == 0 {
        cb("", false)
        return
    }
    cb(string(bytes), true)
}
