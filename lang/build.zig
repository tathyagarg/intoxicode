const std = @import("std");

pub fn build(b: *std.Build) !void {
    const all_targets = b.option(bool, "all", "Build for all major platforms") orelse false;
    const optimize = b.standardOptimizeOption(.{});

    const default_target = b.standardTargetOptions(.{});

    const targets = if (all_targets)
        &[_]std.zig.CrossTarget{
            .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
            .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
            .{ .cpu_arch = .x86_64, .os_tag = .macos },
        }
    else
        &[_]std.zig.CrossTarget{
            .{ .cpu_arch = .x86_64, .os_tag = .macos },
        };

    for (targets) |target| {
        const name = try std.fmt.allocPrint(
            b.allocator,
            "intoxicode-{s}-{s}",
            .{
                @tagName(target.os_tag.?),
                @tagName(target.cpu_arch.?),
            },
        );

        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(target),
            .optimize = optimize,
            .strip = true,
        });
        exe.linkLibC();
        b.installArtifact(exe);
    }

    const run_cmd = b.addRunArtifact(b.addExecutable(.{
        .name = "intoxicode-run",
        .root_source_file = b.path("src/main.zig"),
        .target = default_target,
        .optimize = optimize,
    }));
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("tests/root.zig"),
        .target = default_target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");

    const intoxicode = b.addModule("intoxicode", .{
        .root_source_file = b.path("src/root.zig"),
    });
    exe_unit_tests.root_module.addImport("intoxicode", intoxicode);

    test_step.dependOn(&run_exe_unit_tests.step);
}
