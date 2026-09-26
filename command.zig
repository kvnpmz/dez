const std = @import("std");
const search_mod = @import("search.zig");

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
