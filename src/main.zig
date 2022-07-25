const std = @import("std");

pub fn main() anyerror!void {
    const a = std.heap.page_allocator;

    const args = try std.process.argsAlloc(a);

    var bytes = std.ArrayList(u8).init(a);
    if (args.len > 1) {
        for (args[1..args.len]) |arg, i| {
            if (i > 0) try bytes.writer().writeAll(" ");
            try bytes.writer().writeAll(arg);
        }
    } else {
        try bytes.writer().writeAll("y");
    }
    try bytes.writer().print("\n", .{});
    a.free(args);

    var buf = std.ArrayList(u8).init(a);
    const bufsiz = 64 * 1024;
    var copysize = bytes.items.len;

    var copies = bufsiz / copysize;
    while (copies > 0) {
        try buf.writer().writeAll(bytes.items);
        copies -= 1;
    }
    bytes.deinit();

    const writer = std.io.getStdOut().writer();
    while (true) {
        try writer.writeAll(buf.items);
    }
}
