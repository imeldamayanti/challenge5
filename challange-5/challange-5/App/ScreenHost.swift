import SwiftUI

/// Builds a screen's view model once and keeps it for as long as the screen is on screen.
///
/// SwiftUI re-evaluates a `body` whenever anything it reads changes, and a view model constructed
/// inside one is therefore constructed again — taking a fresh location provider with it, and
/// leaving the in-flight fix belonging to an object nobody holds any more. The arrival screen sat
/// on "looking for a location fix" forever because of exactly that. `@State` is what makes the
/// model outlive a redraw.
struct ScreenHost<Model: AnyObject, Content: View>: View {
    /// The navigation bar's visibility for the frames before the model exists.
    ///
    /// The model is built in `onAppear`, so a pushed screen draws its placeholder first — and a
    /// placeholder carrying no `toolbar` modifier gets the navigation bar the stack shows by
    /// default. On a screen that then hides the bar, that reads as a bar appearing and vanishing
    /// during the push. Screens that mean to be chromeless say so here so there is nothing to
    /// vanish.
    var navigationBarWhileLoading: Visibility = .automatic
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
                    .toolbar(navigationBarWhileLoading, for: .navigationBar)
            }
        }
        .onAppear { if model == nil { model = make() } }
    }
}
