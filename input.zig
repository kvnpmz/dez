const visual_mod = @import("visual.zig");
const command_mod = @import("command.zig");
const cursor_mod = @import("cursor.zig");
const insert_mod = @import("insert.zig");
const normal_mod = @import("normal.zig");
const terminal = @import("terminal.zig");
const macro_mod = @import("macro.zig");

pub fn handleInput(editor: anytype, io: anytype, byte: u8) void {
    if (editor.mode == .normal) {
        if (macro_mod.handleNormal(byte)) |macro| {
            for (macro) |replay_byte| {
                handleInput(editor, io, replay_byte);
            }
            return;
        }
    }

    macro_mod.record(byte);

    switch (editor.mode) {
        .command => command_mod.handle(editor, io, byte),
        .insert => insert_mod.handle(editor, byte),
        .normal => normal_mod.handle(editor, byte),
        .visual, .visual_line => visual_mod.handle(editor, byte),
    }
}

pub fn handleArrow(editor: anytype, byte: u8) void {
    switch (byte) {
         'A' => editor.cursor.moveUp(&editor.document),
         'B' => editor.cursor.moveDown(&editor.document),
         'C' => editor.cursor.moveRight(&editor.document),
         'D' => editor.cursor.moveLeft(),
        '3' => {
            const third = terminal.readByte() orelse return;
            if (third == '~') {
                editor.deleteAtCursor();
            }
        },
        'H' => {
            editor.cursor.pos = cursor_mod.lineStart(&editor.document, editor.cursor.pos);
        },
        'F' => {
            editor.cursor.pos = cursor_mod.lineEnd(&editor.document, editor.cursor.pos);
        },
         else => {},
    }
}
