const std = @import("std");

pub const Register = struct {
    buffer: [8192]u8 = undefined,
    len: usize = 0,

    pub fn set(self: *Register, data: []const u8) void {
        self.len = @min(data.len, self.buffer.len);
        @memcpy(self.buffer[0..self.len], data[0..self.len]);
    }

    pub fn get(self: *const Register) []const u8 {
        return self.buffer[0..self.len];
    }
};

pub fn copyToWayland(io: std.Io, data: []const u8) void {
    var child = std.process.spawn(io, .{
        .argv = &.{"wl-copy"},
        .stdin = .pipe,
        .stdout = .ignore,
        .stderr = .ignore,
    }) catch return;

    if (child.stdin) |*stdin| {
        std.Io.File.writeStreamingAll(stdin.*, io, data) catch {};
        std.Io.File.close(stdin.*, io);
        child.stdin = null;
    }
}

pub fn pasteFromWayland(
    allocator: std.mem.Allocator,
    io: std.Io,
    register: *Register,
) bool {
    const result = std.process.run(allocator, io, .{
        .argv = &.{ "wl-paste", "--no-newline" },
        .stdout_limit = .limited(8192),
        .stderr_limit = .limited(1024),
    }) catch return false;

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) return false;

    register.set(result.stdout);
    return true;
}

pub fn yank(editor: anytype, start: usize, finish: usize) void {
    if (start >= finish) return;
    const end = @min(finish, editor.document.len);
    editor.register.set(editor.document.buffer[start..end]);
    copyToWayland(editor.io, editor.register.get());
}

pub fn paste(editor: anytype, before: bool) void {
    _ = pasteFromWayland(
        editor.allocator,
        editor.io,
        &editor.register,
    );
    const data = editor.register.get();
    if (data.len == 0) return;
    var pos = editor.cursor.pos;
    if (!before and pos < editor.document.len) pos += 1;
    for (data) |byte| {
        if (editor.document.len >= editor.document.buffer.len) break;
        editor.document.insertRaw(pos, byte);
        pos += 1;
    }
    editor.cursor.pos = if (pos > 0) pos - 1 else 0;
}
