const cursor_mod = @import("cursor.zig");

pub fn handle(editor: anytype, byte: u8) bool {
    if (editor.pending_g) {
        editor.pending_g = false;
        if (byte == 'g') editor.cursor.moveFileStart();
        return true;
    }

    if (byte >= '0' and byte <= '9') {
        editor.cursor.count = editor.cursor.count * 10 + (byte - '0');
        return true;
    }

    switch (byte) {
        'n' => return search(editor, false),
        'N' => return search(editor, true),
        'h' => editor.cursor.moveLeft(),
        'j' => editor.cursor.moveDown(&editor.document),
        'k' => editor.cursor.moveUp(&editor.document),
        'l' => editor.cursor.moveRight(&editor.document),
        '0' => editor.cursor.moveLineStart(&editor.document),
        '$' => editor.cursor.moveLineEnd(&editor.document),
        'w' => editor.cursor.moveWordForward(&editor.document),
        'b' => editor.cursor.moveWordBack(&editor.document),
        'e' => editor.cursor.moveWordEnd(&editor.document),
        'g' => editor.pending_g = true,
        'G' => moveFile(editor),
        else => return false,
    }
    return true;
}

fn search(editor: anytype, reverse: bool) bool {
    @import("search.zig").next(editor, if (reverse) !editor.search_forward else editor.search_forward);
    return true;
}

fn moveFile(editor: anytype) void {
    if (editor.cursor.count == 0) {
        editor.cursor.moveFileEnd(&editor.document);
    } else {
        var line: usize = 1;
        var pos: usize = 0;

        while (line < editor.cursor.count and pos < editor.document.len) {
            if (editor.document.buffer[pos] == '\n') line += 1;
            pos += 1;
        }

        editor.cursor.pos = cursor_mod.lineStart(&editor.document, pos);
    }
    editor.cursor.count = 0;
}
