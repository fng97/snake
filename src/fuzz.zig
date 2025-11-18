const std = @import("std");
const snake = @import("snake.zig");
const config = @import("config");

pub fn main() !void {
    const seed_global = blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    };
    var prng = std.Random.DefaultPrng.init(seed_global);
    const random = prng.random();

    std.debug.print("Starting fuzzer with global seed: {d}\n", .{seed_global});

    var best_score: u64 = 0;

    var seed = random.int(u64);
    var games: usize = 1;
    while (true) : ({
        seed = random.int(u64);
        games += 1;
    }) {
        var game = snake.State.init(seed);

        while (game.snake.alive) game.tick(game.auto_play());

        if (game.score > best_score) {
            std.debug.print(
                "Best score (of {d} games): {d}\n" ++
                    "\tzig build run -- --seed={d}  # ({s}) SCORE: {d}\n",
                .{ games, game.score, seed, config.commit, game.score },
            );
            best_score = game.score;
        }
    }
}
