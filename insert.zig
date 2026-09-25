pub fn handle(editor: anytype, byte: u8) void {
    switch (byte) {
        27 => {
            const term = @import("terminal.zig");
            const next = term.readByte() orelse {
                editor.mode = .normal;
                return;
            };

            if (next == '[') {
                const arrow = term.readByte() orelse return;
                @import("input.zig").handleArrow(editor, arrow);
            } else {
                editor.mode = .normal;
            }
        },

        ':' => {
            editor.mode = .command;
            editor.command_len = 0;
        },

        127, 8 => {
            editor.deleteBeforeCursor();
        },

        '\r', '\n' => {
            editor.insertByte('\n');
        },

        else => {
            if (byte >= 32) {
                editor.insertByte(byte);
            }
        },
    }
}
