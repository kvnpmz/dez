const Editor = @import("editor.zig").Editor;

pub const EditKind = enum {
    insert,
    delete,
};

pub const Edit = struct {
    kind: EditKind,
    pos: usize,
    byte: u8,
};

pub fn recordEdit(self: *Editor, edit: Edit) void {
    if (self.undo_len < self.undo_stack.len) {
        self.undo_stack[self.undo_len] = edit;
        self.undo_len += 1;
    } else {
        var i: usize = 1;
        while (i < self.undo_stack.len) : (i += 1) {
            self.undo_stack[i - 1] = self.undo_stack[i];
        }
        self.undo_stack[self.undo_stack.len - 1] = edit;
    }
    self.redo_len = 0;
}

pub fn insertRaw(self: *Editor, pos: usize, byte: u8) void {
    if (self.document.len >= self.document.buffer.len) return;
    var i = self.document.len;
    while (i > pos) {
        self.document.buffer[i] = self.document.buffer[i - 1];
        i -= 1;
    }
    self.document.buffer[pos] = byte;
    self.document.len += 1;
}

pub fn deleteRaw(self: *Editor, pos: usize) void {
    if (pos >= self.document.len) return;
    var i = pos;
    while (i + 1 < self.document.len) : (i += 1) {
        self.document.buffer[i] = self.document.buffer[i + 1];
    }
    self.document.len -= 1;
}

pub fn undo(self: *Editor) void {
    if (self.undo_len == 0) return;
    self.undo_len -= 1;
    const edit = self.undo_stack[self.undo_len];
    switch (edit.kind) {
        .insert => {
            deleteRaw(self, edit.pos);
            self.cursor.pos = edit.pos;
        },
        .delete => {
            insertRaw(self, edit.pos, edit.byte);
            self.cursor.pos = edit.pos + 1;
        },
    }
    if (self.redo_len < self.redo_stack.len) {
        self.redo_stack[self.redo_len] = edit;
        self.redo_len += 1;
    }
}

pub fn redo(self: *Editor) void {
    if (self.redo_len == 0) return;
    self.redo_len -= 1;
    const edit = self.redo_stack[self.redo_len];
    switch (edit.kind) {
        .insert => {
            insertRaw(self, edit.pos, edit.byte);
            self.cursor.pos = edit.pos + 1;
        },
        .delete => {
            deleteRaw(self, edit.pos);
            self.cursor.pos = edit.pos;
        },
    }
    if (self.undo_len < self.undo_stack.len) {
        self.undo_stack[self.undo_len] = edit;
        self.undo_len += 1;
    }
}
