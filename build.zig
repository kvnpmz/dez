const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zed",
        .root_module = b.createModule(.{
            .root_source_file = b.path("zed.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
            .link_libc = true,
        }),
    });
    b.installArtifact(exe);
}
