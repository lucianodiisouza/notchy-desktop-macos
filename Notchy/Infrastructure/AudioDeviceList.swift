import Foundation
import CoreAudio

/// Input devices for the microphone picker and for setting the capture device on AVAudioEngine.
enum AudioDeviceList {

    struct Item: Identifiable {
        let id: String  // UID
        let name: String
    }

    /// All audio input devices (UID + display name). Empty string UID = system default (not included).
    static func inputDevices() -> [Item] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let errSize = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard errSize == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids)
        guard err == noErr else { return [] }

        var result: [Item] = []
        for deviceID in ids {
            guard hasInputChannels(deviceID) else { continue }
            guard let uid = deviceUID(deviceID), let name = deviceName(deviceID), !uid.isEmpty, !name.isEmpty else { continue }
            result.append(Item(id: uid, name: name))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Resolve stored UID to the AudioDeviceID set on the engine's input unit.
    static func deviceID(for uid: String) -> AudioDeviceID? {
        deviceIDByUID(uid)
    }

    private static func deviceIDByUID(_ uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let errSize = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard errSize == noErr, size > 0 else { return nil }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids)
        guard err == noErr else { return nil }
        for deviceID in ids {
            if deviceUID(deviceID) == uid { return deviceID }
        }
        return nil
    }

    private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let errSize = AudioObjectGetPropertyDataSize(AudioObjectID(deviceID), &address, 0, nil, &size)
        guard errSize == noErr, size >= MemoryLayout<AudioBufferList>.size else { return false }
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { ptr.deallocate() }
        var outSize = size
        let err = AudioObjectGetPropertyData(AudioObjectID(deviceID), &address, 0, nil, &outSize, ptr)
        guard err == noErr else { return false }
        let bufferList = ptr.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer<AudioBufferList>(bufferList))
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private static func deviceUID(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &uid) { ptr in
            AudioObjectGetPropertyData(AudioObjectID(deviceID), &address, 0, nil, &size, ptr)
        }
        guard err == noErr, let uid = uid as String? else { return nil }
        return uid
    }

    private static func deviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(AudioObjectID(deviceID), &address, 0, nil, &size, ptr)
        }
        guard err == noErr, let name = name as String? else { return nil }
        return name
    }
}
