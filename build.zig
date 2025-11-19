const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "snake",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);
    const run_step = b.step("run", "Run the game");
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run tests");
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    test_step.dependOn(&run_exe_tests.step);

    const fuzz = b.addExecutable(.{
        .name = "fuzz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fuzz.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const fuzz_step = b.step("fuzz", "Run the fuzzer");
    const fuzz_cmd = b.addRunArtifact(fuzz);
    fuzz_step.dependOn(&fuzz_cmd.step);
    // Make git commit available so that displayed fuzzing runs are reproducible from the commit and
    // the seed.
    const config = b.addOptions();
    const commit = std.mem.trimRight(u8, b.run(&.{
        "git",
        "rev-parse",
        "--verify",
        "--short", // short hash is fine for a small project like this
        "HEAD",
    }), "\n");
    config.addOption([]const u8, "commit", commit);
    fuzz.root_module.addOptions("config", config);

    const bench = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const bench_step = b.step("bench", "Run the bench");
    const bench_cmd = b.addRunArtifact(bench);
    bench_step.dependOn(&bench_cmd.step);

    // See https://zigtools.org/zls/guides/build-on-save/.
    const check_step = b.step("check", "Check everything compiles");
    const check_exe = b.addExecutable(.{ .name = "check_exe", .root_module = exe.root_module });
    const check_tests = b.addTest(.{ .root_module = exe.root_module });
    const check_fuzz = b.addExecutable(.{ .name = "check_exe", .root_module = fuzz.root_module });
    check_step.dependOn(&check_exe.step);
    check_step.dependOn(&check_tests.step);
    check_step.dependOn(&check_fuzz.step);
}
