const std = @import("std");

pub const Command = union(enum) { None, Ping, Echo: []const u8 };

pub const State = enum { Command, Payload };
pub const Token = enum { Payload, BString };

pub const Parser = struct {
    allocator: std.mem.Allocator,
    buf: []const u8,
    state: State,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Parser {
        return Parser{
            .allocator = allocator,
            .buf = input,
            .state = State.Command,
        };
    }

    pub fn parse(self: *Parser) !Command {
        var tokens = std.mem.tokenizeSequence(u8, self.buf, "\r\n");
        var command: Command = undefined;

        while (tokens.next()) |token| {
            const token_type = get_token_type(token);
            if (token_type != Token.Payload) continue;

            switch (self.state) {
                State.Command => {
                    command = get_command(token);
                    self.state = State.Payload;
                },
                State.Payload => {
                    self.state = State.Command;
                    switch (command) {
                        .Echo => command.Echo = token,
                        else => {},
                    }
                },
            }
        }

        return command;
    }
};

fn get_command(str: []const u8) Command {
    const str_eq = std.mem.eql;

    if (str_eq(u8, str, "PING")) return Command{ .Ping = {} };
    if (str_eq(u8, str, "ECHO")) return Command{ .Echo = "" };

    return Command.None;
}

fn get_token_type(str: []const u8) Token {
    switch (str[0]) {
        '*' => return Token.BString,
        '$' => return Token.BString,
        else => return Token.Payload,
    }
}
