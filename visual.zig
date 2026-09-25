const std = @import("std");
const cursor_mod = @import("cursor.zig");

pub fn handle(editor: anytype, byte: u8) void {
    switch (byte) {
        27 => {
            editor.mode = .normal;
            editor.visual_start = null;
        },
        'v' => {
            if (editor.mode == .visual) {
                editor.mode = .normal;
                editor.visual_start = null;
            }
        },
        'V' => {
            if (editor.mode == .visual_line) {
                editor.mode = .normal;
                editor.visual_start = null;
            }
        },
        'h' => editor.cursor.moveLeft(),
        'l' => editor.cursor.moveRight(&editor.document),
        'j' => editor.cursor.moveDown(&editor.document),
        'k' => editor.cursor.moveUp(&editor.document),
        '0' => editor.cursor.moveLineStart(&editor.document),
        '$' => editor.cursor.moveLineEnd(&editor.document),
        'w' => editor.cursor.moveWordForward(&editor.document),
        'b' => editor.cursor.moveWordBack(&editor.document),
        'e' => editor.cursor.moveWordEnd(&editor.document),
        'y' => {
            if (editor.visual_start) |start| {
                const curr = editor.cursor.pos;
                var sel_start: usize = 0;
                var sel_end: usize = 0;
                if (editor.mode == .visual) {
                    sel_start = @min(start, curr);
                    sel_end = @max(start, curr) + 1;
                } else {
                    sel_start = cursor_mod.lineStart(&editor.document, @min(start, curr));
                    const line_e = cursor_mod.lineEnd(&editor.document, @max(start, curr));
                    sel_end = @min(line_e + 1, editor.document.len);
                }
                if (sel_start < sel_end) {
                    editor.register.set(editor.document.buffer[sel_start..@min(sel_end, editor.document.len)]);
                }
            }
            editor.mode = .normal;
            editor.visual_start = null;
        },
        'd', 'x' => {
            if (editor.visual_start) |start| {
                const curr = editor.cursor.pos;
                var sel_start: usize = 0;
                var sel_end: usize = 0;
                if (editor.mode == .visual) {
                    sel_start = @min(start, curr);
                    sel_end = @min(@max(start, curr) + 1, editor.document.len);
                } else {
                    sel_start = cursor_mod.lineStart(&editor.document, @min(start, curr));
                    const line_e = cursor_mod.lineEnd(&editor.document, @max(start, curr));
                    sel_end = @min(line_e + 1, editor.document.len);
                }
                if (sel_start < sel_end) {
                    editor.register.set(editor.document.buffer[sel_start..sel_end]);
                    var i = sel_end;
                while (i > sel_start) {
                    i -= 1;
                    editor.document.deleteRaw(i);
                }
                    editor.cursor.pos = sel_start;
                    if (editor.cursor.pos >= editor.document.len and editor.document.len > 0) {
                        editor.cursor.pos = editor.document.len - 1;
                    }
                }
            }
            editor.mode = .normal;
            editor.visual_start = null;
        },
        'c' => {
            if (editor.visual_start) |start| {
                const curr = editor.cursor.pos;
                var sel_start: usize = 0;
                var sel_end: usize = 0;
                if (editor.mode == .visual) {
                    sel_start = @min(start, curr);
                    sel_end = @min(@max(start, curr) + 1, editor.document.len);
                } else {
                    sel_start = cursor_mod.lineStart(&editor.document, @min(start, curr));
                    const line_e = cursor_mod.lineEnd(&editor.document, @max(start, curr));
                    sel_end = @min(line_e + 1, editor.document.len);
                }
                if (sel_start < sel_end) {
                    editor.register.set(editor.document.buffer[sel_start..sel_end]);
                    var i = sel_end;
                while (i > sel_start) {
                    i -= 1;
                    editor.document.deleteRaw(i);
                }
                    editor.cursor.pos = sel_start;
                }
            }
            editor.mode = .insert;
            editor.visual_start = null;
        },
        else => {},
    }
}
