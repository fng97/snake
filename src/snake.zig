const std = @import("std");

const frame_width = 20;
const frame_height = 10;

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

const Snake = struct {
    const max_length = frame_width * frame_height;

    body: [max_length]Point = undefined,
    len: usize = 0,
    direction: Direction = .right,
    alive: bool = true,
};

pub const State = struct {
    snake: Snake,
    food: Point,
    prng: std.Random.DefaultPrng,
    tick_count: u32 = 0,
    score: u32 = 0,

    fn rng(state: *State) std.Random {
        return state.prng.random();
    }

    pub fn init(seed: ?u64) State {
        var game = State{
            .snake = .{
                .len = 3,
                .direction = .right,
            },
            .food = .{ .x = 0, .y = 0 },
            .prng = .init(seed orelse std.testing.random_seed),
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
        outer: for (0..Snake.max_length) |_| { // instead of a while loop
            const point = Point{
                .x = state.rng().intRangeLessThan(i8, 0, frame_width),
                .y = state.rng().intRangeLessThan(i8, 0, frame_height),
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

        std.debug.assert(state.get_snake().len != 0);
        std.debug.assert(state.get_snake().len < Snake.max_length);

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

        // Check for collision with self.
        const len_to_check = if (grow) state.snake.len else state.snake.len - 1;
        for (state.snake.body[0..len_to_check]) |segment| if (segment.eql(new_head)) {
            state.snake.alive = false;
            return;
        };

        // TODO: Assert food doesn't overlap with snake by this point.
        // TODO: Check everything (snake, food) is within frame bounds.

        // Move snake (shift everything down).
        if (grow) state.snake.len += 1;
        var i = state.snake.len - 1;
        while (i > 0) : (i -= 1) state.snake.body[i] = state.snake.body[i - 1];
        state.snake.body[0] = new_head;

        // All segments should be adjacent.
        const snake = state.get_snake();
        for (0..snake.len - 1) |idx| {
            const curr = snake[idx];
            const next = snake[idx + 1];
            const dx = @abs(curr.x - next.x);
            const dy = @abs(curr.y - next.y);
            // Segments must be exactly 1 unit apart in one direction.
            const is_adjacent = (dx == 1 and dy == 0) or (dx == 0 and dy == 1);
            std.debug.assert(is_adjacent);
        }

        // No segments should overlap.
        for (snake, 0..) |a, idx| for (snake[idx + 1 ..]) |b| std.debug.assert(!a.eql(b));
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
        if (state.rng().intRangeLessThan(i8, 0, 10) < 7) {
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
        const choice = dirs[state.rng().intRangeLessThan(usize, 0, 4)];

        // Don't go backwards.
        if (choice.opposite() != state.snake.direction) {
            return choice;
        }

        return state.snake.direction;
    }
};

test "ticks are deterministic" {
    var game_a = State.init(null);
    var game_b = State.init(null);

    for (0..1000) |_| {
        game_a.tick(game_a.autoPlay());
        game_b.tick(game_b.autoPlay());

        try std.testing.expectEqual(game_a, game_b);
    }
}

const BufferWriter = struct {
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

test "terminal output is deterministic" {
    var game_a_output = BufferWriter{};
    defer game_a_output.deinit();
    var game_b_output = BufferWriter{};
    defer game_b_output.deinit();

    var game_a = State.init(null);
    var game_b = State.init(null);

    for (0..100) |_| {
        game_a.tick(game_a.autoPlay());
        game_b.tick(game_b.autoPlay());

        try game_a.render(game_a_output.writer());
        try game_b.render(game_b_output.writer());
    }

    try std.testing.expectEqualStrings(game_a_output.buffer.items, game_b_output.buffer.items);
}

test "snake can't reverse direction" {
    var game = State.init(null);
    game.snake.direction = .right;

    game.tick(.left); // try to go backwards
    try std.testing.expectEqual(Direction.right, game.snake.direction);

    game.tick(.up); // valid turn
    try std.testing.expectEqual(Direction.up, game.snake.direction);
}

test "eating food increases score and length" {
    var game = State.init(null);
    const initial_len = game.snake.len;
    const initial_score = game.score;

    // Place food directly in front of snake.
    game.snake.direction = .right;
    const head = game.snake.body[0];
    game.food = head.move(.right);

    game.tick(null); // move in previously set direction

    try std.testing.expectEqual(initial_len + 1, game.snake.len);
    try std.testing.expectEqual(initial_score + 10, game.score);
}

test "hitting wall kills snake" {
    var game = State.init(null);

    // Before:
    // +--
    // |@  <- head
    // |#
    // |#
    game.snake.body[0] = .{ .x = 0, .y = 0 };
    game.snake.body[1] = .{ .x = 0, .y = 1 };
    game.snake.body[2] = .{ .x = 0, .y = 2 };
    game.snake.direction = .up;
    try std.testing.expect(game.snake.alive);

    // After:
    // +X- <- head hits wall
    // |#
    // |#
    // |
    game.tick(.up);
    try std.testing.expect(!game.snake.alive);
}

test "snake collision with self" {
    var game = State.init(null);

    // Before:
    // +---
    // |#@  <- head
    // |### <- tail
    game.snake.len = 5;
    game.snake.body[0] = .{ .x = 1, .y = 0 };
    game.snake.body[1] = .{ .x = 0, .y = 0 };
    game.snake.body[2] = .{ .x = 0, .y = 1 };
    game.snake.body[3] = .{ .x = 1, .y = 1 };
    game.snake.body[4] = .{ .x = 2, .y = 1 };
    game.snake.direction = .right;
    try std.testing.expect(game.snake.alive);

    // After:
    // +---
    // |##
    // |#X  <- head hits tail
    game.tick(.down);
    try std.testing.expect(!game.snake.alive);
}

test "snake head moving to previous tail is ok" {
    var game = State.init(null);

    // Before:
    // +--
    // |#@ <- head
    // |## <- tail
    game.snake.len = 4;
    game.snake.body[0] = .{ .x = 1, .y = 0 };
    game.snake.body[1] = .{ .x = 0, .y = 0 };
    game.snake.body[2] = .{ .x = 0, .y = 1 };
    game.snake.body[3] = .{ .x = 1, .y = 1 };
    game.snake.direction = .right;
    try std.testing.expect(game.snake.alive);

    // After:
    // +--
    // |##
    // |#@ <- head moves to where tail was before (no collision)
    game.tick(.down);
    try std.testing.expect(game.snake.alive);
}

test "snake head at just-extended tail dies" {
    var game = State.init(null);

    // Start:
    // +---
    // |##@ <- head
    // |# * <- food
    // |###
    // |  # <- tail
    game.snake.len = 8;
    game.snake.body[0] = .{ .x = 2, .y = 0 };
    game.snake.body[1] = .{ .x = 1, .y = 0 };
    game.snake.body[2] = .{ .x = 0, .y = 0 };
    game.snake.body[3] = .{ .x = 0, .y = 1 };
    game.snake.body[4] = .{ .x = 0, .y = 2 };
    game.snake.body[5] = .{ .x = 1, .y = 2 };
    game.snake.body[6] = .{ .x = 2, .y = 2 };
    game.snake.body[7] = .{ .x = 2, .y = 3 };
    game.snake.direction = .right;
    game.food = .{ .x = 2, .y = 1 };
    try std.testing.expect(game.snake.alive);

    // Snake eats food:
    // +---
    // |###
    // |# @ <- head turns down and gobbles food
    // |### <- tail (extended in current tick but not yet rendered)
    game.tick(.down);
    try std.testing.expect(game.snake.alive);

    // Head collides with extended tail:
    // +---
    // |###
    // |# #
    // |##X <- head moves to where we just extended the tail (collision)
    game.tick(.down);
    try std.testing.expect(!game.snake.alive);
}

test "food never spawns on snake" {
    var game = State.init(null);

    for (0..100) |_| {
        game.spawn_food();
        for (game.get_snake()) |segment| try std.testing.expect(!segment.eql(game.food));
    }
}

test "dead snake doesn't move" {
    var game = State.init(null);
    game.snake.alive = false;

    const head_before = game.snake.body[0];
    const tick_before = game.tick_count;

    game.tick(.up);

    try std.testing.expect(game.snake.body[0].eql(head_before));
    try std.testing.expectEqual(tick_before, game.tick_count);
}

test "score correlates with length growth" {
    var game = State.init(null);
    const starting_len = 3;

    try std.testing.expectEqual(@as(u32, 0), game.score);
    try std.testing.expectEqual(@as(usize, starting_len), game.snake.len);

    for (0..5) |_| {
        game.snake.direction = .right;
        game.food = game.snake.body[0].move(.right);
        game.tick(null);
    }

    try std.testing.expectEqual(@as(u32, 50), game.score);
    try std.testing.expectEqual(@as(usize, starting_len + 5), game.snake.len);
}

test "fuzz: all segments stay in bounds when alive" {
    for (0..50) |seed| {
        var game = State.init(seed);

        for (0..300) |_| {
            if (!game.snake.alive) break;

            for (game.get_snake()) |segment| { // all segments must be in bounds
                try std.testing.expect(segment.x >= 0 and segment.x < frame_width);
                try std.testing.expect(segment.y >= 0 and segment.y < frame_height);
            }

            game.tick(game.autoPlay());
        }
    }
}
