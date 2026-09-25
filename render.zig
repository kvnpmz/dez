const std = @import("std");
const Editor = @import("editor.zig").Editor;
const terminal = @import("terminal.zig");

pub fn render(editor: *const Editor) void {
    const size = terminal.terminalSize();

    // Home + clear screen.
    terminal.writeAll("\x1b[H\x1b[2J");

    // Determine visual selection range if in visual mode
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
                // Visual line mode: select full lines
                const line_s = @import("cursor.zig").lineStart(&editor.document, @min(start, curr));
                const line_e = @import("cursor.zig").lineEnd(&editor.document, @max(start, curr));
                sel_start = line_s;
                sel_end = @min(line_e + 1, editor.document.len);
            }
        }
    }

    // Only draw the portion that fits vertically.
    var row: usize = 1;
    var col: usize = 1;
    var i: usize = 0;

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
