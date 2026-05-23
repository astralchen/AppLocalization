# LanguageSwitchingDemo

Open `LanguageSwitchingDemo.xcodeproj` in Xcode and run the `LanguageSwitchingDemo` scheme.

This sample app demonstrates:

- SwiftUI live localization refresh through `.locale` and `.layoutDirection`.
- UIKit refresh through `LocalizedContentUpdating` and `UserInterfaceLayoutDirectionUpdating`.
- Presented modal refresh through the presented view controller chain.
- `UICollectionView` direction invalidation when switching between LTR and RTL.
- Semantic gesture direction instead of hard-coded physical left/right checks.
- A modern `Localizable.xcstrings` String Catalog.
- App display name localization through `InfoPlist.xcstrings`; this is system-owned metadata and is not refreshed by in-app language switching.
- Light, dark, and tinted app icon variants through `Assets.xcassets/AppIcon.appiconset`.

The sample compiles the library sources from `../../Sources/AppLocalization` directly into the app target so it can be opened without extra package setup.
