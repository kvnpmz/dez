const cursor_mod = @import("cursor.zig");

pub fn handle(editor: anytype, byte: u8) void {
    if (editor.pending_g) {
        editor.pending_g = false;

        if (byte == 'g') {
            editor.cursor.moveFileStart();
        }

        return;
    }

    switch (byte) {
        27 => {
            const term = @import("terminal.zig");
            const next = term.readByte() orelse return;

            if (next == '[') {
                @import("input.zig").handleArrow(editor, next);
            }
        },

        ':' => {
            editor.mode = .command;
            editor.command_len = 0;
        },

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
