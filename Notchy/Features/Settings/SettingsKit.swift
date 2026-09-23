import SwiftUI

// The building blocks of the settings window, shared with PrimoDock, CameraMan and DailyNotch so the apps look alike.

/// Notchy's own palette for the settings window.
enum SettingsPalette {
    /// Backdrop of the notch previews: a dusk wallpaper, so the black pill reads the way it does on a real desktop.
    static let previewBackdrop = LinearGradient(
        colors: [Color(hex: "#1E3A8A"), Color(hex: "#4C1D95"), Color(hex: "#0F172A")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let selection = Color.accentColor
    static let card = Color.primary.opacity(0.05)
    static let cardStroke = Color.primary.opacity(0.07)
}

/// Colored rounded-square symbol, like System Settings.
struct SettingsIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.75)], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

/// A page's scrolling column, capped in width so rows stay readable on a wide window.
struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .modifier(SettingScroller(proxy: proxy))
        }
    }
}

/// Section title with an optional description.
struct SettingsSectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.localized)
                .font(.system(size: 18, weight: .bold))
            if let subtitle {
                Text(subtitle.localized)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingAnchor(title)
        .padding(.top, 14)
    }
}

/// A rounded card holding rows separated by thin dividers.
struct SettingsGroup<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            rows
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SettingsPalette.card))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SettingsPalette.cardStroke))
            if let footer {
                Text(footer.localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .settingAnchor(title)
    }

    /// Rows with a divider between them (macOS 15+); plain stack before.
    @ViewBuilder
    private var rows: some View {
        if #available(macOS 15.0, *) {
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.offset) { index, subview in
                        if index > 0 {
                            Divider().padding(.leading, 52)
                        }
                        subview
                    }
                }
            }
        } else {
            VStack(spacing: 0) { content }
        }
    }
}

/// Icon, title, gray subtitle and a trailing control.
struct SettingsRow<Trailing: View>: View {
    let symbol: String
    let color: Color
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle.localized)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .settingAnchor(title)
    }
}

/// A row with a switch.
struct SettingsToggleRow: View {
    let symbol: String
    let color: Color
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(symbol: symbol, color: color, title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

/// A row with a menu picker.
struct SettingsPickerRow<Value: Hashable, Options: View>: View {
    let symbol: String
    let color: Color
    let title: String
    var subtitle: String?
    @Binding var selection: Value
    @ViewBuilder let options: Options

    var body: some View {
        SettingsRow(symbol: symbol, color: color, title: title, subtitle: subtitle) {
            Picker("", selection: $selection) { options }
                .labelsHidden()
                .fixedSize()
        }
    }
}

/// A row with a color well.
struct SettingsColorRow: View {
    let symbol: String
    let color: Color
    let title: String
    var subtitle: String?
    @Binding var selection: Color

    var body: some View {
        SettingsRow(symbol: symbol, color: color, title: title, subtitle: subtitle) {
            ColorPicker("", selection: $selection)
                .labelsHidden()
        }
    }
}

/// A row with a value label and a slider under the title.
struct SettingsSliderRow: View {
    let symbol: String
    let color: Color
    let title: String
    var subtitle: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsRow(symbol: symbol, color: color, title: title, subtitle: subtitle) {
                Text(format(value))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ThickSlider(value: $value, range: range, step: step, tint: color, label: title, format: format)
                .padding(.leading, 52)
                .padding(.trailing, 14)
                .padding(.bottom, 10)
        }
    }
}

/// A wide filled bar you drag, like the sliders in Control Center. For a range that goes both ways around zero
/// (position, brightness) the fill grows from the middle, so the neutral point stays visible.
struct ThickSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var tint: Color = .accentColor
    var label: String = ""
    var format: (Double) -> String = { String(format: "%.1f", $0) }

    @Environment(\.isEnabled) private var isEnabled

    private var span: Double { range.upperBound - range.lowerBound }
    private var origin: Double { range.lowerBound < 0 && range.upperBound > 0 ? 0 : range.lowerBound }
    private func fraction(_ v: Double) -> Double { span > 0 ? (v - range.lowerBound) / span : 0 }

    private let trackHeight: CGFloat = 12
    private let knobSize: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            // The knob's centre travels between the two ends, so it never hangs off the bar.
            let travel = max(geo.size.width - knobSize, 1)
            let x = { (v: Double) in knobSize / 2 + fraction(v) * travel }
            // One-way settings fill from the very left of the bar; two-way ones from the zero mark.
            let start = origin == range.lowerBound ? 0 : x(origin)
            let knob = x(min(max(value, range.lowerBound), range.upperBound))
            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Rectangle()
                        .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                        .frame(width: abs(knob - start))
                        .offset(x: min(start, knob))
                }
                .frame(height: trackHeight)
                .clipShape(Capsule())
                if origin != range.lowerBound {
                    // The zero mark of a two-way setting.
                    Capsule().fill(Color.primary.opacity(0.35)).frame(width: 2, height: trackHeight + 6).offset(x: start - 1)
                }
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.08)))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: knob - knobSize / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in set(fraction: (drag.location.x - knobSize / 2) / travel) }
            )
        }
        .frame(height: knobSize + 2)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityElement()
        .accessibilityLabel(label.localized)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(value: value + step)
            case .decrement: set(value: value - step)
            @unknown default: break
            }
        }
    }

    private func set(fraction: Double) {
        set(value: range.lowerBound + min(max(fraction, 0), 1) * span)
    }

    private func set(value newValue: Double) {
        var v = min(max(newValue, range.lowerBound), range.upperBound)
        if step > 0 { v = (v / step).rounded() * step }
        v = min(max(v, range.lowerBound), range.upperBound)
        if v == 0 { v = 0 }  // no "-0.00" from rounding a small negative
        if v != value { value = v }
    }
}

/// A large selectable card with a live preview on the backdrop; the chosen one gets an outline and a bold caption.
struct VisualChoiceCard<Preview: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let preview: Preview

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(SettingsPalette.previewBackdrop)
                    preview
                }
                .frame(height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected ? SettingsPalette.selection : Color.white.opacity(isHovered ? 0.25 : 0.08),
                            lineWidth: isSelected ? 3 : 1)
                )
                Text(title.localized)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .settingAnchor(title)
    }
}

// MARK: - Search highlight

/// Marks a row the window's search can land on: the page scrolls to it by its title and it glows for a moment when it
/// was the one picked.
private struct SettingAnchor: ViewModifier {
    @Environment(SettingsNavigation.self) private var navigation: SettingsNavigation?
    let key: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let key {
            let isHighlighted = navigation?.highlightedSetting == key
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(isHighlighted ? 0.22 : 0))
                )
                .animation(.easeInOut(duration: 0.35), value: isHighlighted)
                .id(Self.id(for: key))
        } else {
            content
        }
    }

    static func id(for key: String) -> String { "setting:\(key)" }
}

extension View {
    func settingAnchor(_ title: String?) -> some View {
        modifier(SettingAnchor(key: title))
    }
}

/// Scrolls a settings page to the row a search picked and lets the highlight fade after a moment.
struct SettingScroller: ViewModifier {
    @Environment(SettingsNavigation.self) private var navigation: SettingsNavigation?
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onAppear { reveal(navigation?.highlightedSetting) }
            .onChange(of: navigation?.highlightedSetting) { _, key in reveal(key) }
    }

    private func reveal(_ key: String?) {
        guard let key else { return }
        // A page that just opened lays its rows out first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(SettingAnchor.id(for: key), anchor: .center)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if navigation?.highlightedSetting == key { navigation?.highlightedSetting = nil }
        }
    }
}
