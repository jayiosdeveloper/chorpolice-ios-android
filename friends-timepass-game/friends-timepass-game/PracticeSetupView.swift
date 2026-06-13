//
//  PracticeSetupView.swift
//  Pre-practice screen: pick the map and the bot difficulty, then start.
//

import SwiftUI

struct PracticeSetupView: View {
    @ObservedObject var settings: GameSettings
    let onStart: (Int) -> Void      // resolved map index
    let onBack: () -> Void

    @State private var mapChoice = 0          // 0..2 = map, 3 = random

    private let levelNames = ["Easy", "Normal", "Hard", "Pro"]
    private let levelBlurbs = [
        "Chilled target practice — the bot wanders and rarely shoots",
        "A fair fight — the bot chases you and shoots back",
        "Fast and accurate — it hunts you down",
        "Merciless — moves like a player and leads its shots"
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.23),
                                    Color(red: 0.27, green: 0.21, blue: 0.43)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("PRACTICE")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("You vs Bot — warm up before the real fight")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 12) {
                    row("MAP") {
                        Picker("", selection: $mapChoice) {
                            ForEach(0..<Maps.all.count, id: \.self) { i in
                                Text(Maps.all[i].shortName).tag(i)
                            }
                            Text("Random").tag(Maps.all.count)
                        }
                        .pickerStyle(.segmented)
                    }

                    row("BOT LEVEL") {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("", selection: $settings.botLevel) {
                                ForEach(0..<levelNames.count, id: \.self) { i in
                                    Text(levelNames[i]).tag(i)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text(levelBlurbs[min(max(settings.botLevel, 0), levelBlurbs.count - 1)])
                                .font(.caption).foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: 460)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(action: {
                    let m = mapChoice >= Maps.all.count ? Int.random(in: 0..<Maps.all.count) : mapChoice
                    onStart(m)
                }) {
                    Text("START")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .frame(maxWidth: 460).padding(.vertical, 14)
                        .background(Color(red: 0.20, green: 0.75, blue: 0.35))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(action: onBack) {
                    Text("Back").foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private func row<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .heavy)).foregroundColor(.white.opacity(0.55))
            content()
        }
    }
}
