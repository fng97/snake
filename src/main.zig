const std = @import("std");
const snake = @import("snake.zig");

pub fn main() !void {
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    const stdout = &stdout_writer.interface;

    // Use a fixed seed for now for deterministic behavior.
    var game = snake.State.init(std.testing.random_seed);

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
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
    try game.render(stdout); // final render

    try stdout.print("Final score: {}\n", .{game.score});
}

test snake {
    _ = @import("snake.zig");
}
