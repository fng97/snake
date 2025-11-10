const std = @import("std");

// TODO: Replace with Zig RNG
// Simple deterministic RNG: Marsaglia Xorshift
const Rng = struct {
    state: u64,

    pub fn init(seed: u64) Rng {
        return .{ .state = seed };
    }

    pub fn next(rng: *Rng) u64 {
        rng.state ^= rng.state << 13;
        rng.state ^= rng.state >> 17;
        rng.state ^= rng.state << 5;
        return rng.state;
    }

    pub fn range(rng: *Rng, min: u64, max: u64) u64 {
        return min + (rng.next() % (max - min));
    }
};

const Point = struct {
    x: i8,
    y: i8,

    pub fn eql(point: Point, other: Point) bool {
        return point.x == other.x and point.y == other.y;
    }

    pub fn move(point: Point, direction: Direction) Point {
        return switch (direction) {
            .up => .{ .x = point.x, .y = point.y - 1 },
            .down => .{ .x = point.x, .y = point.y + 1 },
            .left => .{ .x = point.x - 1, .y = point.y },
            .right => .{ .x = point.x + 1, .y = point.y },
        };
    }
};

const Direction = enum {
    up,
    down,
    left,
    right,

    pub fn opposite(direction: Direction) Direction {
        return switch (direction) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        };
    }
};

pub const State = struct {
    const frame_width = 20;
    const frame_height = 10;

    snake: Snake,
    food: Point,
    rng: Rng,
    tick_count: u32 = 0,
    score: u32 = 0,

    const Snake = struct {
        const max_length = frame_width * frame_height;

        body: [max_length]Point = undefined,
        len: usize = 0,
        direction: Direction = .right,
        alive: bool = true,
    };

    pub fn init(seed: u64) State {
        var game = State{
            .snake = .{
                .len = 3,
                .direction = .right,
            },
            .food = .{ .x = 0, .y = 0 },
            .rng = Rng.init(seed),
        };

        // Start snake in the middle.
        game.snake.body[0] = Point{ .x = frame_width / 2 - 0, .y = frame_height / 2 };
        game.snake.body[1] = Point{ .x = frame_width / 2 - 1, .y = frame_height / 2 };
        game.snake.body[2] = Point{ .x = frame_width / 2 - 2, .y = frame_height / 2 };
        game.snake.len = 3;

        game.spawn_food();

        return game;
    }

    fn get_snake(state: *const State) []const Point {
        return state.snake.body[0..state.snake.len];
    }

    fn spawn_food(state: *State) void {
        outer: for (0..State.Snake.max_length) |_| { // instead of a while loop
            const point = Point{
                .x = @as(i8, @intCast(state.rng.range(0, frame_width))),
                .y = @as(i8, @intCast(state.rng.range(0, frame_height))),
            };

            // Check if point would collide with snake.
            for (state.get_snake()) |segment| if (segment.eql(point)) continue :outer;

            state.food = point;
            return;
        }
    }

    pub fn tick(state: *State, input_direction: ?Direction) void {
        if (!state.snake.alive) return;
        defer state.tick_count += 1;

        // Make sure the snake can't go back on itself. Instead keep previous direction.
        if (input_direction) |direction| {
            if (state.snake.direction != direction.opposite()) state.snake.direction = direction;
        }

        // Calculate new head position
        const head = state.snake.body[0];
        const new_head = head.move(state.snake.direction);

        // Check if snake reached food.
        const grow = new_head.eql(state.food);
        if (grow) {
            state.score += 10;
            state.spawn_food();
        }

        // Check for collision with wall.
        if (new_head.x < 0 or new_head.x >= frame_width or
            new_head.y < 0 or new_head.y >= frame_height)
        {
            state.snake.alive = false;
            return;
        }

        // TODO: Should this omit the final segment of the snake?
        // Check for collision with self.
        for (state.get_snake()) |segment| if (segment.eql(new_head)) {
            state.snake.alive = false;
            return;
        };

        // Move snake (shift everything down).
        if (grow) state.snake.len += 1;
        var i = state.snake.len - 1;
        while (i > 0) : (i -= 1) state.snake.body[i] = state.snake.body[i - 1];
        state.snake.body[0] = new_head;
    }

    pub fn render(state: *const State, writer: anytype) !void {
        try writer.print("\x1b[2J\x1b[H", .{}); // clear screen

        // Draw top border.
        try writer.writeByte('+');
        for (0..frame_width) |_| try writer.writeByte('-');
        try writer.print("+\n", .{});

        // Draw board.
        for (0..frame_height) |y| {
            try writer.writeByte('|'); // side border
            for (0..frame_width) |x| {
                const point = Point{ .x = @intCast(x), .y = @intCast(y) };

                // Draw blank cell, snake, or food.
                try writer.writeByte(cell: {
                    if (point.eql(state.food)) break :cell '*';
                    for (state.get_snake(), 0..) |segment, i| if (segment.eql(point)) {
                        if (i == 0) { // head segment
                            if (!state.snake.alive) break :cell 'X';
                            break :cell '@';
                        }
                        break :cell '#'; // body segment
                    };
                    break :cell ' ';
                });
            }
            try writer.print("|\n", .{}); // side border
        }

        // Draw bottom border.
        try writer.writeByte('+');
        for (0..frame_width) |_| try writer.writeByte('-');
        try writer.print("+\n", .{});

        // Show game info.
        try writer.print("Score: {} | Length: {} | Tick: {}\n", .{
            state.score,
            state.snake.len,
            state.tick_count,
        });

        if (!state.snake.alive) try writer.print("GAME OVER!\n", .{});
    }

    // Auto-play with random movements.
    pub fn autoPlay(state: *State) Direction {
        // Simple strategy: mostly go towards food, sometimes random.
        const head = state.snake.body[0];

        // 70% chance to move towards food.
        if (state.rng.range(0, 10) < 7) {
            if (state.food.x > head.x and state.snake.direction != .left) {
                return .right;
            } else if (state.food.x < head.x and state.snake.direction != .right) {
                return .left;
            } else if (state.food.y > head.y and state.snake.direction != .up) {
                return .down;
            } else if (state.food.y < head.y and state.snake.direction != .down) {
                return .up;
            }
        }

        // Random valid move.
        const dirs = [_]Direction{ .up, .down, .left, .right };
        const choice = dirs[state.rng.range(0, 4)];

        // Don't go backwards.
        if (choice.opposite() != state.snake.direction) {
            return choice;
        }

        return state.snake.direction;
    }
};

