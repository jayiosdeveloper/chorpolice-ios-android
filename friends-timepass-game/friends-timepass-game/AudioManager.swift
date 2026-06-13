//
//  AudioManager.swift
//  All game audio is synthesized at launch (no sound asset files needed):
//  chiptune music loop, jetpack rumble, and one-shot SFX, played through
//  a small AVAudioEngine graph.
//

import AVFoundation

final class AudioManager {

    static let shared = AudioManager()

    enum SFX: CaseIterable {
        case rifle, uzi, shotgun, sniper, hit, explosion, pickup, capture, win,
             flame, rocket, nadeThrow
    }

    var soundEnabled = true

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var sfxNodes: [AVAudioPlayerNode] = []
    private var sfxIndex = 0
    private let jetNode = AVAudioPlayerNode()
    private let musicNode = AVAudioPlayerNode()
    private var buffers: [SFX: AVAudioPCMBuffer] = [:]
    private var jetBuffer: AVAudioPCMBuffer!
    private var menuMusicBuffer: AVAudioPCMBuffer!
    private var battleMusicBuffer: AVAudioPCMBuffer!

    enum MusicTrack { case menu, battle }
    private var currentTrack: MusicTrack = .menu
    private var musicOn = false
    private var started = false
    private var jetRunning = false
    private var musicRunning = false

    private init() {
        for _ in 0..<6 {
            let n = AVAudioPlayerNode()
            engine.attach(n)
            engine.connect(n, to: engine.mainMixerNode, format: format)
            sfxNodes.append(n)
        }
        engine.attach(jetNode)
        engine.connect(jetNode, to: engine.mainMixerNode, format: format)
        engine.attach(musicNode)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)

