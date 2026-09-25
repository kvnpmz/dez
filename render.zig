const std = @import("std");
const Editor = @import("editor.zig").Editor;
const terminal = @import("terminal.zig");

pub fn render(editor: *const Editor) void {
    const size = terminal.terminalSize();

    // Home + clear screen.
    terminal.writeAll("\x1b[H\x1b[2J");

    // Only draw the portion that fits vertically.
    var row: usize = 1;
    var col: usize = 1;
    var i: usize = 0;

    while (i < editor.document.len and row <= size.rows - 1) : (i += 1) {
        const ch = editor.document.buffer[i];

        if (ch == '\n') {
            terminal.writeAll("\r\n");
            row += 1;
            col = 1;
        } else {
            if (col <= size.cols) {
                terminal.writeRaw(&editor.document.buffer[i], 1);
            }

            col += 1;

            if (col > size.cols) {
                row += 1;
                col = 1;
            }
        }
    }

    // Status / command line.
    var out: [512]u8 = undefined;

    if (editor.mode == .command) {
        const text = std.fmt.bufPrint(
            &out,
            "\x1b[{};1H:{s}",
            .{
                size.rows,
                editor.command[0..editor.command_len],
            },
        ) catch return;

        terminal.writeAll(text);
    } else {
        const cursor_pos = editor.cursor.pos;

        var cr: usize = 1;
        var cc: usize = 1;

        var p: usize = 0;

        while (p < cursor_pos) : (p += 1) {
            if (editor.document.buffer[p] == '\n') {
                cr += 1;
                cc = 1;
            } else {
                cc += 1;

                if (cc > size.cols) {
                    cr += 1;
                    cc = 1;
                }
            }
        }

        // Put cursor at calculated screen position.
        const pos = std.fmt.bufPrint(
            &out,
            "\x1b[{};{}H",
            .{ cr, cc },
        ) catch return;

        terminal.writeAll(pos);
    }
}
