import SwiftUI

struct FilterSelectionView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Binding var isPresented: Bool
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Panel background
            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(RetroTheme.metalLight.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Top bar: Setting + Close
                HStack {
                    Button {
                        showSettings.toggle()
                        HapticService.impact(.light)
                    } label: {
                        Text("Setting")
                            .font(VintageFont.label(14))
                            .foregroundStyle(showSettings && viewModel.selectedFilter != .none
                                             ? RetroTheme.accent : RetroTheme.faded)
                    }
                    .disabled(viewModel.selectedFilter == .none)

                    Spacer()

                    Button {
                        isPresented = false
                        HapticService.impact(.light)
                    } label: {
                        Text("Done")
                            .font(VintageFont.label(14))
                            .foregroundStyle(RetroTheme.accent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // Divider
                Rectangle()
                    .fill(RetroTheme.metalDark.opacity(0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // Canister strip OR settings sliders (same area)
                if showSettings && viewModel.selectedFilter != .none {
                    filterSettingsPanel
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                        .transition(.opacity)
                } else {
                    filmCanisterStrip
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RetroTheme.cameraBody)
                    .shadow(color: .black.opacity(0.6), radius: 20, y: -5)
            )
        }
        .animation(.easeInOut(duration: 0.25), value: showSettings)
    }

    // MARK: - Film Canister Strip

    private var filmCanisterStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(FilmFilterType.allCases) { filter in
                        FilmCanisterCard(
                            filter: filter,
                            isSelected: viewModel.selectedFilter == filter
                        )
                        .id(filter)
                        .onTapGesture {
                            viewModel.selectedFilter = filter
                            switch filter {
                            case .none: break
                            case .glow: viewModel.filterParams = .defaultGlow
                            case .light: viewModel.filterParams = .defaultLight
                            }
                            HapticService.impact(.light)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .onAppear {
                proxy.scrollTo(viewModel.selectedFilter, anchor: .center)
            }
        }
    }

    // MARK: - Settings Panel

    private var filterSettingsPanel: some View {
        VStack(spacing: 12) {
            filterSlider(label: "BLUR", value: $viewModel.filterParams.blur)
            filterSlider(label: "OPACITY", value: $viewModel.filterParams.opacity)
            filterSlider(label: "RANGE", value: $viewModel.filterParams.range)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(RetroTheme.cameraBodyLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RetroTheme.metalDark.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private func filterSlider(label: String, value: Binding<Float>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(VintageFont.caption(10))
                .foregroundStyle(RetroTheme.faded)
                .frame(width: 56, alignment: .leading)

            Slider(value: value, in: 0...100, step: 1)
                .tint(RetroTheme.accent)

            Text("\(Int(value.wrappedValue))")
                .font(VintageFont.lcd(12))
                .foregroundStyle(RetroTheme.accent)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Film Canister Card

private struct FilmCanisterCard: View {
    let filter: FilmFilterType
    let isSelected: Bool

    private var canisterColor: Color {
        switch filter {
        case .none: return RetroTheme.metalDark
        case .glow: return Color(red: 0.75, green: 0.55, blue: 0.15)
        case .light: return Color(red: 0.35, green: 0.50, blue: 0.65)
        }
    }

    private var labelColor: Color {
        switch filter {
        case .none: return RetroTheme.faded.opacity(0.6)
        case .glow: return Color(red: 0.95, green: 0.80, blue: 0.30)
        case .light: return Color(red: 0.70, green: 0.85, blue: 1.0)
        }
    }

    private var filmCode: String {
        switch filter {
        case .none: return "STD"
        case .glow: return "GL"
        case .light: return "LT"
        }
    }

    private var isoText: String {
        switch filter {
        case .none: return ""
        case .glow: return "200"
        case .light: return "100"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(canisterColor.gradient)
                    .frame(width: 72, height: 88)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? RetroTheme.accent : .clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.15))
                        .frame(width: 60, height: 6)

                    Text(filmCode)
                        .font(VintageFont.caption(18))
                        .foregroundStyle(.white)
                        .fontWeight(.bold)

                    if !isoText.isEmpty {
                        Text(isoText)
                            .font(VintageFont.caption(11))
                            .foregroundStyle(labelColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.black.opacity(0.3))
                            )
                    }

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.1))
                        .frame(width: 60, height: 4)
                }
            }

            Text(filter.displayName)
                .font(VintageFont.caption(10))
                .foregroundStyle(isSelected ? RetroTheme.accent : RetroTheme.faded.opacity(0.7))
                .tracking(1)
        }
    }
}
