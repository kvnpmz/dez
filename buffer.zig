const document_mod = @import("document.zig");

pub const Buffer = struct {
    document: document_mod.Document = .{},
    cursor_pos: usize = 0,
};

pub const BufferList = struct {
    items: [32]Buffer = undefined,
    len: usize = 0,
    current: usize = 0,

    pub fn init() BufferList {
        var result = BufferList{};
        result.add();
        return result;
    }

    pub fn add(self: *BufferList) void {
        if (self.len >= self.items.len) return;

        self.items[self.len] = .{};
        self.current = self.len;
        self.len += 1;
    }

    pub fn next(self: *BufferList) void {
        if (self.len < 2) return;
        self.current = (self.current + 1) % self.len;
    }

    pub fn previous(self: *BufferList) void {
        if (self.len < 2) return;

        self.current = if (self.current == 0)
            self.len - 1
        else
            self.current - 1;
    }

    pub fn remove(self: *BufferList) void {
        if (self.len <= 1) return;

        var i = self.current;
        while (i + 1 < self.len) : (i += 1)
            self.items[i] = self.items[i + 1];

        self.len -= 1;

        if (self.current >= self.len)
            self.current = self.len - 1;
    }

    pub fn store(self: *BufferList, editor: anytype) void {
        const buffer = &self.items[self.current];
        buffer.document = editor.document;
        buffer.cursor_pos = editor.cursor.pos;
    }

    pub fn load(self: *BufferList, editor: anytype) void {
        const buffer = &self.items[self.current];
        editor.document = buffer.document;
        editor.cursor.pos = buffer.cursor_pos;
        editor.undo_len = 0;
        editor.redo_len = 0;
    }

    pub fn nextBuffer(self: *BufferList, editor: anytype) void {
        self.store(editor);
        self.next();
        self.load(editor);
    }

    pub fn previousBuffer(self: *BufferList, editor: anytype) void {
        self.store(editor);
        self.previous();
        self.load(editor);
    }

    pub fn newBuffer(self: *BufferList, editor: anytype) void {
        self.store(editor);
        self.add();
        self.load(editor);
    }

    pub fn deleteBuffer(self: *BufferList, editor: anytype) void {
        self.store(editor);
        self.remove();
        self.load(editor);
    }
};
