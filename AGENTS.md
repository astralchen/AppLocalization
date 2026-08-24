# AGENTS.md

## Project Overview

This repository contains a reusable Swift package, `AppLocalization`, plus a runnable iOS example app.

- Package: `Sources/AppLocalization`
  - Core state: `Core/`
  - String lookup: `Strings/`
  - Direction helpers: `Directional/`
  - SwiftUI adapters: `SwiftUI/`
  - UIKit adapters: `UIKit/`
- Tests: `Tests/AppLocalizationTests`
- Main README: `README.md`
- Example app: `Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj`
- Example String Catalog: `Examples/LanguageSwitchingDemo/LanguageSwitchingDemo/Localizable.xcstrings`
- Example app-name String Catalog: `Examples/LanguageSwitchingDemo/LanguageSwitchingDemo/InfoPlist.xcstrings`
- App icon source: `Design/AppIcon`
- App icon asset catalog: `Examples/LanguageSwitchingDemo/LanguageSwitchingDemo/Assets.xcassets`

The package implements in-app language switching without restarting the app. It supports SwiftUI, UIKit, mixed stacks, multiple windows/scenes, presented view controllers, `UITableView` and `UICollectionView` layout direction, navigation direction, semantic gestures, and modern `Localizable.xcstrings` resources.

## App Icon Rules

- Keep editable icon source in `Design/AppIcon`.
- Keep Xcode-consumed icon assets in `Examples/LanguageSwitchingDemo/LanguageSwitchingDemo/Assets.xcassets/AppIcon.appiconset`.
- Use `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` for the demo target.
- App icon variants should include Any/Light, Dark, and Tinted 1024 px resources.
- Tinted icon artwork must be grayscale so iOS 26 can apply the user's selected theme color.
- Avoid readable text, flags, or country-specific symbols inside the icon.

## Architecture Rules

- Treat the app-selected locale as app state, not as a system language mutation.
- Do not use `AppleLanguages` or `Bundle.main` swizzling as the primary runtime language-switching mechanism.
- Keep `LocalizationController` as the single source of truth for:
  - `currentLocale`
  - `locale`
  - `layoutDirection`
  - persisted locale identifier
  - localization-change notifications
- Keep translation lookup behind `LocalizedStringResolver`.
- Prefer `Localizable.xcstrings` for app UI strings and `InfoPlist.xcstrings` for bundle metadata such as `CFBundleDisplayName`. Legacy `.strings` files may appear as compiled build outputs, but source resources should use String Catalogs.
- Keep app-name localization out of `LocalizedStringResolver`; iOS reads `CFBundleDisplayName` from Info.plist localization resources and it does not participate in in-app live switching.
- Deliver text and direction as one `UIKitLocalizationUpdate`, while preserving this internal order:
  - text changes update labels, titles, buttons, placeholders, menus, and visible cells
  - direction changes update semantic content attributes, table/collection layouts, navigation side mapping, gestures, and transition directions
- Default to lightweight UI reload. Root-window rebuild is an opt-in fallback for direction changes or system UI that cannot reliably update otherwise.

## UIKit Integration Rules

- UIKit screens should implement `UIKitLocalizationApplying`; apply direction targets before text, menus, and configurations.
- Create one `UIWindowSceneLocalizationCoordinator(localizationController:)`, explicitly register only app-owned Windows, unregister them on disconnect, and synchronize them on activation.
- Do not use `UIView.appearance()` for runtime semantic changes, enumerate system Windows, or recurse through UIKit private subviews.
- Use `UIViewLayoutDirectionTarget` with `.inherited`, `.followApplication`, `.followContainer`, or `.fixed(...)` at public component boundaries.
- Use `.reattachExistingRoot` or `.recreateRoot` only as explicit recovery actions; recreation requires a registered root factory.
- Presented chains must be included. Ordinary presented view controllers can reload; alerts, menus, context menus, and third-party SDK views may need dismiss/recreate behavior.
- For `UITableView`, use `applyLocalization(_:preservingVisibleRow:)`; for `UICollectionView`, use `applyLocalization(_:preservingVisibleItem:rebuildingLayoutWith:)`.
- Create a `UIKitLocalizationContext` from a snapshot provider. It may retain the provider, but must read a fresh snapshot for every configuration or attachment and must not cache a `LocalizationSnapshot` or `UIKitLocalizationUpdate`.
- Use `UIKitLocalizationContext.makeCellRegistration` and `makeSupplementaryRegistration` so direction restoration runs before the business handler. For UITableView, use the localized dequeue helpers before assigning configuration or text. Use `restoreOnAttachment` from `willDisplay`.
- The reusable lifecycle API owns only public reusable boundaries. Cells update themselves and `contentView`; header/footer/supplementary views update themselves. Business components declare only special owned targets such as fixed LTR, playback, spatial, manual-frame, horizontal-scroll, or cached-direction nodes.
- Reapply the latest snapshot when reusable or detached content materializes again. Every async completion must validate `LocalizationSnapshot.revision`.
- Use `NavigationItemPlacement.leading/trailing` mapping instead of hard-coded left/right navigation items.

