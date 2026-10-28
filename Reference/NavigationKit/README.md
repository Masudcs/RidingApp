# NavigationKit (reference copy)

Copied unchanged from "Why Not SwiftUI!" by Md. Mahmudul Hasan Shohag
(https://github.com/ImaginativeShohag/Why-Not-SwiftUI), Apache License 2.0 (see `LICENSE`).

This folder is NOT part of the app target: it sits outside `RidingApps/`, so Xcode does not compile it
and `Scripts/generate_pbxproj.py` ignores it. It is kept here only as a reference for a future
`NavController`-based navigation system. To use it later, copy `Sources/` into the app and replace the
`SuperLog` logging with `AppLogger`.

Note: the demo screens declare types named `RootScreen` and `RootScreenController`, which would clash
with the app's own `RootScreen`; rename them when copying the demos.
