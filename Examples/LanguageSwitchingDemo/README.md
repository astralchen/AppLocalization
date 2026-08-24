# LanguageSwitchingDemo

Open `LanguageSwitchingDemo.xcodeproj` in Xcode and run the `LanguageSwitchingDemo` scheme.

This sample app demonstrates:

- SwiftUI live localization refresh through `.locale` and `.layoutDirection`.
- Atomic UIKit refresh through `UIKitLocalizationApplying` and explicit `UIViewLayoutDirectionTarget` policies.
- Explicit weak Window registration, optional caller-filtered scene discovery, revision checks, and attachment-time resynchronization.
- Presented modal refresh through the presented view controller chain.
- `UICollectionView` direction invalidation when switching between LTR and RTL.
- Semantic gesture direction instead of hard-coded physical left/right checks.
- A modern `Localizable.xcstrings` String Catalog.
- App display name localization through `InfoPlist.xcstrings`; this is system-owned metadata and is not refreshed by in-app language switching.
- Light, dark, and tinted app icon variants through `Assets.xcassets/AppIcon.appiconset`.

The Xcode project links the repository root as a local Swift Package and imports the `AppLocalization` library product. The package reference is already configured, so no additional dependency setup is required.
