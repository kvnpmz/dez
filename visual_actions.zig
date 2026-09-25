const cursor_mod = @import("cursor.zig");

pub fn handle(editor: anytype, byte: u8) bool {
    switch (byte) {
        'y' => {
            if (editor.visual_start) |start| {
                const range = selection(editor, start, editor.cursor.pos);
                if (range.start < range.end) {
                    editor.register.set(editor.document.buffer[range.start..range.end]);
                }
            }
            finish(editor, .normal);
            return true;
        },
        'd', 'x' => {
            if (editor.visual_start) |start| {
                const range = selection(editor, start, editor.cursor.pos);
                if (range.start < range.end) {
                    editor.register.set(editor.document.buffer[range.start..range.end]);
                    var i = range.end;
                    while (i > range.start) {
                        i -= 1;
                        editor.document.deleteRaw(i);
                    }
                    editor.cursor.pos = range.start;
                    if (editor.cursor.pos >= editor.document.len and editor.document.len > 0) {
                        editor.cursor.pos = editor.document.len - 1;
                    }
                }
            }
            finish(editor, .normal);
            return true;
        },
        'c' => {
            if (editor.visual_start) |start| {
                const range = selection(editor, start, editor.cursor.pos);
                if (range.start < range.end) {
                    editor.register.set(editor.document.buffer[range.start..range.end]);
                    var i = range.end;
                    while (i > range.start) {
                        i -= 1;
                        editor.document.deleteRaw(i);
                    }
                    editor.cursor.pos = range.start;
                }
            }
            finish(editor, .insert);
            return true;
        },
        else => return false,
    }
}

fn selection(editor: anytype, start: usize, curr: usize) struct { start: usize, end: usize } {
    if (editor.mode == .visual) {
        return .{
            .start = @min(start, curr),
            .end = @min(@max(start, curr) + 1, editor.document.len),
        };
    }

    const first = @min(start, curr);
    const last = @max(start, curr);
    return .{
        .start = cursor_mod.lineStart(&editor.document, first),
        .end = @min(cursor_mod.lineEnd(&editor.document, last) + 1, editor.document.len),
    };
}

fn finish(editor: anytype, mode: @TypeOf(editor.mode)) void {
    editor.mode = mode;
    editor.visual_start = null;
}
