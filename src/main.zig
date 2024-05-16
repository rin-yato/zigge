const std = @import("std");
const net = std.net;

const ArenaAllocator = std.heap.ArenaAllocator;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const address = try net.Address.parseIp("127.0.0.1", 8080);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    std.log.info("listening at {any}\n", .{address});

    while (true) {
        const connection = try listener.accept();

        var client_arena = ArenaAllocator.init(allocator);
        const client = try client_arena.allocator().create(Client);
        errdefer client_arena.deinit();

        client.* = Client.init(client_arena, connection.stream);

        _ = try std.Thread.spawn(.{}, Client.handle, .{client});
    }
}

const Client = struct {
    arena: ArenaAllocator,
    stream: net.Stream,
    handler: Handler,

    pub fn init(arena: ArenaAllocator, stream: net.Stream) Client {
        return .{
            .stream = stream,
            .arena = arena,
            .handler = Handler.init(arena, stream),
        };
    }

    fn handle(self: *Client) !void {
        defer self.arena.deinit();
        defer self.stream.close();

        const stream = self.stream;
        _ = try stream.write("Welcome to Zigge Key & Value!!\n");

        while (true) {
            var buf: [100]u8 = undefined;

            const n = try stream.read(&buf);
            if (n == 0) return;

            const msg = buf[0 .. n - 1];

            std.log.info("received message: {s}\n", .{msg});

            const case = std.meta.stringToEnum(Event, msg) orelse {
                _ = try stream.write("unknown command\n");
                continue;
            };

            try switch (case) {
                .Ping => self.handler.Ping(),
            };
        }
    }
};

const Event = enum { Ping };

const Handler = struct {
    arena: ArenaAllocator,
    stream: net.Stream,

    pub fn init(arena: ArenaAllocator, stream: net.Stream) Handler {
        return .{
            .stream = stream,
            .arena = arena,
        };
    }

    fn Ping(self: *Handler) !void {
        const stream = self.stream;
        _ = try stream.write("Pong\n");
    }
};
