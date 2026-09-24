const std = @import("std");

const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h");
});

var original_termios: c.struct_termios = undefined;

fn enableRawMode() void {
    _ = c.tcgetattr(0, &original_termios);

    var raw = original_termios;
    raw.c_lflag &= ~(@as(c.tcflag_t, c.ICANON) | @as(c.tcflag_t, c.ECHO));
    raw.c_lflag &= ~(@as(c.tcflag_t, c.ISIG));
    raw.c_iflag &= ~(@as(c.tcflag_t, c.IXON) | @as(c.tcflag_t, c.ICRNL));
    raw.c_oflag &= ~(@as(c.tcflag_t, c.OPOST));

    _ = c.tcsetattr(0, c.TCSAFLUSH, &raw);
}

fn disableRawMode() void {
    _ = c.tcsetattr(0, c.TCSAFLUSH, &original_termios);
}

fn writeAll(data: []const u8) void {
    var pos: usize = 0;

    while (pos < data.len) {
        const n = c.write(1, data.ptr + pos, data.len - pos);
        if (n <= 0) break;
        pos += @intCast(n);
    }
}

fn terminalSize() struct { rows: usize, cols: usize } {
    var ws: c.struct_winsize = undefined;

    if (c.ioctl(1, c.TIOCGWINSZ, &ws) == 0) {
        return .{
            .rows = if (ws.ws_row > 0) ws.ws_row else 24,
            .cols = if (ws.ws_col > 0) ws.ws_col else 80,
        };
    }

    return .{ .rows = 24, .cols = 80 };
}

const Mode = enum {
    normal,
    insert,
    command,
};

const EditKind = enum {
    insert,
    delete,
};

const Edit = struct {
    kind: EditKind,
    pos: usize,
    byte: u8,
};

