#+build js
#+private
package io_utils

import "base:runtime"
import "core:slice"
import "core:sync"

foreign import io_utils_lib "io_utils"

@(export, link_name="io_utils_read_entire_file_cb")
read_entire_file_cb :: proc(ptr: ^u8, n: int, ok: int, handle: u64, cb: proc(ptr: ^u8, n: int, ok: int, handle: u64)) {
    cb(ptr, n, ok, handle)
}

@(default_calling_convention="contextless")
foreign io_utils_lib {
    @(link_name="read_entire_file")
    read_entire_file :: proc(path: string, buf: []byte, handle: u64, cb: proc "odin" (ptr: ^u8, n: int, ok: int, handle: u64)) -> int ---
}

ReadFileRequestKind :: enum {
    Bytes,
    Text,
}

ReadFileRequest :: struct {
    kind: ReadFileRequestKind,
    bytes_cb: proc(bytes: []u8, ok: bool),
    text_cb: proc(text: string, ok: bool),
    buf: []u8,
}

// Simple handle allocator + map
@(private="file")
_next_handle: u64
@(private="file")
_reqs: map[u64]ReadFileRequest
@(private="file")
_reqs_mutex: sync.Mutex

request_new :: proc(kind: ReadFileRequestKind) -> (h: u64) {
    sync.mutex_lock(&_reqs_mutex)
    defer sync.mutex_unlock(&_reqs_mutex)
    if _reqs == nil {
        _reqs = make(map[u64]ReadFileRequest)
    }
    _next_handle += 1
    h = _next_handle
    _reqs[h] = ReadFileRequest {
        kind = kind,
        buf = make([]u8, 1 << 20)
    }
    return
}

request_set_bytes_cb :: proc(h: u64, cb: proc(bytes: []u8, ok: bool)) {
    sync.mutex_lock(&_reqs_mutex)
    defer sync.mutex_unlock(&_reqs_mutex)
    r, ok := _reqs[h]
    if !ok do return
    r.bytes_cb = cb
    _reqs[h] = r
}

request_set_text_cb :: proc(h: u64, cb: proc(text: string, ok: bool)) {
    sync.mutex_lock(&_reqs_mutex)
    defer sync.mutex_unlock(&_reqs_mutex)
    r, ok := _reqs[h]
    if !ok do return
    r.text_cb = cb
    _reqs[h] = r
}

request_take :: proc(h: u64) -> (r: ReadFileRequest, ok: bool) {
    sync.mutex_lock(&_reqs_mutex)
    defer sync.mutex_unlock(&_reqs_mutex)
    r, ok = _reqs[h]
    if ok {
        delete_key(&_reqs, h)
    }
    return
}

// Trampoline that routes by handle and request kind, then finalizes the request
@(private="file")
on_read_entire_file_done :: proc "odin" (ptr: ^u8, n: int, ok: int, handle: u64) {
    r, exists := request_take(handle)
    if !exists {
        return
    }
    ok := ok != 0 && ptr != nil && n > 0
    if !ok {
        if r.kind == .Bytes {
            if r.bytes_cb != nil do r.bytes_cb(nil, false)
        } else {
            if r.text_cb != nil do r.text_cb("", false)
        }
        return
    }

    // Build slice view of the received data
    bytes := slice.from_ptr(ptr, n)

    if r.kind == .Bytes {
        if r.bytes_cb != nil do r.bytes_cb(bytes, true)
    } else {
        s := string(bytes)
        if r.text_cb != nil do r.text_cb(s, true)
    }
}

// Low-level raw bytes read (JS bridge) with handle
_read_entire_file_to_bytes :: proc "contextless" (path: string, cb: proc(bytes: []u8, ok: bool)) -> bool {
    context = runtime.default_context()

    h := request_new(.Bytes)
    request_set_bytes_cb(h, cb)

    // Access request buffer
    r, _ := _reqs[h]
    return read_entire_file(path, r.buf, h, on_read_entire_file_done) != 0
}

// Text read built atop the same bytes pipe, identified by handle
_read_entire_file_to_string :: proc "contextless" (path: string, cb: proc(text: string, ok: bool)) -> bool {
    context = runtime.default_context()

    h := request_new(.Text)
    request_set_text_cb(h, cb)

    r, _ := _reqs[h]
    return read_entire_file(path, r.buf, h, on_read_entire_file_done) != 0
}