## SwiftUI Integration Rules

- Wrap SwiftUI roots with `.appLocalizationEnvironment(localizationController)`.
- Avoid caching localized `String` values in `init`, `static let`, or long-lived view model state unless they are recomputed on language change.
- When bridging UIKit into SwiftUI, make `UIViewRepresentable` / `UIViewControllerRepresentable` read `context.environment.locale` and `context.environment.layoutDirection` in `update...`.
- SwiftUI sheets should inherit the same language environment as the root.

## Language Picker Rules

- Display normal language options with two lines:
  - main title: `locale.nativeDisplayName`, stable and not affected by the current app language
  - subtitle: `locale.localizedDisplayName(preferredBy: localizationController.currentLocale)`, refreshed with the current app language
- Render the main title using the candidate locale's own layout direction. This prevents Chinese or English names from being visually reordered under an RTL app environment.
- For full-width UIKit labels, keep the title label's semantic direction tied to the candidate locale, but align both title and subtitle to the current app's semantic leading edge. Writing direction and row alignment are separate concerns.
- Display the "follow system" row as a setting state, not as a real locale:
  - main title comes from `resolver.string("language.follow.system", bundle: .main)` and follows the current app language
  - subtitle shows the resolved effective app locale
  - checkmark is shown only when `followsSystemLocale == true`
- Keep the matching logic separate from display logic. Use `LocalizationController` to resolve system preferences to the closest supported locale.

## Direction And Gesture Rules

- Never encode navigation or gesture intent as `translation.x > 0` directly.
- Use `DirectionalLayout.semanticHorizontalDirection(translationX:layoutDirection:)`.
- Use `DirectionalLayout.backSwipeRectEdge(layoutDirection:)` for custom edge-pan gestures.
- Use `DirectionalLayout.backChevronSystemName(layoutDirection:)` for custom back icons.
- Do not blindly mirror spatial or playback content. Maps, charts, timelines, media controls, and game layouts may need `DirectionalContentSemantics.spatial` or `.playback`.

## Annotated Integration Examples

### 1. Create The Shared Language Services

```swift
final class AppLocaleServices: ObservableObject {
    // Single source of truth for the app-selected locale.
    let localizationController: LocalizationController

    // Use one resolver at the app/service layer so every screen shares the same lookup policy.
    let resolver: LocalizedStringResolver

    init() {
        let localizationController = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: UserDefaultsLocalePreferenceStore(
                key: "app.locale.identifier"
            )
        )

        self.localizationController = localizationController
        self.resolver = LocalizedStringResolver(
            localeProvider: { [localizationController] in
                localizationController.currentLocale
            },
            fallbackLocale: .englishUS,
            missingKeyHandler: { key, locale, _ in
                // Debug builds should make missing keys noisy.
                assertionFailure("Missing localization key '\(key)' for \(locale.identifier)")
            }
        )
    }
}
```

### 2. Wire SwiftUI Root And All Scenes

```swift
@main
struct MyApp: App {
    @StateObject private var services = AppLocaleServices()

    var body: some Scene {
        WindowGroup {
            RootView(
                localizationController: services.localizationController,
                resolver: services.resolver
            )
            // Injects localizationController, locale, and layoutDirection into the SwiftUI tree.
            .appLocalizationEnvironment(services.localizationController)
            // UIKit still needs explicit reload because labels/buttons/nav items are imperative.
            .onReceive(
                NotificationCenter.default.publisher(
                    for: LocalizationController.localizationDidChangeNotification,
                    object: services.localizationController
                )
            ) { notification in
                guard let change = notification.userInfo?[LocalizationController.localizationChangeUserInfoKey] as? LocalizationChange else {
                    return
                }

                services.localizationCoordinator.apply(change)
            }
        }
    }
}
```

