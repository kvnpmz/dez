const std = @import("std");
const term = @import("terminal.zig");
const editor_mod = @import("editor.zig");

pub fn main(init: std.process.Init) !void {
    term.enableRawMode();
    defer term.disableRawMode();

    term.writeAll("\x1b[2J\x1b[H\x1b[?25h");

    defer term.writeAll("\x1b[2J\x1b[H");

    var editor = editor_mod.Editor{
        .io = init.io,
        .allocator = init.gpa,
    };

    const args =
        init.minimal.args.toSlice(
            init.arena.allocator(),
        ) catch &[_][:0]const u8{};

    if (args.len > 1) {
        editor.open(init.io, args[1]);
    }

    editor_mod.render(&editor);

    while (!editor.should_quit) {
        const byte = term.readByte() orelse break;

        editor_mod.handleInput(&editor, init.io, byte);

        editor_mod.render(&editor);
    }
}
