const std = @import("std");
const linux = std.os.linux;

const F_SETPIPE_SZ = 1031;

fn writeLoop(buf: []const u8) void {
    while (true) {
        var rem = buf;
        while (rem.len > 0) {
            const n = std.posix.write(1, rem) catch return;
            rem = rem[n..];
        }
    }
}

pub fn main() anyerror!void {
    const a = std.heap.page_allocator;

    var args = std.process.args();
    _ = args.skip();
    var bytes = std.ArrayList(u8){};
    var bytesWriter = bytes.writer(a);
    if (args.next()) |first| {
        try bytesWriter.writeAll(first);
        while (args.next()) |arg| {
            try bytesWriter.writeAll(" ");
            try bytesWriter.writeAll(arg);
        }
    } else {
        try bytesWriter.writeAll("y");
    }
    try bytesWriter.writeAll("\n");

    // Fill a page-aligned block with whole copies of the line so every
    // syscall stays line-aligned. page_allocator returns page-aligned
    // memory, which vmsplice below wants.
    const copysize = bytes.items.len;
    const bufsiz = @max(64 * 1024, copysize);
    const buf = try a.alloc(u8, (bufsiz / copysize) * copysize);
    @memcpy(buf[0..copysize], bytes.items);
    var filled = copysize;
    while (filled < buf.len) {
        const n = @min(filled, buf.len - filled);
        @memcpy(buf[filled .. filled + n], buf[0..n]);
        filled += n;
    }
    bytes.deinit(a);

    // A larger pipe buffer reduces reader/writer lockstep; best effort.
    _ = linux.fcntl(1, F_SETPIPE_SZ, 1024 * 1024);

    // Zero-copy path: vmsplice maps the pages of our immutable buffer into
    // the pipe instead of copying them. The pages must never be modified
    // afterwards, which holds here. Falls back to plain write(2) when
    // stdout is not a pipe (or vmsplice is unavailable).
    // Short splices are frequent when the pipe is nearly full, and
    // resplicing an unaligned tail is ~2x slower than starting over from
    // the page-aligned buffer start. So when a cut lands on a line
    // boundary, restart; otherwise splice just enough to finish the torn
    // line first.
    outer: while (true) {
        var pos: usize = 0;
        var len: usize = buf.len;
        while (true) {
            const iov = [1]std.posix.iovec_const{.{ .base = buf.ptr + pos, .len = len }};
            const rc = linux.syscall4(.vmsplice, 1, @intFromPtr(&iov), 1, 0);
            switch (linux.E.init(rc)) {
                .SUCCESS => {},
                .INTR => continue,
                // Exit quietly when the reader is gone, like GNU yes.
                .PIPE => return,
                else => return writeLoop(buf),
            }
            const end = pos + rc;
            const frac = end % copysize;
            if (frac == 0) continue :outer;
            pos = end;
            len = copysize - frac;
        }
    }
}
