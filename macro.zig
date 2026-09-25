var data: [26][256]u8 = undefined;
var lens: [26]usize = [_]usize{0} ** 26;
var recording: bool = false;
var pending_record: bool = false;
var pending_replay: bool = false;
var record_reg: usize = 0;
var last_reg: usize = 0;

pub fn handleNormal(byte: u8) ?[]const u8 {
    if (pending_record) {
        pending_record = false;
        if (byte >= 'a' and byte <= 'z') {
            record_reg = byte - 'a';
            lens[record_reg] = 0;
            recording = true;
        }
        return &[_]u8{};
    }

    if (pending_replay) {
        pending_replay = false;
        if (byte == '@') return data[last_reg][0..lens[last_reg]];
        if (byte >= 'a' and byte <= 'z') {
            last_reg = byte - 'a';
            return data[last_reg][0..lens[last_reg]];
        }
        return &[_]u8{};
    }

    if (byte == 'q') {
        if (recording) {
            recording = false;
        } else {
            pending_record = true;
        }
        return &[_]u8{};
    }

    if (byte == '@') {
        pending_replay = true;
        return &[_]u8{};
    }

    return null;
}

pub fn record(byte: u8) void {
    if (recording and lens[record_reg] < 256) {
        data[record_reg][lens[record_reg]] = byte;
        lens[record_reg] += 1;
    }
}
