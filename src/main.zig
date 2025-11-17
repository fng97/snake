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
        // var move: ?Direction = null;
        // inputs: while (true) {
        //     const input = stdin.takeByte() catch |e| switch (e) {
        //         error.EndOfStream => break :inputs, // no more inputs
        //         else => return e,
        //     };
        //
        //     switch (input) {
        //         'w', 'W' => move = .up,
        //         'a', 'A' => move = .left,
        //         's', 'S' => move = .down,
        //         'd', 'D' => move = .right,
        //         else => {}, // ignore everything else
        //     }
        // }
        game.tick(game.autoPlay());
        if (!fast) std.Thread.sleep(100 * std.time.ns_per_ms);
    }
    try game.render(stdout); // final render

    try stdout.print("Final score: {}\n", .{game.score});
}

test snake {
    _ = @import("snake.zig");
}
