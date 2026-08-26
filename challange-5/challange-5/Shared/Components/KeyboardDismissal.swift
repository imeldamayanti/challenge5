import SwiftUI
import UIKit

/// Putting the keyboard away by tapping off the field, and keeping screen-anchored chrome anchored
/// while it is up.
///
/// Neither is decoration. None of this app's text fields draws a Done key — the answer field on
/// `TaskDetailScreen` is a vertical-axis `TextField`, where Return inserts a newline rather than
/// submitting — so without a tap-off there is no way back out of the keyboard on a screen whose
/// controls it covers. `WriteJournalScreen` solved that locally first; this is the same gesture,
/// written once, so a new field-bearing screen does not have to rediscover it.
extension View {
    /// Dismisses the keyboard when a tap lands anywhere on this view that is not a control.
    ///
    /// Attach it to a screen's outermost container, not to the field. Child buttons and the field
    /// itself take a tap first — SwiftUI resolves the innermost gesture — so this only fires on the
    /// screen's own quiet areas, which is exactly the tap a walker means as "I'm done typing".
    ///
    /// The resignation goes through `UIResponder` rather than a `@FocusState`: a screen may carry
    /// more than one field, and the container does not need to know which of them is up.
    func kultaraDismissesKeyboardOnTap() -> some View {
        contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }

    /// Holds a bottom `safeAreaInset`'s content against the *screen's* bottom edge rather than the
    /// keyboard's, so a foot the frames draw at the home indicator stays there while typing.
    ///
    /// **`ignoresSafeArea(.keyboard, edges: .bottom)` does not do this**, which is the whole reason
    /// this modifier exists. It was tried in both of the two places it could go — on the inset's
    /// content, and on the whole screen outside `safeAreaInset` — and neither moved the foot: the
    /// map hint still rose with the keyboard and, on the shipped task sheet, ended up printed
    /// across the parchment (seen on iPhone 17 / iOS 26.5). SwiftUI raises the bottom safe area for
    /// the keyboard and places the inset against the raised edge regardless. `KultaraRootView`'s
    /// tab bar carries the same `ignoresSafeArea` call and is not evidence against this — the bar
    /// hides on the screens that have fields, so nobody has watched it try.
    ///
    /// So the lift is measured and cancelled instead. The offset is exactly what the keyboard added
    /// on top of the home indicator's own inset, taken from the notification's frame, which means
    /// it is zero whenever there is no keyboard and cannot drift from what SwiftUI actually did.
    /// The foot ends up *behind* the keyboard, which is where the frame draws it and what the
    /// walker sees the moment they tap away.
    func kultaraStaysBelowKeyboard() -> some View {
        modifier(KeyboardAnchoredToScreenBottom())
    }
}

/// Cancels SwiftUI's keyboard lift for one view. See `kultaraStaysBelowKeyboard()`.
private struct KeyboardAnchoredToScreenBottom: ViewModifier {
    @State private var lift: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: lift)
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification)
            ) { note in
                update(from: note)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification)
            ) { _ in
                lift = 0
            }
    }

    private func update(from note: Notification) {
        guard
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
        else { return }
        // What the keyboard covers, less the inset the screen already had without it: the safe area
        // rose by the difference, so that difference is what has to come back off.
        let covered = window.bounds.maxY - frame.minY
        lift = max(0, covered - window.safeAreaInsets.bottom)
    }
}
