const std = @import("std");
const snake = @import("snake.zig");

pub fn main() !void {
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    const stdout = &stdout_writer.interface;

    var seed: u64 = seed_gen: {
        var s: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&s));
        break :seed_gen s;
    };
    var fast: bool = false;

    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();
    _ = args.next(); // skip argv[0]
    while (args.next()) |arg| {
        const seed_arg_prefix = "--seed=";
        if (std.mem.startsWith(u8, arg, seed_arg_prefix)) {
            seed = try std.fmt.parseInt(u64, arg[seed_arg_prefix.len..], 10);
        } else if (std.mem.eql(u8, arg, "--fast")) fast = true;
    }

    var game = snake.State.init(seed);

    while (game.snake.alive) {
        try game.render(stdout);
        game.tick(game.auto_play());
        if (!fast) std.Thread.sleep(100 * std.time.ns_per_ms);
    }
    try game.render(stdout); // final render

    try stdout.print("Final score: {}\n", .{game.score});
}

test snake {
    _ = @import("snake.zig");
}

test "fuzz" {
    const ByteMoves = packed struct(u8) {
        mv0: u2,
        mv1: u2,
        mv2: u2,
        mv3: u2,

        pub fn move_0(byte_moves: *const @This()) snake.Direction {
            return std.meta.intToEnum(snake.Direction, byte_moves.mv0) catch unreachable;
        }
        pub fn move_1(byte_moves: *const @This()) snake.Direction {
            return std.meta.intToEnum(snake.Direction, byte_moves.mv1) catch unreachable;
        }
        pub fn move_2(byte_moves: *const @This()) snake.Direction {
            return std.meta.intToEnum(snake.Direction, byte_moves.mv2) catch unreachable;
        }
        pub fn move_3(byte_moves: *const @This()) snake.Direction {
            return std.meta.intToEnum(snake.Direction, byte_moves.mv3) catch unreachable;
        }
    };

    const Context = struct {
        state: snake.State,

        fn testOne(ctx: *@This(), input: []const u8) anyerror!void {
            for (input) |byte| {
                const moves: ByteMoves = @bitCast(byte);
                ctx.state.tick(moves.move_0());
            }
        }
    };

    var ctx = Context{
        .state = snake.State.init(0),
    };
    try std.testing.fuzz(&ctx, Context.testOne, .{});
}