### 3. Switch Locale From UI

```swift
struct LocalePickerView: View {
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    var body: some View {
        List {
            Button {
                localizationController.setFollowsSystemLocale()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // "Follow system" is a setting state, so its title is localized by the current app locale.
                        Text(resolver.string("language.follow.system", bundle: .main))
                        Text(localizationController.currentLocale.localizedDisplayName(
                            preferredBy: localizationController.currentLocale
                        ))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if localizationController.followsSystemLocale {
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(localizationController.supportedLocales, id: \.identifier) { locale in
                Button {
                    // Updates memory state, persists the selection, and publishes LocalizationChange.
                    localizationController.setLocale(identifier: locale.identifier)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            // Stable native name for the main title.
                            Text(locale.nativeDisplayName)
                                .environment(\.layoutDirection, locale.layoutDirection.swiftUILayoutDirection)

                            // Localized explanation for the current app language.
                            Text(locale.localizedDisplayName(preferredBy: localizationController.currentLocale))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !localizationController.followsSystemLocale && locale == localizationController.currentLocale {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}
```

### 4. Localize SwiftUI Text

```swift
struct SettingsView: View {
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    var body: some View {
        Form {
            // Resolve inside body so localizationController changes recompute the visible text.
            Text(resolver.string("settings.language.title", bundle: .main))

            // Avoid storing this translated String in init/static/view-model state.
            Text(resolver.string("settings.language.subtitle", bundle: .main))
        }
        .navigationTitle(resolver.string("settings.title", bundle: .main))
    }
}
```

### 5. Reload UIKit Screens

```swift
final class SettingsViewController: UIViewController, UIKitLocalizationApplying {
    private let resolver: LocalizedStringResolver
    private let localizationController: LocalizationController
    private let titleLabel = UILabel()
    private let confirmButton = UIButton(type: .system)

    init(localizationController: LocalizationController, resolver: LocalizedStringResolver) {
        self.localizationController = localizationController
        self.resolver = resolver
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyLocalization(.initial(snapshot: localizationController.currentSnapshot))
    }

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        if update.requiresLayoutDirectionRefresh {
            UIViewLayoutDirectionUpdater.apply(
                update,
                to: [UIViewLayoutDirectionTarget(confirmButton, policy: .followApplication)]
            )
        }
        guard update.requiresLocalizedContentRefresh else { return }
        // UIKit values are one-time assignments, so set every visible string again.
        title = resolver.string("settings.title", bundle: .main)
        navigationItem.title = title
        titleLabel.text = resolver.string("settings.language.title", bundle: .main)
        confirmButton.setTitle(resolver.string("common.confirm", bundle: .main), for: .normal)
    }
}
```

### 6. Bridge UIKit Inside SwiftUI

```swift
struct SettingsUIKitBridge: UIViewControllerRepresentable {
    let localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    func makeUIViewController(context: Context) -> SettingsViewController {
        SettingsViewController(localizationController: localizationController, resolver: resolver)
    }

    func updateUIViewController(_ viewController: SettingsViewController, context: Context) {
        // Reading these environment values makes the bridge respond when SwiftUI locale/direction changes.
        _ = context.environment.locale
        _ = context.environment.layoutDirection

        viewController.applyLocalization(
            .initial(snapshot: localizationController.currentSnapshot)
        )
    }
}
```

### 7. Refresh Direction-Sensitive Table And Collection Views

```swift
final class SettingsViewController: UITableViewController, UIKitLocalizationApplying {
    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        // Refreshes visible reusable-view layout without calling reloadData().
        tableView.applyLocalization(
            update,
            preservingVisibleRow: true
        )
    }
}
```

```swift
final class ProductsViewController: UIViewController, UIKitLocalizationApplying {
    private let collectionView: UICollectionView

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        // Updates semanticContentAttribute, invalidates layout, and keeps the logical visible item.
        collectionView.applyLocalization(
            update,
            preservingVisibleItem: true
        )
    }
}
```

### 8. Use Semantic Gesture Direction

