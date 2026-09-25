const render_mod = @import("render.zig");
const std = @import("std");
const cursor_mod = @import("cursor.zig");
const undo_mod = @import("undo.zig");
const input_mod = @import("input.zig");
const document_mod = @import("document.zig");
const register_mod = @import("register.zig");

pub const Mode = enum {
    normal,
    insert,
    command,
    visual,
    visual_line,
};

pub const EditKind = undo_mod.EditKind;
pub const Edit = undo_mod.Edit;

pub const Operator = enum {
    none,
    delete,
    change,
    yank,
};

pub const Document = document_mod.Document;

pub const Editor = struct {
    visual_start: ?usize = null,
    document: Document = .{},
    cursor: cursor_mod.Cursor = .{},

    mode: Mode = .normal,

    command: [128]u8 = undefined,
    command_len: usize = 0,
    search_active: bool = false,
    search_forward: bool = true,

    should_quit: bool = false,

    undo_stack: [256]Edit = undefined,
    undo_len: usize = 0,

    redo_stack: [256]Edit = undefined,
    redo_len: usize = 0,

    pending_g: bool = false,
    pending_operator: Operator = .none,
    register: register_mod.Register = .{},
    io: std.Io,
    allocator: std.mem.Allocator,

    pub fn recordEdit(self: *Editor, edit: Edit) void {
        undo_mod.recordEdit(self, edit);
    }

    pub fn insertRaw(self: *Editor, pos: usize, byte: u8) void {
        self.document.insertRaw(pos, byte);
    }

    pub fn deleteRaw(self: *Editor, pos: usize) void {
        self.document.deleteRaw(pos);
    }

    pub fn insertByte(self: *Editor, byte: u8) void {
        if (self.document.len >= self.document.buffer.len) return;

        const pos = self.cursor.pos;

        self.document.insertRaw(pos, byte);
        self.cursor.pos += 1;

        self.recordEdit(.{
            .kind = .insert,
            .pos = pos,
            .byte = byte,
        });
    }

    pub fn deleteBeforeCursor(self: *Editor) void {
        if (self.cursor.pos == 0) return;

        const pos = self.cursor.pos - 1;
        const byte = self.document.buffer[pos];

        self.document.deleteRaw(pos);
        self.cursor.pos -= 1;

        self.recordEdit(.{
            .kind = .delete,
            .pos = pos,
            .byte = byte,
        });
    }

    pub fn deleteAtCursor(self: *Editor) void {
        if (self.cursor.pos >= self.document.len) return;

        const pos = self.cursor.pos;
        const byte = self.document.buffer[pos];

        self.document.deleteRaw(pos);

        self.recordEdit(.{
            .kind = .delete,
            .pos = pos,
            .byte = byte,
        });
    }

    pub fn deleteRange(self: *Editor, start: usize, end: usize) void {
        if (start >= end) return;

        const actual_end = @min(end, self.document.len);

        var remaining = actual_end - start;

        while (remaining > 0 and start < self.document.len) {
            const byte = self.document.buffer[start];

            self.document.deleteRaw(start);

            self.recordEdit(.{
                .kind = .delete,
                .pos = start,
                .byte = byte,
            });

            remaining -= 1;
        }

        self.cursor.pos = @min(start, self.document.len);
    }

    pub fn undo(self: *Editor) void {
        undo_mod.undo(self);
    }

    pub fn redo(self: *Editor) void {
        undo_mod.redo(self);
    }

    pub fn open(self: *Editor, io: anytype, path: []const u8) void {
        self.document.open(io, path);
        self.cursor.pos = 0;
    }

    pub fn save(self: *Editor, io: anytype) void {
        self.document.save(io);
    }
    pub fn render(self: *const Editor) void {
        render_mod.render(self);
    }

    pub fn handleInput(self: *Editor, io: anytype, byte: u8) void {
        input_mod.handleInput(self, io, byte);
    }
};
pub fn render(editor: *const Editor) void {
    render_mod.render(editor);
}

pub fn handleInput(editor: *Editor, io: anytype, byte: u8) void {
    input_mod.handleInput(editor, io, byte);
}
