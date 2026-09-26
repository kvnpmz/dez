const std = @import("std");
const search_mod = @import("search.zig");
const substitute_mod = @import("substitute.zig");

pub fn handle(editor: anytype, io: anytype, byte: u8) void {
    if (byte == 27) {
        editor.mode = .normal;
        editor.search_active = false;
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
        const command = editor.command[0..editor.command_len];

        if (editor.search_active) {
            editor.search_forward = true;
            search_mod.run(editor);
            editor.mode = .normal;
            editor.search_active = false;
            editor.command_len = 0;
            return;
        }

        if (std.mem.eql(u8, command, "q")) {
            editor.should_quit = true;
        } else if (std.mem.eql(u8, command, "bn")) {
            editor.nextBuffer();
        } else if (std.mem.eql(u8, command, "bp")) {
            editor.previousBuffer();
        } else if (std.mem.eql(u8, command, "bd")) {
            editor.deleteBuffer();
        } else if (std.mem.eql(u8, command, "enew")) {
            editor.newBuffer();
        } else if (std.mem.eql(u8, command, "w")) {
            editor.save(io);
        } else if (std.mem.eql(u8, command, "wq")) {
            editor.save(io);
            editor.should_quit = true;
        } else if (std.mem.startsWith(u8, command, "e ") and command.len > 2) {
            editor.open(io, command[2..]);
        } else if (command.len >= 2 and command[0] == 's' and !std.ascii.isAlphanumeric(command[1])) {
            substitute_mod.run(editor, command);
        } else if (std.fmt.parseInt(usize, command, 10) catch null) |line| {
            goToLine(editor, line);
        }

        editor.mode = .normal;
        editor.command_len = 0;
        return;
    }

    if (editor.command_len < editor.command.len) {
        editor.command[editor.command_len] = byte;
        editor.command_len += 1;
    }
}

fn goToLine(editor: anytype, line: usize) void {
    const target = if (line == 0) @as(usize, 1) else line;
    var current_line: usize = 1;
    var i: usize = 0;
    while (i < editor.document.len) : (i += 1) {
        if (current_line == target) {
            editor.cursor.pos = i;
            return;
        }
        if (editor.document.buffer[i] == '\n') {
            current_line += 1;
        }
    }
    editor.cursor.pos = if (editor.document.len > 0) editor.document.len - 1 else 0;
}
