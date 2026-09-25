const std = @import("std");
const Editor = @import("editor.zig").Editor;
const terminal = @import("terminal.zig");
const viewport = @import("viewport.zig");

pub fn render(editor: *const Editor) void {
    const size = terminal.terminalSize();

    terminal.writeAll("\x1b[H\x1b[2J");

    const top = viewport.start(
        editor.document.buffer[0..editor.document.len],
        editor.cursor.pos,
        size.cols,
        size.rows,
    );

    var sel_start: usize = 0;
    var sel_end: usize = 0;
    var in_visual = false;

    if (editor.mode == .visual or editor.mode == .visual_line) {
        if (editor.visual_start) |start| {
            in_visual = true;
            const curr = editor.cursor.pos;
            if (editor.mode == .visual) {
                sel_start = @min(start, curr);
                sel_end = @max(start, curr);
            } else {
                const line_s = @import("cursor.zig").lineStart(&editor.document, @min(start, curr));
                const line_e = @import("cursor.zig").lineEnd(&editor.document, @max(start, curr));
                sel_start = line_s;
                sel_end = @min(line_e + 1, editor.document.len);
            }
        }
    }

    var row: usize = 1;
    var col: usize = 1;
    var i: usize = top;

    var highlighting = false;

    while (i < editor.document.len and row <= size.rows - 1) : (i += 1) {
        const should_highlight = in_visual and (i >= sel_start and i <= sel_end);

        if (should_highlight and !highlighting) {
            terminal.writeAll("\x1b[7m"); // Reverse video for highlight
            highlighting = true;
        } else if (!should_highlight and highlighting) {
            terminal.writeAll("\x1b[0m"); // Reset style
            highlighting = false;
        }

        const ch = editor.document.buffer[i];

        if (ch == '\n') {
            if (highlighting) {
                terminal.writeAll("\x1b[0m");
            }
            terminal.writeAll("\r\n");
            row += 1;
            col = 1;
            if (should_highlight) {
                terminal.writeAll("\x1b[7m");
                highlighting = true;
            } else {
                highlighting = false;
            }
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

    if (highlighting) {
        terminal.writeAll("\x1b[0m");
    }

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

        const cursor = viewport.cursorPosition(
            editor.document.buffer[0..editor.document.len],
            top,
            cursor_pos,
            size.cols,
        );
        const cr = cursor.row;
        const cc = cursor.col;

        const mode_str = switch (editor.mode) {
            .normal => " NORMAL ",
            .insert => " INSERT ",
            .visual => " VISUAL ",
            .visual_line => " VISUAL LINE ",
            .command => " COMMAND ",
        };

        const status_text = std.fmt.bufPrint(
            &out,
            "\x1b[{};1H\x1b[7m{s}\x1b[0m Row: {}, Col: {}",
            .{ size.rows, mode_str, cr, cc },
        ) catch "";
        terminal.writeAll(status_text);

        const pos = std.fmt.bufPrint(
            &out,
            "\x1b[{};{}H",
            .{ cr, cc },
        ) catch return;

        terminal.writeAll(pos);
    }
}
