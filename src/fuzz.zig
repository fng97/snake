const std = @import("std");
const snake = @import("snake.zig");

pub fn main() !void {
    const global_seed = std.testing.random_seed;
    var prng = std.Random.DefaultPrng.init(global_seed);
    const random = prng.random();

    std.debug.print("Starting fuzzer with global seed: {d}\n", .{global_seed});

    std.debug.print("Printing one (.) every million seeds", .{});
    var seed = random.int(u64);
    var i: usize = 1;
    while (true) : ({
        seed = random.int(u64);
        i += 1;
    }) {
        var game = snake.State.init(seed);
        while (game.snake.alive) {
            game.tick(game.autoPlay());
            if (i % 1_000_000 == 0) std.debug.print(".", .{});
        }
    }
}
