const std = @import("std");
const net = std.net;

const Parser = @import("parser.zig").Parser;
const Command = @import("parser.zig").Command;

pub fn main() anyerror!void {
    const address = try net.Address.parseIp("127.0.0.1", 6379);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    std.log.info("listening at {any}\n", .{address});

    while (true) {
        const connection = try listener.accept();
        _ = try std.Thread.spawn(.{}, handle, .{connection.stream});
    }
}

fn handle(stream: std.net.Stream) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    while (true) {
        var buf: [128]u8 = undefined;

        const n = try stream.read(&buf);
        if (n == 0) break;

        var parser = Parser.init(allocator, buf[0..n]);

        const command = try parser.parse();

        switch (command) {
            .Ping => {
                try stream.writeAll("+PONG\r\n");
            },
            .Echo => |payload| {
                std.log.info("Echo: {s}\n", .{payload});
                try stream.writer().print("${d}\r\n{s}\r\n", .{ payload.len, payload });
            },
            .None => {
                try stream.writer().print("+Unknown command\r\n", .{});
            },
        }
    }
}
