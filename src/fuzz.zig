const std = @import("std");
const snake = @import("snake.zig");
const config = @import("config");

var seed: u64 = undefined;

pub fn main() !void {
    var prng = std.Random.DefaultPrng.init(blk: {
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const random = prng.random();

    var best_score: u64 = 0;

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

pub const panic = std.debug.FullPanic(struct {
    /// Make sure we catch the seed in the case of a failure so it can be reproduced.
    fn panic_handler(msg: []const u8, first_trace_addr: ?usize) noreturn {
        std.debug.print(
            "FUZZING FAILURE: {s}. Reproduce the following panic with:\n" ++
                "\tzig build run -- --seed={d}  # PANIC ({s})\n",
            .{ msg, seed, config.commit },
        );
        std.debug.defaultPanic(msg, first_trace_addr);
    }
}.panic_handler);
