import SwiftUI
import AppKit

/// The raw OS dark-mode setting.
///
/// Read from the global `AppleInterfaceStyle` default rather than SwiftUI's
/// `colorScheme` or the window's `effectiveAppearance`: on macOS 26 a window that
/// hosts Liquid Glass is promoted to a light "glass" appearance, which flips both
/// of those to light even while the system is dark (the ring skin hit the same
/// thing — see `WheelActionsView.isDark`). The popup is rebuilt on every show, so
/// not reacting to a live switch is fine; the next popup picks the new value up.
enum SystemAppearance {
    static var isDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
}

/// Whether the real system Liquid Glass can be drawn: macOS 26+ at run time, and
/// an SDK new enough to know `.glassEffect` at compile time.
enum LiquidGlassSupport {
    static var isAvailable: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { return true }
        #endif
        return false
    }
}

extension View {
    /// The background of every rectangular piece of popup chrome — the capsule
    /// bar, the loading pill, the result panel and a group's dropdown.
    ///
    /// `glass == false` (or a system without Liquid Glass) is the original look:
    /// an `NSVisualEffectView` `.menu` blur with a layer-masked hairline border,
    /// so the edge stays crisp and the drop shadow is the window's own.
    ///
    /// `glass == true` draws the system Liquid Glass in the same continuous
    /// rounded rectangle. Three things need care, all learnt on the ring skin:
    ///  - Click-through. The glass is composited by the window server and leaves
    ///    the app's backing store clear, and a fully transparent window pixel is
    ///    not the window's — a mouse-down there goes to the app behind. So a
    ///    near-invisible fill is painted in exactly the chrome's shape, giving the
    ///    window real (alpha > 0) pixels to hit. Nothing is painted outside the
    ///    shape, so the rounded corners stay click-through and invisible.
    ///  - Dark mode. The glass window is promoted to a light appearance, so the
    ///    content's `colorScheme` is pinned back to the raw system setting (text
    ///    and SF Symbols stay light in dark mode), and a controlled dark scrim
    ///    keeps the glass from going pale over bright backdrops, which would
    ///    leave light glyphs unreadable.
    ///  - Shadow. The window keeps `hasShadow`; the scrim/backing fill is what
    ///    gives the window an alpha outline for the shadow to follow. The glass
    ///    draws its own specular rim, so no extra border is added.
    @ViewBuilder
    func popupChrome(glass: Bool, cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if glass, #available(macOS 26.0, *) {
            modifier(GlassChrome(cornerRadius: cornerRadius))
        } else {
            classicChrome(cornerRadius: cornerRadius)
        }
        #else
        classicChrome(cornerRadius: cornerRadius)
        #endif
    }

    private func classicChrome(cornerRadius: CGFloat) -> some View {
        background(VisualEffectBlur(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private struct GlassChrome: ViewModifier {
    let cornerRadius: CGFloat

    /// Light mode: just enough alpha to own the click. Dark mode: a real scrim,
    /// pinning the glass to a predictable dark tone (same 0.34 the ring uses on
    /// its band, a touch lighter because the capsule is a solid slab, not a
    /// thin ring).
    private var backing: Color {
        SystemAppearance.isDark ? Color.black.opacity(0.28) : Color.white.opacity(0.008)
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let dark = SystemAppearance.isDark
        content
            .environment(\.colorScheme, dark ? .dark : .light)
            .background(shape.fill(backing))
            .glassEffect(.regular, in: shape)
            .contentShape(shape)
    }
}
#endif