        generateBuffers()
    }

    // MARK: Public API

    func play(_ sfx: SFX, volume: Float = 1) {
        guard soundEnabled, ensureStarted(), let buf = buffers[sfx] else { return }
        let node = sfxNodes[sfxIndex]
        sfxIndex = (sfxIndex + 1) % sfxNodes.count
        node.stop()
        node.volume = volume
        node.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
        node.play()
    }

    func setJetpack(_ on: Bool) {
        guard soundEnabled || !on, ensureStarted() else { return }
        if on && !jetRunning {
            jetNode.scheduleBuffer(jetBuffer, at: nil, options: .loops, completionHandler: nil)
            jetNode.play()
            jetRunning = true
        }
        jetNode.volume = on ? 0.5 : 0
    }

    func setMusic(_ on: Bool) {
        musicOn = on
        guard ensureStarted() else { return }
        if on {
            startCurrentTrackIfNeeded()
            musicNode.volume = currentTrack == .menu ? 0.44 : 0.30
        } else {
            musicNode.volume = 0
        }
    }

    /// Switch between the menu theme and the in-game loop.
    func playTrack(_ track: MusicTrack) {
        if track != currentTrack {
            currentTrack = track
            if musicRunning {
                musicNode.stop()
                musicRunning = false
            }
        }
        setMusic(musicOn)
    }

    private func startCurrentTrackIfNeeded() {
        guard !musicRunning else { return }
        let buf = currentTrack == .menu ? menuMusicBuffer! : battleMusicBuffer!
        musicNode.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
        musicNode.play()
        musicRunning = true
    }

    // MARK: Engine

    @discardableResult
    private func ensureStarted() -> Bool {
        if started { return true }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.prepare()
        do { try engine.start() } catch { return false }
        started = true
        return true
    }

    // MARK: Synthesis

    private func makeBuffer(_ duration: Double, _ sample: (Double) -> Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(44100 * duration)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let data = buf.floatChannelData![0]
        for i in 0..<Int(frames) {
            data[i] = sample(Double(i) / 44100)
        }
        return buf
    }

    private var noiseState: UInt32 = 0x12345678
    private func noise() -> Float {
        noiseState ^= noiseState << 13
        noiseState ^= noiseState >> 17
        noiseState ^= noiseState << 5
        return Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
    }

    private func generateBuffers() {
        func decay(_ t: Double, _ dur: Double, _ k: Double = 5) -> Float {
            t >= dur ? 0 : Float(exp(-k * t / dur))
        }

        buffers[.rifle] = makeBuffer(0.09) { t in
            let f = 1600 - 1200 * (t / 0.09)
            let sweep = Float(sin(2 * .pi * f * t))
            return (sweep * 0.5 + self.noise() * 0.3) * decay(t, 0.09, 6) * 0.55
        }
        buffers[.uzi] = makeBuffer(0.06) { t in
            let f = 1300 - 900 * (t / 0.06)
            return (Float(sin(2 * .pi * f * t)) * 0.5 + self.noise() * 0.25) * decay(t, 0.06, 6) * 0.45
        }
        buffers[.shotgun] = makeBuffer(0.25) { t in
            let boom = Float(sin(2 * .pi * 110 * t)) * 0.5
            return (self.noise() * 0.6 + boom) * decay(t, 0.25, 7) * 0.7
        }
        buffers[.sniper] = makeBuffer(0.16) { t in
            let f = 2200 - 1900 * (t / 0.16)
            let crack = Float(sin(2 * .pi * f * t)) * 0.45
            return (crack + self.noise() * 0.5) * decay(t, 0.16, 8) * 0.7
        }
        buffers[.hit] = makeBuffer(0.07) { t in
            Float(sin(2 * .pi * 620 * t)) * decay(t, 0.07, 6) * 0.4
        }
        buffers[.explosion] = makeBuffer(0.55) { t in
            let boom = Float(sin(2 * .pi * (70 - 30 * t) * t)) * 0.6
            return (self.noise() * 0.55 + boom) * decay(t, 0.55, 5) * 0.8
        }
        buffers[.pickup] = makeBuffer(0.18) { t in
            let f: Double = t < 0.09 ? 660 : 990
            return Float(sin(2 * .pi * f * t)) * decay(t.truncatingRemainder(dividingBy: 0.09), 0.09, 3) * 0.4
        }
        buffers[.capture] = makeBuffer(0.3) { t in
            let step = Int(t / 0.1)
            let f: Double = [659.0, 784.0, 1047.0][min(step, 2)]
            return Float(sin(2 * .pi * f * t)) * decay(t.truncatingRemainder(dividingBy: 0.1), 0.1, 3) * 0.45
        }
        buffers[.win] = makeBuffer(0.9) { t in
            let step = Int(t / 0.18)
            let f: Double = [523.0, 659.0, 784.0, 1047.0, 1319.0][min(step, 4)]
            let tt = t.truncatingRemainder(dividingBy: 0.18)
            return Float(sin(2 * .pi * f * t)) * decay(tt, 0.18, 2.5) * 0.5
        }

        buffers[.flame] = makeBuffer(0.14) { t in
            let rumble = Float(sin(2 * .pi * 95 * t)) * 0.2
            return (self.noise() * 0.35 + rumble) * decay(t, 0.14, 3) * 0.4
        }
        buffers[.rocket] = makeBuffer(0.5) { t in
            let f = 320 - 230 * (t / 0.5)
            let whoosh = Float(sin(2 * .pi * f * t)) * 0.35
            return (self.noise() * 0.5 + whoosh) * decay(t, 0.5, 4) * 0.7
        }
        buffers[.nadeThrow] = makeBuffer(0.08) { t in
            let f = 480 + 1800 * t
            return Float(sin(2 * .pi * f * t)) * decay(t, 0.08, 5) * 0.35
        }

        jetBuffer = makeBuffer(0.6) { t in
            let rumble = Float(sin(2 * .pi * 85 * t)) * 0.3
            let hiss = self.noise() * 0.4
            let wobble = 0.75 + 0.25 * Float(sin(2 * .pi * 9 * t))
            return (rumble + hiss) * wobble * 0.6
        }

        menuMusicBuffer = makeMenuMusic()
        battleMusicBuffer = makeBattleMusic()
    }

    /// The title theme: an epic 8-bar chiptune anthem in A minor (Am-F-C-G) —
    /// kick/snare/hats, pulsing bass, warm pad chords, and a catchy vibrato
    /// lead with echo that lifts an octave in the second half.
    private func makeMenuMusic() -> AVAudioPCMBuffer {
        let bpm = 112.0
        let beat = 60.0 / bpm
        let barLen = beat * 4
        let total = barLen * 8
        let frames = Int(44100 * total)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buf.frameLength = AVAudioFrameCount(frames)
        let data = buf.floatChannelData![0]
        for i in 0..<frames { data[i] = 0 }

        enum Wave { case sine, square, lead }
        func osc(_ w: Wave, _ phase: Double) -> Float {
            switch w {
            case .sine: return Float(sin(phase))
            case .square: return sin(phase) > 0 ? 0.5 : -0.5
            case .lead: return Float(sin(phase)) * 0.55 + (sin(phase) > 0 ? 0.32 : -0.32)
            }
        }
        func note(_ start: Double, _ dur: Double, _ freq: Double, _ vol: Float,
                  _ wave: Wave, attack: Double = 0.012, vibrato: Double = 0, decay: Double = 2.8) {
            let s = Int(start * 44100), n = Int(dur * 44100)
            for j in 0..<n {
                let idx = s + j
                if idx >= frames { break }
                let t = Double(j) / 44100
                let vib = vibrato > 0 ? 1 + 0.004 * sin(2 * .pi * vibrato * t) : 1
                let phase = 2 * .pi * freq * vib * t
                let env = Float(exp(-decay * t / dur)) * Float(min(1, t / attack))
                data[idx] += osc(wave, phase) * env * vol
            }
        }
        func kick(_ start: Double) {
            let s = Int(start * 44100), n = Int(0.11 * 44100)
            var phase = 0.0
            for j in 0..<n {
                let idx = s + j
                if idx >= frames { break }
                let t = Double(j) / 44100
                let f = 42 + 95 * exp(-30 * t)
                phase += 2 * .pi * f / 44100
                data[idx] += Float(sin(phase)) * Float(exp(-9 * t)) * 0.5
            }
        }
        func snare(_ start: Double) {
            let s = Int(start * 44100), n = Int(0.1 * 44100)
            for j in 0..<n {
                let idx = s + j
                if idx >= frames { break }
                let t = Double(j) / 44100
                data[idx] += (noise() * 0.5 + Float(sin(2 * .pi * 185 * t)) * 0.18)
                    * Float(exp(-16 * t)) * 0.5
            }
        }
        func hat(_ start: Double, _ vol: Float) {
            let s = Int(start * 44100), n = Int(0.025 * 44100)
            for j in 0..<n {
                let idx = s + j
                if idx >= frames { break }
                data[idx] += noise() * vol * Float(exp(-Double(j) / (0.012 * 44100)))
            }
        }

        // Chords per bar: Am F C G (repeated). [bass root, pad triad]
        let bass: [Double] = [110.00, 87.31, 130.81, 98.00]
        let pads: [[Double]] = [
            [220.00, 261.63, 329.63],   // Am
            [174.61, 220.00, 261.63],   // F
            [261.63, 329.63, 392.00],   // C
            [196.00, 246.94, 293.66]    // G
        ]
        // Lead phrase over 4 bars: (bar, beatInBar, durBeats, freq)
        let melody: [(Int, Double, Double, Double)] = [
            (0, 0.0, 0.75, 440.00), (0, 0.75, 0.25, 493.88), (0, 1.0, 0.75, 523.25),
            (0, 1.75, 0.25, 587.33), (0, 2.0, 1.4, 659.25), (0, 3.5, 0.5, 587.33),
            (1, 0.0, 1.0, 523.25), (1, 1.0, 1.0, 440.00), (1, 2.0, 1.9, 349.23),
            (2, 0.0, 0.75, 392.00), (2, 0.75, 0.25, 440.00), (2, 1.0, 0.75, 493.88),
            (2, 1.75, 0.25, 523.25), (2, 2.0, 1.4, 659.25), (2, 3.5, 0.5, 698.46),
            (3, 0.0, 1.0, 587.33), (3, 1.0, 1.0, 493.88), (3, 2.0, 1.9, 392.00)
        ]

        for bar in 0..<8 {
            let barStart = Double(bar) * barLen
            let chord = bar % 4

            // Pad: detuned square pair per chord tone, slow attack.
            for f in pads[chord] {
                note(barStart, barLen * 0.98, f, 0.030, .square, attack: 0.18, decay: 1.1)
                note(barStart, barLen * 0.98, f * 1.004, 0.024, .square, attack: 0.18, decay: 1.1)
            }
            // Bass: driving eighths with an octave pop.
            for e in 0..<8 {
                let f = (e % 4 == 2) ? bass[chord] * 2 : bass[chord]
                note(barStart + Double(e) * beat / 2, beat * 0.42, f, 0.15, .square, decay: 3.5)
            }
            // Drums.
            for b in 0..<4 {
                kick(barStart + Double(b) * beat)
                if b == 1 || b == 3 { snare(barStart + Double(b) * beat) }
            }
            let hatStep = bar >= 4 ? beat / 4 : beat / 2
            var ht = barStart
            while ht < barStart + barLen - 0.01 {
                hat(ht, bar >= 4 ? 0.042 : 0.05)
                ht += hatStep
            }
            // Sparkle arp in the lifted half.
            if bar >= 4 {
                let tones = pads[chord]
                var at = barStart
                var k = 0
                while at < barStart + barLen - 0.01 {
                    note(at, beat * 0.22, tones[k % 3] * (k % 4 == 3 ? 4 : 2), 0.035, .sine, decay: 4)
                    k += 1
                    at += beat / 4
                }
            }
        }
        // Lead melody: bars 0-3 plain, bars 4-7 doubled an octave up; echo trails.
        for pass in 0..<2 {
            let offset = Double(pass) * barLen * 4
            for (bar, b, durB, f) in melody {
                let st = offset + Double(bar) * barLen + b * beat
                let dur = durB * beat
                note(st, dur, f, pass == 0 ? 0.115 : 0.085, .lead, vibrato: 5.5)
                note(st + beat * 0.75, dur * 0.8, f, 0.035, .lead, vibrato: 5.5)   // echo
                if pass == 1 {
                    note(st, dur, f * 2, 0.07, .lead, vibrato: 5.5)
                }
            }
        }
        // Soft clip.
        for i in 0..<frames { data[i] = max(-0.95, min(0.95, data[i])) }
        return buf
    }

    /// The in-game loop: square-wave bass, plucked lead arp, noise hats.
    private func makeBattleMusic() -> AVAudioPCMBuffer {
        let bpm = 132.0
        let beat = 60.0 / bpm
        let bars = 4.0
        let total = beat * 4 * bars
        let frames = Int(44100 * total)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buf.frameLength = AVAudioFrameCount(frames)
        let data = buf.floatChannelData![0]
        for i in 0..<frames { data[i] = 0 }

        func addNote(start: Double, dur: Double, freq: Double, vol: Float, square: Bool) {
            let s = Int(start * 44100), n = Int(dur * 44100)
            for j in 0..<n {
                let idx = s + j
                if idx >= frames { break }
                let t = Double(j) / 44100
                let phase = 2 * .pi * freq * t
                let raw: Float = square ? (sin(phase) > 0 ? 0.5 : -0.5) : Float(sin(phase))
                let env = Float(exp(-3.5 * t / dur)) * (t < 0.01 ? Float(t / 0.01) : 1)
                data[idx] += raw * env * vol
            }
        }

        // Bass line (A minor-ish): A1 A1 C2 D2 per bar pattern
        let bassNotes: [Double] = [55.0, 55.0, 65.41, 73.42]
        for bar in 0..<4 {
            let root = bassNotes[bar]
            for b in 0..<4 {
                addNote(start: (Double(bar) * 4 + Double(b)) * beat, dur: beat * 0.9,
                        freq: root, vol: 0.30, square: true)
            }
        }
        // Lead arp (eighth notes, two octaves up)
        let arp: [Double] = [220, 261.63, 329.63, 440, 329.63, 261.63]
        var k = 0
        var t8 = 0.0
        while t8 < total - beat / 2 {
            addNote(start: t8, dur: beat * 0.42, freq: arp[k % arp.count] * 2, vol: 0.13, square: false)
            k += 1
            t8 += beat / 2
        }
        // Hats: short noise ticks on half beats
        var th = 0.0
        while th < total {
            let s = Int(th * 44100)
            for j in 0..<Int(0.018 * 44100) {
                let idx = s + j
                if idx >= frames { break }
                data[idx] += noise() * 0.07 * Float(exp(-9 * Double(j) / (0.018 * 44100)))
            }
            th += beat / 2
        }
        return buf
    }
}
