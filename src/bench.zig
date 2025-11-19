const std = @import("std");
const snake = @import("snake.zig");

pub fn main() !void {
    const seed_global = blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    };
    var prng = std.Random.DefaultPrng.init(seed_global);
    const random = prng.random();

    std.debug.print("Starting bench with global seed: {d}\n", .{seed_global});

    var timer = try std.time.Timer.start();

    const games = 100_000;
    var i: usize = 0;
    var seed = random.int(u64);
    var ticks: usize = 1;
    while (i < games) : ({
        i += 1;
        seed = random.int(u64);
    }) {
        var game = snake.State.init(seed);
        while (game.snake.alive) : (ticks += 1) game.tick(game.auto_play());
    }

    const runtime_ns = timer.read();

    std.debug.print(
        "Games [{d}] Time (ms) [{d}] Ticks [{d}] Average game (ns) [{d}] Average tick (ns) [{d}]\n",
        .{
            games,
            runtime_ns / std.time.ns_per_ms,
            ticks,
            runtime_ns / games,
            runtime_ns / ticks,
        },
    );
}
