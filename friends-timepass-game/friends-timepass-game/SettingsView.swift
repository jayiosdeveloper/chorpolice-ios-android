//
//  SettingsView.swift
//  Full-screen, two-column settings: your character on the left, game options on
//  the right. Same options as before, laid out across the whole screen.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: GameSettings
    var onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.23),
                                    Color(red: 0.20, green: 0.16, blue: 0.34)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onClose) {
                        Text("Done")
                            .fontWeight(.bold)
                            .padding(.horizontal, 26).padding(.vertical, 11)
                            .background(Color.green.opacity(0.88))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }

                // Two columns filling the screen
                HStack(alignment: .top, spacing: 18) {
                    characterCard
                    optionsCard
                }
                .frame(maxHeight: .infinity)
            }
            .padding(22)
        }
    }

    // MARK: Left — character

    private var characterCard: some View {
        card("Your character") {
            HStack(alignment: .top, spacing: 18) {
                RobotPreview(skin: settings.skin)
                    .frame(width: 120, height: 150)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))

                field("Player name") {
                    TextField("Your name", text: $settings.playerName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // full-width tab row so "Colors / Army / Custom" all fit
            Picker("", selection: $settings.skinMode) {
                Text("Colors").tag(0)
                Text("Army").tag(1)
                Text("Custom").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)

            skinPicker
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var skinPicker: some View {
        switch settings.skinMode {
        case 1:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                ForEach(0..<ArmySkins.all.count, id: \.self) { i in
                    VStack(spacing: 4) {
                        RobotPreview(skin: ArmySkins.all[i].skin)
                            .frame(width: 48, height: 60).padding(6)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(settings.armyIndex == i ? 0.20 : 0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: settings.armyIndex == i ? 2 : 0))
                        Text(ArmySkins.all[i].name).font(.caption2)
                            .foregroundColor(.white.opacity(settings.armyIndex == i ? 1 : 0.65))
                    }
                    .onTapGesture { settings.armyIndex = i }
                }
            }
        case 2:
            VStack(alignment: .leading, spacing: 8) {
                customPicker("Jacket", settings.customMainBinding)
                customPicker("Helmet", settings.customHelmetBinding)
                customPicker("Visor & glow", settings.customAccentBinding)
                customPicker("Pants", settings.customPantsBinding)
                customPicker("Skin tone", settings.customToneBinding)
            }
        default:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                ForEach(0..<PlayerColors.all.count, id: \.self) { i in
                    RobotPreview(skin: PlayerColors.skin(i))
                        .frame(width: 44, height: 55).padding(6)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(settings.colorIndex == i ? 0.20 : 0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: settings.colorIndex == i ? 2 : 0))
                        .onTapGesture { settings.colorIndex = i }
                }
            }
        }
    }

    // MARK: Right — options

    private var optionsCard: some View {
        card("Game") {
            Toggle(isOn: $settings.leftHanded) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left-handed controls").foregroundColor(.white).fontWeight(.semibold)
                    Text("Move on the right, aim on the left")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                }
            }
            .tint(.green)

            Toggle(isOn: $settings.soundOn) {
                Text("Sound effects").foregroundColor(.white).fontWeight(.semibold)
            }
            .tint(.green)
            .onChange(of: settings.soundOn) { on in
                AudioManager.shared.soundEnabled = on
                if !on { AudioManager.shared.setJetpack(false) }
            }

            Toggle(isOn: $settings.musicOn) {
                Text("Music").foregroundColor(.white).fontWeight(.semibold)
            }
            .tint(.green)
            .onChange(of: settings.musicOn) { on in AudioManager.shared.setMusic(on) }

            field("Fire bullets") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("", selection: $settings.unlimitedAmmo) {
                        Text("Limited").tag(false)
                        Text("Unlimited").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text(settings.unlimitedAmmo
                         ? "Every gun fires forever — no ammo limit"
                         : "Uzi / Shotgun / Sniper carry limited ammo (rifle is always ∞)")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("In multiplayer the host's choice applies to everyone")
                        .font(.caption2).foregroundColor(.white.opacity(0.45))
                }
            }

            field("Kills to win (multiplayer)") {
                Stepper(value: $settings.killsToWin, in: 3...30) {
                    Text("\(settings.killsToWin) kills").foregroundColor(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: helpers

    private func customPicker(_ title: String, _ binding: Binding<Color>) -> some View {
        ColorPicker(title, selection: binding, supportsOpacity: false)
            .foregroundColor(.white)
            .font(.system(size: 14, weight: .medium))
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.8))
            content()
        }
    }

    @ViewBuilder
    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.06)))
    }
}
