const visual_actions = @import("visual_actions.zig");

pub fn handle(editor: anytype, byte: u8) void {
    if (visual_actions.handle(editor, byte)) return;

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
        else => {},
    }
}
