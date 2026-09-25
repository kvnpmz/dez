const cursor_mod = @import("cursor.zig");
const register_mod = @import("register.zig");

pub fn handle(editor: anytype, byte: u8) bool {
    if (editor.pending_operator == .none) return false;

    const operator = editor.pending_operator;
    editor.pending_operator = .none;

    if (byte == 27) return true;

    if (operator == .yank) {
        if (byte == 'y') {
            const start = cursor_mod.lineStart(&editor.document, editor.cursor.pos);
            var finish = cursor_mod.lineEnd(&editor.document, editor.cursor.pos);

            if (finish < editor.document.len and
                editor.document.buffer[finish] == '\n')
            {
                finish += 1;
            }

            editor.register.set(editor.document.buffer[start..finish]);
            register_mod.copyToWayland(editor.io, editor.register.get());
            return true;
        }

        const start = editor.cursor.pos;
        var finish = start;

        switch (byte) {
            'w' => {
                editor.cursor.moveWordForward(&editor.document);
                finish = editor.cursor.pos;
            },
            'b' => {
                editor.cursor.moveWordBack(&editor.document);
                finish = editor.cursor.pos;
            },
            'e' => {
                editor.cursor.moveWordEnd(&editor.document);
                if (editor.cursor.pos < editor.document.len) editor.cursor.pos += 1;
                finish = editor.cursor.pos;
            },
            '$' => finish = cursor_mod.lineEnd(&editor.document, start),
            '0' => finish = cursor_mod.lineStart(&editor.document, start),
            else => return true,
        }

        const range_start = @min(start, finish);
        const range_end = @max(start, finish);
        if (range_start < range_end) {
            editor.register.set(editor.document.buffer[range_start..range_end]);
            register_mod.copyToWayland(editor.io, editor.register.get());
        }
        return true;
    }

    if ((operator == .delete and byte == 'd') or
        (operator == .change and byte == 'c'))
    {
        const start = cursor_mod.lineStart(&editor.document, editor.cursor.pos);
        const end = cursor_mod.lineEnd(&editor.document, editor.cursor.pos);

        var finish = end;

        if (finish < editor.document.len and
            editor.document.buffer[finish] == '\n')
        {
            finish += 1;
        }

        apply(editor, start, finish, operator == .change);
        return true;
    }

    const start = editor.cursor.pos;
    var finish = start;

    switch (byte) {
        'w' => {
            editor.cursor.moveWordForward(&editor.document);
            finish = editor.cursor.pos;
        },

        'b' => {
            editor.cursor.moveWordBack(&editor.document);
            finish = editor.cursor.pos;
        },

        'e' => {
            editor.cursor.moveWordEnd(&editor.document);

            if (editor.cursor.pos < editor.document.len) {
                editor.cursor.pos += 1;
            }

            finish = editor.cursor.pos;
        },

        '$' => finish = cursor_mod.lineEnd(&editor.document, start),

        '0' => {
            finish = cursor_mod.lineStart(&editor.document, start);
        },

        else => return true,
    }

    apply(
        editor,
        @min(start, finish),
        @max(start, finish),
        operator == .change,
    );

    return true;
}

fn apply(editor: anytype, start: usize, finish: usize, change: bool) void {
    if (start >= finish) return;

    editor.deleteRange(start, finish);

    if (change) {
        editor.mode = .insert;
    }
}
