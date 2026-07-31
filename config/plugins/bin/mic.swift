// mic [toggle|get] — read or flip the default input device's mute state.
//
// Through CoreAudio directly rather than osascript, which measured ~275ms per
// call: this runs on every bar tick, so that cost would be paid all day.
//
// Prints "muted" or "live" on stdout. Devices differ: some expose a real mute
// property, others only volume, so this handles both and falls back to volume
// when mute is unsupported.
import CoreAudio
import Foundation

func defaultInputDevice() -> AudioDeviceID? {
    var id = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
    return err == noErr && id != 0 ? id : nil
}

func addr(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector,
                               mScope: kAudioObjectPropertyScopeInput,
                               mElement: kAudioObjectPropertyElementMain)
}

func isMuted(_ dev: AudioDeviceID) -> Bool {
    var a = addr(kAudioDevicePropertyMute)
    if AudioObjectHasProperty(dev, &a) {
        var v = UInt32(0); var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &v) == noErr { return v == 1 }
    }
    // no mute property: treat zero input volume as muted
    var va = addr(kAudioDevicePropertyVolumeScalar)
    if AudioObjectHasProperty(dev, &va) {
        var v = Float32(0); var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(dev, &va, 0, nil, &size, &v) == noErr { return v < 0.001 }
    }
    return false
}

func setMuted(_ dev: AudioDeviceID, _ muted: Bool) {
    var a = addr(kAudioDevicePropertyMute)
    if AudioObjectHasProperty(dev, &a) {
        var v = UInt32(muted ? 1 : 0)
        if AudioObjectSetPropertyData(dev, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v) == noErr { return }
    }
    var va = addr(kAudioDevicePropertyVolumeScalar)
    if AudioObjectHasProperty(dev, &va) {
        // remember the level so unmuting restores it rather than guessing
        let store = NSString(string: "~/.local/share/sketchetc/data/.mic_level").expandingTildeInPath
        var v = Float32(0); var size = UInt32(MemoryLayout<Float32>.size)
        if muted {
            if AudioObjectGetPropertyData(dev, &va, 0, nil, &size, &v) == noErr, v > 0.001 {
                try? "\(v)".write(toFile: store, atomically: true, encoding: .utf8)
            }
            v = 0
        } else {
            let saved = (try? String(contentsOfFile: store, encoding: .utf8)).flatMap { Float32($0) }
            v = saved ?? 0.75
        }
        AudioObjectSetPropertyData(dev, &va, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
    }
}

guard let dev = defaultInputDevice() else { print("none"); exit(1) }
let cmd = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "get"
if cmd == "toggle" { setMuted(dev, !isMuted(dev)) }
print(isMuted(dev) ? "muted" : "live")
