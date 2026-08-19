import SwiftUI

/// Builds a screen's view model once and keeps it for as long as the screen is on screen.
///
/// SwiftUI re-evaluates a `body` whenever anything it reads changes, and a view model constructed
/// inside one is therefore constructed again — taking a fresh location provider with it, and
/// leaving the in-flight fix belonging to an object nobody holds any more. The arrival screen sat
/// on "looking for a location fix" forever because of exactly that. `@State` is what makes the
/// model outlive a redraw.
struct ScreenHost<Model: AnyObject, Content: View>: View {
    let make: () -> Model?
    @ViewBuilder let content: (Model) -> Content

    @State private var model: Model?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                // A screen whose model cannot be built is not a blank one — whatever pushed it
                // stays reachable behind the back button.
                Color.clear
            }
        }
        .onAppear { if model == nil { model = make() } }
    }
}
