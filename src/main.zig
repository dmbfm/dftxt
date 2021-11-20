const std = @import("std");
const zdf = @import("zdf");

const Args = zdf.Args;
const Allocator = std.mem.Allocator;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = &arena.allocator;

const stdout = std.io.getStdOut().writer();

fn usage() !void {
    try stdout.writeAll("Usage: dftxt [file]\n");
}

const Scanner = struct {
    cur: usize,
    buf: []const u8,

    pub fn init(buf: []const u8) Scanner {
        return .{
            .cur = 0,
            .buf = buf,
        };
    }

    pub fn skipWhitespace(self: *Scanner) void {
        while (self.cur < self.buf.len and self.buf[self.cur] == ' ') {
            self.cur += 1;
        }
    }

    pub fn skip(self: *Scanner, ch: u8) usize {
        var n: usize = 0;
        while (self.cur < self.buf.len and self.buf[self.cur] == ch) {
            self.cur += 1;
            n += 1;
        }

        return n;
    }

    pub fn eat(self: *Scanner) ?u8 {
        if (self.cur == self.buf.len) {
            return null;
        }

        defer self.cur += 1;
        return self.buf[self.cur];
    }

    pub fn peek(self: Scanner) ?u8 {
        if (self.cur == self.buf.len) {
            return null;
        }

        return self.buf[self.cur];
    }

    pub fn eof(self: Scanner) bool {
        return self.cur >= self.buf.len;
    }

    pub fn leftover(self: Scanner) []const u8 {
        return self.buf[self.cur..];
    }

    pub fn uneat(self: *Scanner) void {
        if (self.cur > 0) {
            self.cur -= 1;
        }
    }
};

fn out(bytes: []const u8) !void {
    try stdout.writeAll(bytes);
}

fn outByte(byte: u8) !void {
    try stdout.writeByte(byte);
}

// const TokenType = enum {};

const ContextType = enum {
    Heading,
    Paragraph,
    List,
    None,
};

const ListContext = struct {
    indent: usize,
    depth: usize,
};

const Context = union(ContextType) {
    Heading: usize,
    Paragraph: void,
    List: ListContext,
    None: void,

    pub fn open(self: Context) !void {
        switch (self) {
            .Heading => |level| {
                try out(try std.fmt.allocPrint(allocator, "<h{}>", .{level}));
            },
            .Paragraph => {
                try out("\n<p>\n");
            },
            .List => |list| {
                var i: usize = 0;
                while (i < list.depth) {
                    try out("\n<ul>\n");
                    i += 1;
                }
            },
            else => {},
        }
    }

    pub fn close(self: Context) !void {
        switch (self) {
            .Heading => |level| {
                try out(try std.fmt.allocPrint(allocator, "</h{}>", .{level}));
            },
            .Paragraph => {
                try out("\n</p>\n");
            },
            .List => |list| {
                var i: usize = 0;
                while (i < list.depth) {
                    try out("\n</ul>\n");
                    i += 1;
                }
            },

            else => {},
        }
    }

    pub fn change(self: *Context, new: Context) !void {
        var tag: ContextType = self.*;
        if (tag != new) {
            try self.close();
            try new.open();

            self.* = new;
        }
    }
};

const State = struct {
    ctx: Context,
};

fn parseLine(state: *State, line: []const u8) !void {
    // try stdout.print("\n[parseLine]: '{s}'\n", .{line});

    var s = Scanner.init(line);
    var n = s.skip(' ');

    // Blank/empty line...
    if (s.eof()) {
        try state.ctx.change(Context.None);
    }

    if (s.eat()) |ch| {
        switch (ch) {
            '*' => {
                try state.ctx.close();
                var level = s.skip('*') + 1;
                try out(try std.fmt.allocPrint(allocator, "<h{}>", .{level}));
                try out(s.leftover());
                try out(try std.fmt.allocPrint(allocator, "</h{}>", .{level}));
                state.ctx = Context.None;
            },
            '-' => {
                if (state.ctx == Context.List) {
                    var oldDepth = state.ctx.List.depth;
                    var currentDepth = n + 1;

                    if (currentDepth > oldDepth) {
                        var i: usize = 0;
                        while (i < (currentDepth - oldDepth)) {
                            try out("\n<ul>\n");
                            i += 1;
                        }
                    } else if (currentDepth < oldDepth) {
                        var i: usize = 0;
                        while (i < (oldDepth - currentDepth)) {
                            try out("\n</ul>\n");
                            i += 1;
                        }
                    }

                    state.ctx.List.depth = currentDepth;
                } else {
                    // We don't really use indent for now...
                    try state.ctx.change(Context{ .List = .{ .indent = 0, .depth = n + 1 } });
                }

                try out("<li>");
                try out(s.leftover());
                try out("</li>");
            },
            ' ' => {},
            else => {
                try state.ctx.change(Context.Paragraph);
                s.uneat();
                while (s.eat()) |ch2| {
                    switch (ch2) {
                        '[' => {
                            var next: u8 = 0;
                            if (s.peek()) |peek| {
                                next = peek;
                            }

                            if (next == '[') {
                                _ = s.eat();

                                try out("<a href=\"\">[[");
                                while (s.eat()) |ch3| {
                                    switch (ch3) {
                                        ']' => {
                                            if (s.peek()) |peek2| {
                                                if (peek2 == ']') {
                                                    try out("]]</a>");
                                                    _ = s.eat();
                                                    break;
                                                }
                                            }
                                        },
                                        else => {
                                            try outByte(ch3);
                                        },
                                    }
                                }
                            }

                            try out("<a href=\"");
                            while (s.eat()) |ch3| {
                                switch (ch3) {
                                    '|' => {
                                        try out("\">");
                                    },
                                    ']' => {
                                        try out("</a>");
                                        break;
                                    },
                                    else => {
                                        try outByte(ch3);
                                    },
                                }
                            }
                        },
                        else => {
                            try outByte(ch2);
                        },
                    }
                }

                try outByte(' ');
            },
        }
    } else {}
}

fn run(filename: []const u8) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    var contents = try file.readToEndAlloc(allocator, 1024 * 1024 * 1024);

    var state = State{ .ctx = Context.None };

    var i: usize = 0;
    var lineStart: usize = 0;
    while (i < contents.len) {
        if (contents[i] == '\n') {
            try parseLine(&state, contents[lineStart..i]);
            lineStart = i + 1;
        }

        i += 1;
    }

    try state.ctx.close();
}

pub fn main() anyerror!void {
    defer arena.deinit();

    var args = try Args.init(allocator);
    defer args.deinit();

    if (args.argc < 2) {
        try usage();
        return;
    }

    try run(args.argv[1]);
}
