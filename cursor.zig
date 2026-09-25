const Document = @import("document.zig").Document;

fn isWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\n';
}

pub fn lineStart(document: *const Document, pos: usize) usize {
    var p = @min(pos, document.len);

    while (p > 0 and document.buffer[p - 1] != '\n') {
        p -= 1;
    }

    return p;
}

pub fn lineEnd(document: *const Document, pos: usize) usize {
    var p = @min(pos, document.len);

    while (p < document.len and document.buffer[p] != '\n') {
        p += 1;
    }

    return p;
}

pub fn column(document: *const Document, pos: usize) usize {
    return pos - lineStart(document, pos);
}

pub const Cursor = struct {
    count: usize = 0,
    pos: usize = 0,

    pub fn moveLeft(self: *Cursor) void {
        if (self.pos > 0) self.pos -= 1;
    }

    pub fn moveRight(self: *Cursor, document: *const Document) void {
        if (self.pos < document.len) self.pos += 1;
    }

    pub fn moveLineStart(self: *Cursor, document: *const Document) void {
        self.pos = lineStart(document, self.pos);
    }

    pub fn moveLineEnd(self: *Cursor, document: *const Document) void {
        self.pos = lineEnd(document, self.pos);
    }

    pub fn moveWordForward(self: *Cursor, document: *const Document) void {
        var p = self.pos;

        while (p < document.len and isWhitespace(document.buffer[p])) {
            if (document.buffer[p] == '\n') break;
            p += 1;
        }

        while (p < document.len and !isWhitespace(document.buffer[p])) {
            p += 1;
        }

        while (p < document.len and isWhitespace(document.buffer[p])) {
            if (document.buffer[p] == '\n') break;
            p += 1;
        }

        self.pos = p;
    }

    pub fn moveWordBack(self: *Cursor, document: *const Document) void {
        if (self.pos == 0) return;

        var p = self.pos - 1;

        while (p > 0 and isWhitespace(document.buffer[p])) {
            p -= 1;
        }

        while (p > 0 and !isWhitespace(document.buffer[p - 1])) {
            p -= 1;
        }

        self.pos = p;
    }

    pub fn moveWordEnd(self: *Cursor, document: *const Document) void {
        if (self.pos >= document.len) return;

        var p = self.pos;

        while (p < document.len and isWhitespace(document.buffer[p])) {
            p += 1;
        }

        if (p >= document.len) {
            self.pos = document.len;
            return;
        }

        while (p + 1 < document.len and !isWhitespace(document.buffer[p + 1])) {
            p += 1;
        }

        self.pos = p;
    }

    pub fn moveFileStart(self: *Cursor) void {
        self.pos = 0;
    }

    pub fn moveFileEnd(self: *Cursor, document: *const Document) void {
        self.pos = document.len;

        if (self.pos > 0 and document.buffer[self.pos - 1] == '\n') {
            self.pos -= 1;
        }
    }

    pub fn moveUp(self: *Cursor, document: *const Document) void {
        const start = lineStart(document, self.pos);
        if (start == 0) return;

        const wanted_col = column(document, self.pos);
        const previous_end = start - 1;
        const previous_start = lineStart(document, previous_end);
        const previous_len = previous_end - previous_start;

        self.pos = previous_start + @min(wanted_col, previous_len);
    }

    pub fn moveDown(self: *Cursor, document: *const Document) void {
        const end = lineEnd(document, self.pos);
        if (end >= document.len) return;

        const next_start = end + 1;
        const next_end = lineEnd(document, next_start);
        const wanted_col = column(document, self.pos);
        const next_len = next_end - next_start;

        self.pos = next_start + @min(wanted_col, next_len);
    }
};
