const cursor_mod = @import("cursor.zig");
const std = @import("std");
const operator_mod = @import("operator.zig");
const search_mod = @import("search.zig");
const register_mod = @import("register.zig");

pub fn handle(editor: anytype, byte: u8) void {
    if (operator_mod.handle(editor, byte)) return;
    if (editor.pending_g) {
        editor.pending_g = false;
        if (byte == 'g') {
            editor.cursor.moveFileStart();
        }
        return;
    }
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
                @import("input.zig").handleArrow(editor, next);
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
        'n' => search_mod.next(editor, editor.search_forward),
        'N' => search_mod.next(editor, !editor.search_forward),
        'h' => editor.cursor.moveLeft(),
        'j' => editor.cursor.moveDown(&editor.document),
        'k' => editor.cursor.moveUp(&editor.document),
        'l' => editor.cursor.moveRight(&editor.document),
        '0' => {
            editor.cursor.moveLineStart(&editor.document);
        },
        '$' => {
            editor.cursor.moveLineEnd(&editor.document);
        },
        'w' => {
            editor.cursor.moveWordForward(&editor.document);
        },
        'b' => {
            editor.cursor.moveWordBack(&editor.document);
        },
        'e' => {
            editor.cursor.moveWordEnd(&editor.document);
        },
        'g' => {
            editor.pending_g = true;
        },
        'G' => {
            editor.cursor.moveFileEnd(&editor.document);
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
