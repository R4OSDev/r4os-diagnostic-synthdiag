const r4os = @import("r4os");

const DiagApi = struct {
    sys: r4os.r4sys.Context,
    audio: r4os.r4audio.Context,
    dev: r4os.r4dev.Context,

    fn init(r4_app: *r4os.App) ?DiagApi {
        return .{
            .sys = r4_app.system(),
            .audio = r4_app.audioLowLevel() orelse return null,
            .dev = r4_app.devicesLowLevel() orelse return null,
        };
    }
};

pub fn r4_app_main(r4_app: *r4os.App) i32 {
    var ctx = DiagApi.init(r4_app) orelse return r4os.abi.err_no_group;
    var ok = true;

    ctx.sys.println("SYNTHD");
    ctx.sys.print("SID model: ");
    ctx.sys.print(ctx.audio.sidModelName());
    ctx.sys.write("\r\n");

    ok = checkRole(&ctx, "audio.midi") and ok;
    ok = checkRole(&ctx, "audio.opl3") and ok;
    ok = checkRole(&ctx, "audio.sid") and ok;
    ok = checkMidiProtocol(&ctx) and ok;
    ok = checkOpl3Protocol(&ctx) and ok;
    ok = checkSidProtocol(&ctx) and ok;
    ok = checkMidi(&ctx) and ok;
    ok = checkOpl3(&ctx) and ok;
    ok = checkSid(&ctx) and ok;

    ctx.sys.print("SYNTHD result: ");
    ctx.sys.println(if (ok) "OK" else "FAILED");
    return if (ok) 0 else 1;
}

fn checkRole(ctx: *const DiagApi, role: []const u8) bool {
    var status: r4os.abi.ProtocolStatus = .{};
    const rc = ctx.dev.protocolStatus(role, &status);
    const ok = rc == 0 and status.state == @intFromEnum(r4os.abi.ProtocolState.active) and (status.flags & (1 << 1)) != 0;
    ctx.sys.write("SYNTHD role ");
    ctx.sys.write(role);
    ctx.sys.write(": ");
    ctx.sys.write(if (ok) "OK" else "FAILED");
    ctx.sys.write(" source=");
    ctx.sys.write(sourceName(status.flags));
    ctx.sys.write(" state=");
    ctx.sys.write(stateName(status.state));
    if (rc != 0) {
        ctx.sys.write(" rc=");
        ctx.sys.printI32(rc);
    }
    ctx.sys.write("\r\n");
    return ok;
}

fn checkMidiProtocol(ctx: *const DiagApi) bool {
    var op: r4os.abi.AudioMidiOp = .{};
    const rc = dispatch(ctx, "audio.midi", r4os.abi.audio_midi_op_self_test, r4os.abi.AudioMidiOp, &op);
    const ok = rc == r4os.abi.audio_midi_result_ok and op.result == r4os.abi.audio_midi_result_ok;
    printDispatch(ctx, "midi-protocol", ok, rc, op.result);
    return ok;
}

fn checkOpl3Protocol(ctx: *const DiagApi) bool {
    var op: r4os.abi.AudioOpl3Op = .{};
    const rc = dispatch(ctx, "audio.opl3", r4os.abi.audio_opl3_op_self_test, r4os.abi.AudioOpl3Op, &op);
    const ok = rc == r4os.abi.audio_opl3_result_ok and op.result == r4os.abi.audio_opl3_result_ok;
    printDispatch(ctx, "opl3-protocol", ok, rc, op.result);
    return ok;
}

fn checkSidProtocol(ctx: *const DiagApi) bool {
    var op: r4os.abi.AudioSidOp = .{};
    const rc = dispatch(ctx, "audio.sid", r4os.abi.audio_sid_op_self_test, r4os.abi.AudioSidOp, &op);
    const ok = rc == r4os.abi.audio_sid_result_ok and op.result == r4os.abi.audio_sid_result_ok;
    printDispatch(ctx, "sid-protocol", ok, rc, op.result);
    return ok;
}

fn checkMidi(ctx: *const DiagApi) bool {
    const counter_only = ctx.audio.midiOpenSynth("MIDI");
    ctx.sys.print("midi_open_synth MIDI (non-renderer): ");
    ctx.sys.printI32(counter_only);
    ctx.sys.write("\r\n");
    if (counter_only >= 0) {
        _ = ctx.audio.midiClose(@intCast(counter_only));
        return false;
    }

    const handle = ctx.audio.midiOpenSynth("OPL3");
    ctx.sys.print("midi_open_synth OPL3: ");
    ctx.sys.printI32(handle);
    ctx.sys.write("\r\n");
    if (handle < 0) return false;

    const id: u32 = @intCast(handle);
    const program = ctx.audio.midiSend(id, 0, 0xC0, 0, 0);
    const on = ctx.audio.midiSend(id, 0, 0x90, 60, 96);
    const rendered_on = renderMidi(ctx, id, 1024);
    ctx.sys.sleepTicks(ctx.sys.ticksFromMilliseconds(22));
    const off = ctx.audio.midiSend(id, 0, 0x80, 60, 0);
    const rendered_off = renderMidi(ctx, id, 1024);
    const close = ctx.audio.midiClose(id);
    ctx.sys.print("midi program/on/render/off/render/close: ");
    ctx.sys.printI32(program);
    ctx.sys.write(" / ");
    ctx.sys.printI32(on);
    ctx.sys.write(" / ");
    ctx.sys.printI32(rendered_on);
    ctx.sys.write(" / ");
    ctx.sys.printI32(off);
    ctx.sys.write(" / ");
    ctx.sys.printI32(rendered_off);
    ctx.sys.write(" / ");
    ctx.sys.printI32(close);
    ctx.sys.write("\r\n");
    return program >= 0 and on >= 0 and rendered_on >= 0 and off >= 0 and rendered_off >= 0 and close == 0;
}

