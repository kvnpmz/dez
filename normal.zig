const cursor_mod = @import("cursor.zig");
const normal_motion = @import("normal_motion.zig");
const std = @import("std");
const operator_mod = @import("operator.zig");
const register_mod = @import("register.zig");

pub fn handle(editor: anytype, byte: u8) void {
    if (operator_mod.handle(editor, byte)) return;
    if (normal_motion.handle(editor, byte)) return;
    switch (byte) {
        'y' => {
            editor.pending_operator = .yank;
        },
        'Y' => {
            const start = cursor_mod.lineStart(&editor.document, editor.cursor.pos);
            var finish = cursor_mod.lineEnd(&editor.document, editor.cursor.pos);
            if (finish < editor.document.len and editor.document.buffer[finish] == '\n') {
                finish += 1;
            }
            editor.register.set(editor.document.buffer[start..finish]);
            register_mod.copyToWayland(editor.io, editor.register.get());
        },
        'D' => {
            const start = editor.cursor.pos;
            const finish = cursor_mod.lineEnd(&editor.document, start);
            if (start < finish) {
                var i = finish;
                while (i > start) {
                    i -= 1;
                    editor.document.deleteRaw(i);
                }
                editor.cursor.pos = start;
            }
        },
        'C' => {
            const start = editor.cursor.pos;
            const finish = cursor_mod.lineEnd(&editor.document, start);
            if (start < finish) {
                var i = finish;
                while (i > start) {
                    i -= 1;
                    editor.document.deleteRaw(i);
                }
                editor.cursor.pos = start;
            }
            editor.mode = .insert;
        },
        'p' => register_mod.paste(editor, false),
        'P' => register_mod.paste(editor, true),
        27 => {
            const term = @import("terminal.zig");
            const next = term.readByte() orelse return;
            if (next == '[') {
                const arrow = term.readByte() orelse return;
                @import("input.zig").handleArrow(editor, arrow);
            }
        },
        ':' => {
            editor.mode = .command;
            editor.search_active = false;
            editor.command_len = 0;
        },
        '/' => {
            editor.mode = .command;
            editor.search_active = true;
            editor.command_len = 0;
        },
        'd' => {
            editor.pending_operator = .delete;
        },
        'c' => {
            editor.pending_operator = .change;
        },
        'v' => {
            editor.mode = .visual;
            editor.visual_start = editor.cursor.pos;
        },
        'V' => {
            editor.mode = .visual_line;
            editor.visual_start = editor.cursor.pos;
        },
        'i' => {
            editor.mode = .insert;
        },
        'a' => {
            if (editor.cursor.pos < editor.document.len) {
                editor.cursor.pos += 1;
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
            const end = cursor_mod.lineEnd(&editor.document, editor.cursor.pos);
            editor.cursor.pos = end;
            if (editor.cursor.pos < editor.document.len and
                editor.document.buffer[editor.cursor.pos] == '\n')
            {
                editor.cursor.pos += 1;
            }
            editor.insertByte('\n');
            editor.mode = .insert;
        },
        'O' => {
            const start = cursor_mod.lineStart(&editor.document, editor.cursor.pos);
            editor.cursor.pos = start;
            editor.insertByte('\n');
            editor.cursor.pos = start;
            editor.mode = .insert;
        },
        else => {},
    }
}
