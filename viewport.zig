pub const Position = struct { row: usize, col: usize };

pub fn start(b: []const u8, cursor: usize, cols: usize, rows: usize) usize {
    if (cursor == 0 or cols == 0 or rows < 2) return 0;

    const limit = rows - 1;
    var lines: usize = 0;
    var col: usize = 1;
    var i: usize = 0;

    while (i < cursor and i < b.len) : (i += 1) {
        if (b[i] == '\n') {
            lines += 1;
            col = 1;
        } else {
            col += 1;
            if (col > cols) {
                lines += 1;
                col = 1;
            }
        }
    }

    if (lines < limit) return 0;

    const wanted = lines - limit + 1;
    lines = 0;
    col = 1;
    i = 0;

    while (i < b.len and lines < wanted) : (i += 1) {
        if (b[i] == '\n') {
            lines += 1;
            col = 1;
        } else {
            col += 1;
            if (col > cols) {
                lines += 1;
                col = 1;
            }
        }
    }

    return i;
}

pub fn cursorPosition(
    b: []const u8,
    top: usize,
    cursor: usize,
    cols: usize,
) Position {
    var row: usize = 1;
    var col: usize = 1;
    var i = top;

    while (i < cursor and i < b.len) : (i += 1) {
        if (b[i] == '\n') {
            row += 1;
            col = 1;
        } else {
            col += 1;
            if (col > cols) {
                row += 1;
                col = 1;
            }
        }
    }

    return .{ .row = row, .col = col };
}
