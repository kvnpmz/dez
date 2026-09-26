const std = @import("std");
const cursor_mod = @import("cursor.zig");

// :s/pattern/replacement/flags  (g flag supported)
// Note: literal string matching only, no regex
// Note: does not currently record undo entries
pub fn run(editor: anytype, command: []const u8) void {
    if (command.len < 2 or command[0] != 's') return;

    const delim = command[1];
    var pattern: []const u8 = "";
    var replacement: []const u8 = "";
    var flags: []const u8 = "";

    var section: usize = 0;
    var section_start: usize = 2;
    var i: usize = 2;

    while (i <= command.len) : (i += 1) {
        if (i == command.len or command[i] == delim) {
            switch (section) {
                0 => pattern     = command[section_start..i],
                1 => replacement = command[section_start..i],
                2 => flags       = command[section_start..i],
                else => {},
            }
            section += 1;
            section_start = i + 1;
            if (section >= 3) break;
        }
    }

    if (section == 0 or pattern.len == 0) return;

    const global = std.mem.indexOfScalar(u8, flags, 'g') != null;

    const line_start = cursor_mod.lineStart(&editor.document, editor.cursor.pos);
    var line_end = cursor_mod.lineEnd(&editor.document, editor.cursor.pos);

    var pos: usize = line_start;

    while (true) {
        if (pos > line_end) break;
        const avail = line_end + 1 - pos;
        if (avail < pattern.len) break;

        const haystack = editor.document.buffer[pos .. pos + avail];
        const match_offset = std.mem.indexOf(u8, haystack, pattern) orelse break;
        const match_pos = pos + match_offset;

        var d: usize = 0;
        while (d < pattern.len) : (d += 1) {
            editor.deleteRaw(match_pos);
        }

        var r: usize = 0;
        while (r < replacement.len) : (r += 1) {
            editor.insertRaw(match_pos + r, replacement[r]);
        }

        if (replacement.len >= pattern.len) {
            line_end += replacement.len - pattern.len;
        } else {
            const shrink = pattern.len - replacement.len;
            if (shrink > line_end - pos) break;
            line_end -= shrink;
        }

        if (!global) break;
        const step: usize = if (replacement.len > 0) replacement.len else 1;
        pos = match_pos + step;
    }
}
