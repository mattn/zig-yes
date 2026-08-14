const std = @import("std");

pub fn main() anyerror!void {
    const a = std.heap.page_allocator;

    const args = try std.process.argsAlloc(a);

    var bytes = std.ArrayList(u8){};
    var bytesWriter = bytes.writer(a);
    if (args.len > 1) {
        for (args[1..args.len], 1..args.len) |arg, i| {
            if (i > 1) try bytesWriter.writeAll(" ");
            try bytesWriter.writeAll(arg);
        }
    } else {
        try bytesWriter.writeAll("y");
    }
    try bytesWriter.writeAll("\n");
    a.free(args);

    var buf = std.ArrayList(u8){};
    // 8KiB matches GNU yes; on pipes, filling the whole (64KiB) pipe buffer
    // per write causes reader/writer lockstep and hurts throughput.
    const bufsiz = 8 * 1024;
    const copysize = bytes.items.len;
    const bufWriter = buf.writer(a);

    var copies = @max(1, bufsiz / copysize);
    while (copies > 0) {
        try bufWriter.writeAll(bytes.items);
        copies -= 1;
    }
    bytes.deinit(a);

    var outbuf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&outbuf);
    const stdout = &stdout_writer.interface;
    while (true) {
        // Exit quietly when the pipe is closed (EPIPE), like GNU yes.
        stdout.writeAll(buf.items) catch break;
    }
}
