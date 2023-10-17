const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "rotkeapchen",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .{ .custom = ".." },
        .install_subdir = "docs",
    });

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    const bench_test = b.addExecutable(.{
        .name = "bench",
        .root_source_file = .{ .path = "src/bench.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_tests).step);
    const docs_step = b.step("docs", "Build the documentation");
    docs_step.dependOn(&install_docs.step);
    const bench_step = b.step("bench", "Run the benchmark test");
    bench_step.dependOn(&b.addRunArtifact(bench_test).step);
}