fn renderMidi(ctx: *const DiagApi, handle: u32, frames: u16) i32 {
    while (true) {
        const result = ctx.audio.midiRender(handle, frames);
        if (result != r4os.abi.service_api_result_busy) return result;
        ctx.sys.sleepTicks(1);
    }
}

fn dispatch(ctx: *const DiagApi, role: []const u8, opcode: u32, comptime T: type, op: *T) i32 {
    var in_buffer = r4os.abi.ProtocolBuffer{
        .data = op,
        .len = @sizeOf(T),
        .capacity = @sizeOf(T),
        .flags = 0,
        .reserved = 0,
    };
    var out_buffer: r4os.abi.ProtocolBuffer = .{};
    return ctx.dev.protocolDispatch(role, opcode, &in_buffer, &out_buffer);
}

fn printDispatch(ctx: *const DiagApi, label: []const u8, ok: bool, rc: i32, result: i32) void {
    ctx.sys.write("SYNTHD selftest ");
    ctx.sys.write(label);
    ctx.sys.write(": ");
    ctx.sys.write(if (ok) "OK" else "FAILED");
    ctx.sys.write(" rc=");
    ctx.sys.printI32(rc);
    ctx.sys.write(" result=");
    ctx.sys.printI32(result);
    ctx.sys.write("\r\n");
}

fn sourceName(flags: u32) []const u8 {
    if ((flags & (1 << 2)) != 0) return "preload";
    if ((flags & (1 << 1)) != 0) return "r4p";
    if ((flags & (1 << 0)) != 0) return "builtin";
    return "none";
}

fn stateName(state: u32) []const u8 {
    return switch (state) {
        1 => "loaded",
        2 => "active",
        3 => "fallback",
        4 => "blocked",
        5 => "error",
        6 => "disabled",
        else => "missing",
    };
}

fn checkOpl3(ctx: *const DiagApi) bool {
    const reset = ctx.audio.opl3Reset();
    const write = ctx.audio.opl3WriteRegister(0, 0x20, 0x21);
    const render = ctx.audio.opl3RenderBlock();
    const stop = ctx.audio.opl3Stop();
    ctx.sys.print("opl3 reset/write/render/stop: ");
    ctx.sys.printI32(reset);
    ctx.sys.write(" / ");
    ctx.sys.printI32(write);
    ctx.sys.write(" / ");
    ctx.sys.printI32(render);
    ctx.sys.write(" / ");
    ctx.sys.printI32(stop);
    ctx.sys.write("\r\n");
    return reset >= 0 and write >= 0 and render >= 0 and stop >= 0;
}

fn checkSid(ctx: *const DiagApi) bool {
    const handle = ctx.audio.sidAcquire();
    ctx.sys.print("sid_acquire: ");
    ctx.sys.printI32(handle);
    ctx.sys.write("\r\n");
    if (handle < 0) return false;

    const id: u32 = @intCast(handle);
    const program = [_]u8{
        0xA9, 0x0F, 0x8D, 0x18, 0xD4,
        0xA9, 0x00, 0x8D, 0x00, 0xD4,
        0xA9, 0x20, 0x8D, 0x01, 0xD4,
        0xA9, 0xF0, 0x8D, 0x05, 0xD4,
        0xA9, 0xF0, 0x8D, 0x06, 0xD4,
        0xA9, 0x21, 0x8D, 0x04, 0xD4,
        0x60, 0xEA, 0x60,
    };
    const loaded = ctx.audio.sidLoadData(id, 0x1000, program[0..]);
    const initialized = ctx.audio.sidInit(id, 0x1000, 1);
    var rendered: i32 = r4os.abi.service_api_result_busy;
    while (rendered == r4os.abi.service_api_result_busy) {
        rendered = ctx.audio.sidPlayFrame(id, 0x1020, 50);
        if (rendered == r4os.abi.service_api_result_busy) ctx.sys.sleepTicks(1);
    }
    const deadline = ctx.sys.ticks() +| ctx.sys.ticksFromMilliseconds(3000);
    var stopped = ctx.audio.sidStop(id);
    while (stopped == r4os.abi.service_api_result_busy and ctx.sys.ticks() < deadline) {
        ctx.sys.sleepTicks(1);
        stopped = ctx.audio.sidStop(id);
    }
    const release = ctx.audio.sidRelease(id);
    ctx.sys.print("sid load/init/render/stop/release: ");
    ctx.sys.printI32(loaded);
    ctx.sys.write(" / ");
    ctx.sys.printI32(initialized);
    ctx.sys.write(" / ");
    ctx.sys.printI32(rendered);
    ctx.sys.write(" / ");
    ctx.sys.printI32(stopped);
    ctx.sys.write(" / ");
    ctx.sys.printI32(release);
    ctx.sys.write("\r\n");
    return loaded == program.len and initialized == 0 and rendered == 0 and stopped == 0 and release == 0;
}