pub fn main() !void {
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    const stdout = &stdout_writer.interface;

    // Use a fixed seed for now for deterministic behavior.
    var game = State.init(12345);

    while (game.snake.alive) {
        try game.render(stdout);
        game.tick(game.autoPlay());
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
    try game.render(stdout); // final render

    try stdout.print("Final score: {}\n", .{game.score});
}

pub const BufferWriter = struct {
    const allocator = std.testing.allocator;

    buffer: std.ArrayList(u8) = .empty,
    interface: std.Io.Writer = .{ .vtable = &.{ .drain = drain }, .buffer = &.{} },

    pub fn drain(w: *std.io.Writer, data: []const []const u8, _: usize) !usize {
        const buffer_writer: *BufferWriter = @fieldParentPtr("interface", w);
        var len: usize = 0;
        for (data) |slice| {
            buffer_writer.buffer.appendSlice(allocator, slice) catch unreachable;
            len += slice.len;
        }
        return len;
    }

    pub fn writer(buffer_writer: *const BufferWriter) *std.Io.Writer {
        return @constCast(&buffer_writer.interface);
    }

    pub fn deinit(buffer_writer: *BufferWriter) void {
        buffer_writer.buffer.deinit(allocator);
    }
};

test "is deterministic with output" {
    var game_a_output = BufferWriter{};
    defer game_a_output.deinit();
    var game_b_output = BufferWriter{};
    defer game_b_output.deinit();

    var game_a = State.init(42);
    var game_b = State.init(42);

    for (0..100) |_| {
        game_a.tick(game_a.autoPlay());
        game_b.tick(game_b.autoPlay());

        try game_a.render(game_a_output.writer());
        try game_b.render(game_b_output.writer());
    }

    try std.testing.expectEqualStrings(game_a_output.buffer.items, game_b_output.buffer.items);
}

test "is deterministic" {
    var game_a = State.init(42);
    var game_b = State.init(42);

    for (0..1000) |_| {
        game_a.tick(game_a.autoPlay());
        game_b.tick(game_b.autoPlay());

        try std.testing.expectEqual(game_a.score, game_b.score);
        try std.testing.expectEqual(game_a.food, game_b.food);
        try std.testing.expectEqualSlices(Point, game_a.get_snake(), game_b.get_snake());
    }
}
