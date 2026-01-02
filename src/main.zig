const std = @import("std");

pub fn main() anyerror!void {
    const a = std.heap.page_allocator;

    const args = try std.process.argsAlloc(a);

    var bytes = std.ArrayList(u8){};
    var bytesWriter = bytes.writer(a);
    if (args.len > 1) {
        for (args[1..args.len], 1..args.len) |arg, i| {
            if (i > 0) try bytesWriter.writeAll(" ");
            try bytesWriter.writeAll(arg);
        }
    } else {
        try bytesWriter.writeAll("y");
    }
    try bytesWriter.writeAll("\n");
    a.free(args);

    var buf = std.ArrayList(u8){};
    const bufsiz = 64 * 1024;
    const copysize = bytes.items.len;
    const bufWriter = buf.writer(a);

    var copies = bufsiz / copysize;
    while (copies > 0) {
        try bufWriter.writeAll(bytes.items);
        copies -= 1;
    }
    bytes.deinit(a);

    var outbuf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&outbuf);
    const stdout = &stdout_writer.interface;
    while (true) {
        try stdout.writeAll(buf.items);
    }
}
