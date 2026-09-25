const std = @import("std");

pub fn next(editor: anytype, forward: bool) void {
    const query = editor.command[0..editor.command_len];
    if (query.len == 0 or editor.document.len == 0) return;

    const len = editor.document.len;

    if (forward) {
        var pos = editor.cursor.pos + 1;
        while (pos + query.len <= len) : (pos += 1) {
            if (std.mem.startsWith(u8, editor.document.buffer[pos..], query)) {
                editor.cursor.pos = pos;
                return;
            }
        }
    } else {
        if (editor.cursor.pos == 0) return;

        var pos = editor.cursor.pos - 1;
        while (true) {
            if (pos + query.len <= len and
                std.mem.startsWith(u8, editor.document.buffer[pos..], query))
            {
                editor.cursor.pos = pos;
                return;
            }

            if (pos == 0) break;
            pos -= 1;
        }
    }
}

pub fn run(editor: anytype) void {
    editor.search_forward = true;
    next(editor, true);
}
