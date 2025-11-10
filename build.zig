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
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run tests");
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    test_step.dependOn(&run_exe_tests.step);

    // See https://zigtools.org/zls/guides/build-on-save/.
    const check_step = b.step("check", "Check everything compiles");
    const check_exe = b.addExecutable(.{ .name = "check", .root_module = exe.root_module });
    const check_tests = b.addTest(.{ .root_module = exe.root_module });
    check_step.dependOn(&check_exe.step);
    check_step.dependOn(&check_tests.step);
}
