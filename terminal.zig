const std = @import("std");

const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h");
});

var original_termios: c.struct_termios = undefined;

pub fn enableRawMode() void {
    _ = c.tcgetattr(0, &original_termios);

    var raw = original_termios;
    raw.c_lflag &= ~(@as(c.tcflag_t, c.ICANON) | @as(c.tcflag_t, c.ECHO));
    raw.c_lflag &= ~(@as(c.tcflag_t, c.ISIG));
    raw.c_iflag &= ~(@as(c.tcflag_t, c.IXON) | @as(c.tcflag_t, c.ICRNL));
    raw.c_oflag &= ~(@as(c.tcflag_t, c.OPOST));

    _ = c.tcsetattr(0, c.TCSAFLUSH, &raw);
}

pub fn disableRawMode() void {
    _ = c.tcsetattr(0, c.TCSAFLUSH, &original_termios);
}

pub fn writeAll(data: []const u8) void {
    var pos: usize = 0;

    while (pos < data.len) {
        const n = c.write(1, data.ptr + pos, data.len - pos);
        if (n <= 0) break;
        pos += @intCast(n);
    }
}

pub fn terminalSize() struct { rows: usize, cols: usize } {
    var ws: c.struct_winsize = undefined;

    if (c.ioctl(1, c.TIOCGWINSZ, &ws) == 0) {
        return .{
            .rows = if (ws.ws_row > 0) ws.ws_row else 24,
            .cols = if (ws.ws_col > 0) ws.ws_col else 80,
        };
    }

    return .{ .rows = 24, .cols = 80 };
}

pub fn readByte() ?u8 {
    var byte: u8 = undefined;

    const n = c.read(0, &byte, 1);

    if (n != 1) return null;

    return byte;
}

pub fn writeRaw(ptr: [*c]const u8, len: usize) void {
    _ = c.write(1, ptr, len);
}
