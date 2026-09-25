const cursor_mod = @import("cursor.zig");
const std = @import("std");
const operator_mod = @import("operator.zig");
const search_mod = @import("search.zig");
const register_mod = @import("register.zig");
fn yank(editor: anytype, start: usize, finish: usize) void {
    if (start >= finish) return;
    const end = @min(finish, editor.document.len);
    editor.register.set(editor.document.buffer[start..end]);
    register_mod.copyToWayland(editor.io, editor.register.get());
}
fn paste(editor: anytype, before: bool) void {
    _ = register_mod.pasteFromWayland(
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
        'p' => paste(editor, false),
        'P' => paste(editor, true),
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
