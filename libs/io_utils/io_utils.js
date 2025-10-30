function makeIOUtils(wmi) {
    return {
        read_entire_file: (path_ptr, path_len, buf_ptr, buf_len, handle, cb_fn) => {
            try {
                const path = wmi.loadString(path_ptr, path_len);
                fetch(path).then(res => {
                    if (!res.ok) throw new Error("Bad status");
                    return res.text();
                }).then(str => {
                    if (buf_len > 0 && buf_ptr) {
                        let n = Math.min(buf_len, str.length);
                        str = str.substring(0, n);
                        wmi.loadBytes(buf_ptr, buf_len).set(new TextEncoder().encode(str))
                        wmi.exports.io_utils_read_entire_file_cb(buf_ptr, n, 1, handle, cb_fn);
                    } else {
                        throw new Error("Bad status");
                    }
                }).catch(() => {
                    console.log("Read file failed!", path);
                    wmi.exports.io_utils_read_entire_file_cb(0, 0, 0, handle, cb_fn);
                });
                return 1;
            } catch (e) {
                console.log("Error in read_file_to_string:", e);
                return 0;
            }
        },
    };
}