```swift
final class CardSwipeController: UIViewController {
    private var layoutDirection: AppUserInterfaceLayoutDirection {
        view.effectiveUserInterfaceLayoutDirection.appLayoutDirection
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translationX = recognizer.translation(in: view).x
        let semanticDirection = DirectionalLayout.semanticHorizontalDirection(
            translationX: translationX,
            layoutDirection: layoutDirection
        )

        switch semanticDirection {
        case .leading:
            // Leading means left in LTR and right in RTL.
            revealLeadingAction()
        case .trailing:
            // Trailing means right in LTR and left in RTL.
            revealTrailingAction()
        }
    }

    private func revealLeadingAction() {}
    private func revealTrailingAction() {}
}
```

### 9. Configure Custom Navigation Direction

```swift
final class DetailViewController: UIViewController, UIKitLocalizationApplying {
    private let closeItem = UIBarButtonItem(systemItem: .close)

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        guard update.requiresLayoutDirectionRefresh else { return }
        // Keep intent semantic: close belongs on trailing, regardless of physical left/right.
        navigationItem.setBarButtonItem(
            closeItem,
            side: .trailing,
            layoutDirection: update.layoutDirection
        )

        // Custom back assets must flip with the app direction.
        let chevronName = DirectionalLayout.backChevronSystemName(
            layoutDirection: update.snapshot.layoutDirection
        )
        navigationItem.backBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: chevronName),
            style: .plain,
            target: nil,
            action: nil
        )
    }
}
```

### 10. Use `Localizable.xcstrings`

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "settings.language.title" : {
      "comment" : "Title for the locale settings row.",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Language"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "语言"
          }
        },
        "ar" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "اللغة"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

### 11. Use `InfoPlist.xcstrings` For App Names

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "CFBundleDisplayName" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Language Demo"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "语言演示"
          }
        },
        "ar" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "عرض اللغة"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

App names, launch screens, permission prompts, delivered notifications, widgets, and extension processes are system-owned boundaries. Do not promise in-app live refresh for them.

## Verification Commands

Run package tests after changing the core library:

```bash
swift test
```

Build the reusable package for iOS after touching UIKit or SwiftUI conditionally compiled code:

```bash
xcodebuild -scheme AppLocalization -destination 'generic/platform=iOS' build
```

Build the demo app after changing anything under `Examples/LanguageSwitchingDemo` or public APIs used by the demo:

```bash
xcodebuild -project Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj -scheme LanguageSwitchingDemo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

If SwiftPM or Xcode needs to write compiler caches outside the sandbox, rerun the same command with the required sandbox escalation rather than changing source paths or build settings.

## Style And Compatibility

- Keep source files ASCII unless editing an existing localized resource such as `.xcstrings`.
- Keep public APIs small and explicit. This package is intended to be copied into real apps or imported as a local package.
- Maintain iOS 15 compatibility unless the package manifest and example project are intentionally raised together.
- Do not introduce external dependencies without a strong reason.
- Prefer small focused files over large mixed UI/business-logic files.
- Add or update tests when changing behavior in `LocalizationController`, `LocalizedStringResolver`, or `DirectionalLayout`.

## Common Pitfalls To Avoid

- Updating only the current window instead of every connected `UIWindowScene`.
- Forgetting presented view controllers.
- Refreshing text but not layout direction.
- Calling `reloadData()` inside the table direction helper instead of leaving diffable content snapshot-driven.
- Invalidating a collection layout without preserving the logical visible item.
- Storing translated strings instead of localization keys or recomputable values.
- Assuming `.xcstrings` will remain visible at runtime exactly as authored; Xcode may compile String Catalogs into `.lproj/*.strings` outputs.
- Putting app names in `Localizable.xcstrings`; use `InfoPlist.xcstrings` for `CFBundleDisplayName`.
- Adding icon PNGs without preserving an editable source in `Design/AppIcon`.
- Using color-dependent detail in the tinted icon; keep the tinted variant readable as grayscale.
- Promising that app-name changes will live-refresh after an in-app language switch. System metadata follows system localization behavior.
- Letting language option main titles inherit the current app RTL/LTR environment; use the candidate locale direction for `nativeDisplayName`.
- Treating root rebuild as the normal refresh path. Use it as a fallback, especially for RTL/LTR changes.