const Editor = struct {
    buffer: [8192]u8 = undefined,
    len: usize = 0,

    cursor: usize = 0,

    mode: Mode = .insert,

    command: [128]u8 = undefined,
    command_len: usize = 0,

    filename: [256]u8 = undefined,
    filename_len: usize = 0,

    should_quit: bool = false,

    undo_stack: [256]Edit = undefined,
    undo_len: usize = 0,

    redo_stack: [256]Edit = undefined,
    redo_len: usize = 0,
    pending_g: bool = false,

    fn lineStart(self: *const Editor, pos: usize) usize {
        var p = if (pos > self.len) self.len else pos;

        while (p > 0 and self.buffer[p - 1] != '\n') {
            p -= 1;
        }

        return p;
    }

    fn lineEnd(self: *const Editor, pos: usize) usize {
        var p = if (pos > self.len) self.len else pos;

        while (p < self.len and self.buffer[p] != '\n') {
            p += 1;
        }

        return p;
    }

    fn column(self: *const Editor, pos: usize) usize {
        return pos - self.lineStart(pos);
    }

    fn recordEdit(self: *Editor, edit: Edit) void {
        if (self.undo_len < self.undo_stack.len) {
            self.undo_stack[self.undo_len] = edit;
            self.undo_len += 1;
        } else {
            var i: usize = 1;
            while (i < self.undo_stack.len) : (i += 1) {
                self.undo_stack[i - 1] = self.undo_stack[i];
            }

            self.undo_stack[self.undo_stack.len - 1] = edit;
        }

        self.redo_len = 0;
    }

    fn insertRaw(self: *Editor, pos: usize, byte: u8) void {
        if (self.len >= self.buffer.len) return;

        var i = self.len;

        while (i > pos) {
            self.buffer[i] = self.buffer[i - 1];
            i -= 1;
        }

        self.buffer[pos] = byte;
        self.len += 1;
    }

    fn deleteRaw(self: *Editor, pos: usize) void {
        if (pos >= self.len) return;

        var i = pos;

        while (i + 1 < self.len) : (i += 1) {
            self.buffer[i] = self.buffer[i + 1];
        }

        self.len -= 1;
    }

    fn insertByte(self: *Editor, byte: u8) void {
        if (self.len >= self.buffer.len) return;

        const pos = self.cursor;

        self.insertRaw(pos, byte);
        self.cursor += 1;

        self.recordEdit(.{
            .kind = .insert,
            .pos = pos,
            .byte = byte,
        });
    }

    fn deleteBeforeCursor(self: *Editor) void {
        if (self.cursor == 0) return;

        const pos = self.cursor - 1;
        const byte = self.buffer[pos];

        self.deleteRaw(pos);
        self.cursor -= 1;

        self.recordEdit(.{
            .kind = .delete,
            .pos = pos,
            .byte = byte,
        });
    }

    fn deleteAtCursor(self: *Editor) void {
        if (self.cursor >= self.len) return;

        const pos = self.cursor;
        const byte = self.buffer[pos];

        self.deleteRaw(pos);

        self.recordEdit(.{
            .kind = .delete,
            .pos = pos,
            .byte = byte,
        });
    }

    fn undo(self: *Editor) void {
        if (self.undo_len == 0) return;

        self.undo_len -= 1;
        const edit = self.undo_stack[self.undo_len];

        switch (edit.kind) {
            .insert => {
                self.deleteRaw(edit.pos);
                self.cursor = edit.pos;
            },

            .delete => {
                self.insertRaw(edit.pos, edit.byte);
                self.cursor = edit.pos + 1;
            },
        }

        if (self.redo_len < self.redo_stack.len) {
            self.redo_stack[self.redo_len] = edit;
            self.redo_len += 1;
        }
    }

    fn redo(self: *Editor) void {
        if (self.redo_len == 0) return;

        self.redo_len -= 1;
        const edit = self.redo_stack[self.redo_len];

        switch (edit.kind) {
            .insert => {
                self.insertRaw(edit.pos, edit.byte);
                self.cursor = edit.pos + 1;
            },

            .delete => {
                self.deleteRaw(edit.pos);
                self.cursor = edit.pos;
            },
        }

        if (self.undo_len < self.undo_stack.len) {
            self.undo_stack[self.undo_len] = edit;
            self.undo_len += 1;
        }
    }

    fn moveLeft(self: *Editor) void {
        if (self.cursor > 0) {
            self.cursor -= 1;
        }
    }

    fn moveRight(self: *Editor) void {
        if (self.cursor < self.len) {
            self.cursor += 1;
        }
    }

    fn moveLineStart(self: *Editor) void {
        self.cursor = self.lineStart(self.cursor);
    }

    fn moveLineEnd(self: *Editor) void {
        self.cursor = self.lineEnd(self.cursor);
    }

    fn moveWordForward(self: *Editor) void {
        if (self.cursor >= self.len) return;

        var p = self.cursor;

        while (p < self.len and
            (self.buffer[p] == ' ' or self.buffer[p] == '\t'))
        {
            p += 1;
        }

        while (p < self.len and
            self.buffer[p] != '\n' and
            self.buffer[p] != ' ' and
            self.buffer[p] != '\t')
        {
            p += 1;
        }

        while (p < self.len and
            self.buffer[p] != '\n' and
            (self.buffer[p] == ' ' or self.buffer[p] == '\t'))
        {
            p += 1;
        }

        self.cursor = p;
    }

    fn moveWordBack(self: *Editor) void {
        if (self.cursor == 0) return;

        var p = self.cursor - 1;

        while (p > 0 and
            (self.buffer[p] == ' ' or
             self.buffer[p] == '\t' or
             self.buffer[p] == '\n'))
        {
            p -= 1;
        }

        while (p > 0 and
            self.buffer[p - 1] != ' ' and
            self.buffer[p - 1] != '\t' and
            self.buffer[p - 1] != '\n')
        {
            p -= 1;
        }

        self.cursor = p;
    }

    fn moveWordEnd(self: *Editor) void {
        if (self.cursor >= self.len) return;

        var p = self.cursor;

        while (p < self.len and
            (self.buffer[p] == ' ' or
             self.buffer[p] == '\t' or
             self.buffer[p] == '\n'))
        {
            p += 1;
        }

        if (p >= self.len) {
            self.cursor = self.len;
            return;
        }

        while (p + 1 < self.len and
            self.buffer[p + 1] != ' ' and
            self.buffer[p + 1] != '\t' and
            self.buffer[p + 1] != '\n')
        {
            p += 1;
        }

        self.cursor = p;
    }

    fn moveFileStart(self: *Editor) void {
        self.cursor = 0;
    }

    fn moveFileEnd(self: *Editor) void {
        self.cursor = self.len;

        if (self.cursor > 0 and self.buffer[self.cursor - 1] == '\n') {
            self.cursor -= 1;
        }
    }

    fn moveUp(self: *Editor) void {
        const start = self.lineStart(self.cursor);

        if (start == 0) return;

        const wanted_col = self.column(self.cursor);

        // Previous line ends immediately before `start`.
        const previous_end = start - 1;
        const previous_start = self.lineStart(previous_end);

        const previous_len = previous_end - previous_start;

        self.cursor =
            previous_start + @min(wanted_col, previous_len);
    }

    fn moveDown(self: *Editor) void {
        const end = self.lineEnd(self.cursor);

        if (end >= self.len) return;

        const next_start = end + 1;
        const next_end = self.lineEnd(next_start);

        const wanted_col = self.column(self.cursor);
        const next_len = next_end - next_start;

        self.cursor =
            next_start + @min(wanted_col, next_len);
    }

    fn open(self: *Editor, io: anytype, path: []const u8) void {
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

        self.cursor = 0;
    }

    fn save(self: *Editor, io: anytype) void {
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

fn render(editor: *const Editor) void {
    const size = terminalSize();

    // Home + clear screen.
    writeAll("\x1b[H\x1b[2J");

    // Only draw the portion that fits vertically.
    var row: usize = 1;
    var col: usize = 1;
    var i: usize = 0;

    while (i < editor.len and row <= size.rows - 1) : (i += 1) {
        const ch = editor.buffer[i];

        if (ch == '\n') {
            writeAll("\r\n");
            row += 1;
            col = 1;
        } else {
            if (col <= size.cols) {
                _ = c.write(1, &editor.buffer[i], 1);
            }

            col += 1;

            if (col > size.cols) {
                row += 1;
                col = 1;
            }
        }
    }

    // Status / command line.
    var out: [512]u8 = undefined;

    if (editor.mode == .command) {
        const text = std.fmt.bufPrint(
            &out,
            "\x1b[{};1H:{s}",
            .{
                size.rows,
                editor.command[0..editor.command_len],
            },
        ) catch return;

        writeAll(text);
    } else {
        const cursor_pos = editor.cursor;

        var cr: usize = 1;
        var cc: usize = 1;

        var p: usize = 0;

        while (p < cursor_pos) : (p += 1) {
            if (editor.buffer[p] == '\n') {
                cr += 1;
                cc = 1;
            } else {
                cc += 1;

                if (cc > size.cols) {
                    cr += 1;
                    cc = 1;
                }
            }
        }

        // Put cursor at calculated screen position.
        const pos = std.fmt.bufPrint(
            &out,
            "\x1b[{};{}H",
            .{ cr, cc },
        ) catch return;

        writeAll(pos);
    }
}

fn readByte() ?u8 {
    var byte: u8 = undefined;

    const n = c.read(0, &byte, 1);

    if (n != 1) return null;

    return byte;
}

fn handleArrow(editor: *Editor, first: u8) void {
    if (first != '[') return;

    const second = readByte() orelse return;

    switch (second) {
        'A' => editor.moveUp(),
        'B' => editor.moveDown(),
        'C' => editor.moveRight(),
        'D' => editor.moveLeft(),

        '3' => {
            const third = readByte() orelse return;

            if (third == '~') {
                editor.deleteAtCursor();
            }
        },

        'H' => {
            editor.cursor = editor.lineStart(editor.cursor);
        },

        'F' => {
            editor.cursor = editor.lineEnd(editor.cursor);
        },

        else => {},
    }
}

fn handleCommand(editor: *Editor, io: anytype, byte: u8) void {
    if (byte == 27) {
        editor.mode = .insert;
        editor.command_len = 0;
        return;
    }

    if (byte == 127 or byte == 8) {
        if (editor.command_len > 0) {
            editor.command_len -= 1;
        }

        return;
    }

    if (byte == '\r' or byte == '\n') {
        const command =
            editor.command[0..editor.command_len];

        if (std.mem.eql(u8, command, "q")) {
            editor.should_quit = true;
        } else if (std.mem.eql(u8, command, "w")) {
            editor.save(io);
            editor.mode = .insert;
        } else if (std.mem.eql(u8, command, "wq")) {
            editor.save(io);
            editor.should_quit = true;
        }

        editor.command_len = 0;
        return;
    }

    if (editor.command_len < editor.command.len) {
        editor.command[editor.command_len] = byte;
        editor.command_len += 1;
    }
}

fn handleInput(editor: *Editor, io: anytype, byte: u8) void {
    switch (editor.mode) {
        .command => {
            handleCommand(editor, io, byte);
        },

        .insert => {
            switch (byte) {
                27 => {
                    const next = readByte() orelse {
                        editor.mode = .normal;
                        return;
                    };

                    if (next == '[') {
                        handleArrow(editor, next);
                    } else {
                        editor.mode = .normal;
                    }
                },

                ':' => {
                    editor.mode = .command;
                    editor.command_len = 0;
                },

                127, 8 => {
                    editor.deleteBeforeCursor();
                },

                '\r', '\n' => {
                    editor.insertByte('\n');
                },

                else => {
                    if (byte >= 32) {
                        editor.insertByte(byte);
                    }
                },
            }
        },

        .normal => {
            if (editor.pending_g) {
                editor.pending_g = false;

                if (byte == 'g') {
                    editor.moveFileStart();
                }

                return;
            }

            switch (byte) {
                27 => {
                    const next = readByte() orelse return;

                    if (next == '[') {
                        handleArrow(editor, next);
                    }
                },

                ':' => {
                    editor.mode = .command;
                    editor.command_len = 0;
                },

                'h' => editor.moveLeft(),
                'j' => editor.moveDown(),
                'k' => editor.moveUp(),
                'l' => editor.moveRight(),

                '0' => {
                    editor.moveLineStart();
                },

                '$' => {
                    editor.moveLineEnd();
                },

                'w' => {
                    editor.moveWordForward();
                },

                'b' => {
                    editor.moveWordBack();
                },

                'e' => {
                    editor.moveWordEnd();
                },

                'g' => {
                    editor.pending_g = true;
                },

                'G' => {
                    editor.moveFileEnd();
                },

                'i' => {
                    editor.mode = .insert;
                },

                'a' => {
                    if (editor.cursor < editor.len) {
                        editor.cursor += 1;
                    }

                    editor.mode = .insert;
                },

                'x' => {
                    editor.deleteAtCursor();
                },

                'u' => {
                    editor.undo();
                },

                18 => {
                    editor.redo();
                },

                'o' => {
                    const end = editor.lineEnd(editor.cursor);

                    editor.cursor = end;

                    if (editor.cursor < editor.len and
                        editor.buffer[editor.cursor] == '\n')
                    {
                        editor.cursor += 1;
                    }

                    editor.insertByte('\n');
                    editor.mode = .insert;
                },

                'O' => {
                    const start = editor.lineStart(editor.cursor);

                    editor.cursor = start;
                    editor.insertByte('\n');
                    editor.cursor = start;

                    editor.mode = .insert;
                },

                else => {},
            }
        },
    }
}

pub fn main(init: std.process.Init) !void {
    enableRawMode();
    defer disableRawMode();

    writeAll("\x1b[2J\x1b[H\x1b[?25h");

    defer writeAll("\x1b[2J\x1b[H");

    var editor = Editor{};

    const args =
        init.minimal.args.toSlice(
            init.arena.allocator(),
        ) catch &[_][:0]const u8{};

    if (args.len > 1) {
        editor.open(init.io, args[1]);
    }

    render(&editor);

    while (!editor.should_quit) {
        const byte = readByte() orelse break;

        handleInput(&editor, init.io, byte);

        render(&editor);
    }
}
