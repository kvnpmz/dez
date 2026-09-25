const std = @import("std");

pub const Document = struct {
    buffer: [8192]u8 = undefined,
    len: usize = 0,

    filename: [256]u8 = undefined,
    filename_len: usize = 0,

    pub fn insertRaw(self: *Document, pos: usize, byte: u8) void {
        if (self.len >= self.buffer.len) return;

        var i = self.len;
        while (i > pos) : (i -= 1) {
            self.buffer[i] = self.buffer[i - 1];
        }

        self.buffer[pos] = byte;
        self.len += 1;
    }

    pub fn deleteRaw(self: *Document, pos: usize) void {
        if (pos >= self.len) return;

        var i = pos;
        while (i + 1 < self.len) : (i += 1) {
            self.buffer[i] = self.buffer[i + 1];
        }

        self.len -= 1;
    }

    pub fn open(self: *Document, io: anytype, path: []const u8) void {
        if (path.len >= self.filename.len) return;

        @memcpy(self.filename[0..path.len], path);
        self.filename_len = path.len;

        if (std.Io.Dir.cwd().readFile(
            io,
            path,
            &self.buffer,
        )) |data| {
            self.len = data.len;
        } else |_| {
            self.len = 0;
        }
    }

    pub fn save(self: *Document, io: anytype) void {
        if (self.filename_len == 0) return;

        const file = std.Io.Dir.cwd().createFile(
            io,
            self.filename[0..self.filename_len],
            .{},
        ) catch return;

        defer file.close(io);

        var storage: [512]u8 = undefined;
        var writer = file.writer(io, &storage);

        writer.interface.writeAll(self.buffer[0..self.len]) catch {};
        writer.interface.flush() catch {};
    }
};
