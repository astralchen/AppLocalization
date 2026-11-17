import UIKit
import AppLocalization

final class UIKitLocalizationDemoViewController: UIViewController, UIKitLocalizationApplying {
    private let localizationController: LocalizationController
    private let resolver: LocalizedStringResolver
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let modalButton = UIButton(type: .system)
    private let pushButton = UIButton(type: .system)
    private let collectionView: UICollectionView
    private let cellReuseIdentifier = String(describing: LanguageDemoCollectionViewCell.self)
    private let onPushRequested: () -> Void

    init(
        localizationController: LocalizationController,
        resolver: LocalizedStringResolver,
        onPushRequested: @escaping () -> Void
    ) {
        self.localizationController = localizationController
        self.resolver = resolver
        self.onPushRequested = onPushRequested

        let layout = DemoCardLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = DemoSurfaceLayout.cornerRadius
        view.clipsToBounds = true

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        modalButton.accessibilityIdentifier = "uikit.show.modal"
        modalButton.addTarget(self, action: #selector(showModal), for: .touchUpInside)
        pushButton.addTarget(self, action: #selector(openPushPage), for: .touchUpInside)

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(LanguageDemoCollectionViewCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, modalButton, pushButton, collectionView])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = DemoSurfaceLayout.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: DemoSurfaceLayout.contentInset),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DemoSurfaceLayout.contentInset),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DemoSurfaceLayout.contentInset),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -DemoSurfaceLayout.contentInset),
            modalButton.heightAnchor.constraint(greaterThanOrEqualToConstant: DemoSurfaceLayout.buttonHeight),
            pushButton.heightAnchor.constraint(greaterThanOrEqualToConstant: DemoSurfaceLayout.buttonHeight),
            collectionView.heightAnchor.constraint(equalToConstant: DemoSurfaceLayout.collectionHeight)
        ])

        applyLocalization(LocalizationUpdate(snapshot: localizationController.currentSnapshot))
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        guard update.requiresLocalizedContentRefresh else { return }
        title = resolver.string("uikit.title", bundle: .main)
        navigationItem.title = title
        titleLabel.text = resolver.string("uikit.title", bundle: .main)
        subtitleLabel.text = resolver.string("uikit.subtitle", bundle: .main)
        modalButton.setTitle(resolver.string("show.modal", bundle: .main), for: .normal)
        pushButton.setTitle(resolver.string("pop.open", bundle: .main), for: .normal)
        for case let cell as LanguageDemoCollectionViewCell in collectionView.visibleCells {
            if let path = collectionView.indexPath(for: cell) {
                cell.configure(text: resolver.string("collection.item.\(path.item + 1)", bundle: .main))
            }
        }
    }

    @objc private func openPushPage() {
        // UIKit 桥接视图不直接依赖导航控制器。该视图可能由 SwiftUI 宿主控制器包装，
        // 因此通过闭包将事件交回应用持有的 `UINavigationController` 执行入栈。
        onPushRequested()
    }

    @objc private func showModal() {
        let modal = DemoModalViewController(
            localizationController: localizationController,
            resolver: resolver
        )
        let navigationController = UINavigationController(rootViewController: modal)
        present(navigationController, animated: true)
    }
}

extension UIKitLocalizationDemoViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        DemoSurfaceLayout.itemCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: cellReuseIdentifier,
            for: indexPath
        ) as? LanguageDemoCollectionViewCell else {
            return UICollectionViewCell()
        }

        cell.configure(text: resolver.string("collection.item.\(indexPath.item + 1)", bundle: .main))
        return cell
    }
}

extension UIKitLocalizationDemoViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? LanguageDemoCollectionViewCell else { return }
        cell.configure(text: resolver.string("collection.item.\(indexPath.item + 1)", bundle: .main))
    }
}

/// 示例卡片的排列策略由示例自身拥有，框架不提供布局子类。
private final class DemoCardLayout: UICollectionViewFlowLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool { true }

    override init() {
        super.init()
        scrollDirection = .horizontal
        minimumLineSpacing = DemoSurfaceLayout.spacing
        itemSize = CGSize(width: DemoSurfaceLayout.itemWidth, height: DemoSurfaceLayout.itemHeight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("请使用 init()")
    }
}

private final class LanguageDemoCollectionViewCell: UICollectionViewCell {
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        contentView.layer.borderColor = UIColor.separator.cgColor
    }

    func configure(text: String) {
        titleLabel.text = text
    }

    private func configureView() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = DemoSurfaceLayout.cornerRadius
        contentView.layer.borderColor = UIColor.separator.cgColor
        contentView.layer.borderWidth = 1

        titleLabel.font = .preferredFont(forTextStyle: .callout)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
}

final class DemoModalViewController: UIViewController, UIKitLocalizationApplying {
    private let localizationController: LocalizationController
    private let resolver: LocalizedStringResolver
    private let messageLabel = UILabel()
    private let languageControl = UISegmentedControl()
    private let directionLabel = UILabel()
    private let configuredCloseButton = UIButton(type: .system)
    private let navigationCloseButton = UIButton(type: .system)
    private lazy var closeButton = UIBarButtonItem(customView: navigationCloseButton)

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
        view.backgroundColor = .systemBackground

        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.numberOfLines = 0
        // 在同一个呈现页面中切换语言，验证按钮实例不重建时的配置布局。
        for (index, identifier) in localizationController.supportedLocalizations.enumerated() {
            let locale = AppLocale(identifier: identifier)
            languageControl.insertSegment(withTitle: locale.nativeDisplayName, at: index, animated: false)
        }
        languageControl.accessibilityIdentifier = "uikit.modal.language"
        languageControl.addTarget(self, action: #selector(selectLanguage), for: .valueChanged)
        configuredCloseButton.accessibilityIdentifier = "uikit.modal.configured.close"
        configuredCloseButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        directionLabel.accessibilityIdentifier = "uikit.modal.native.direction"
        directionLabel.textAlignment = .center
        directionLabel.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [messageLabel, languageControl, configuredCloseButton, directionLabel])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        // 使用真实 customView 验证热切换，不在页面中重新安装或替换导航项。
        navigationCloseButton.accessibilityIdentifier = "uikit.modal.navigation.close"
        navigationCloseButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        navigationItem.leftBarButtonItem = closeButton
        applyLocalization(LocalizationUpdate(snapshot: localizationController.currentSnapshot))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 挂载后显示 UIKit 的实际继承结果，而非控制器快照中的期望方向。
        directionLabel.text = view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? "RTL" : "LTR"
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        // 参考 UIKitLanguageDemo：方向改变时仅重置这个按钮的配置内容。
        // 保留 UIButton、target/action 和控件状态；同方向刷新不清空配置。
        if view.window != nil {
            directionLabel.text = view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? "RTL" : "LTR"
        }
        let semantic = update.semanticContentAttribute
        if configuredCloseButton.semanticContentAttribute != semantic {
            configuredCloseButton.configuration = nil
        }
        configuredCloseButton.semanticContentAttribute = semantic
        var configuration = UIButton.Configuration.tinted()
        configuration.title = resolver.string("close", bundle: .main)
        configuration.image = UIImage(systemName: "xmark.circle")
        configuration.imagePlacement = .leading
        configuration.imagePadding = 8
        configuredCloseButton.configuration = configuration
        configuredCloseButton.setNeedsLayout()
        languageControl.selectedSegmentIndex = localizationController.supportedLocalizations.firstIndex(of: update.snapshot.locale.identifier) ?? UISegmentedControl.noSegment
        guard update.requiresLocalizedContentRefresh else { return }
        title = resolver.string("modal.title", bundle: .main)
        navigationItem.title = title
        navigationCloseButton.setTitle(resolver.string("close", bundle: .main), for: .normal)
        messageLabel.text = resolver.string("modal.message", bundle: .main)
    }

    @objc private func selectLanguage() {
        let index = languageControl.selectedSegmentIndex
        guard localizationController.supportedLocalizations.indices.contains(index) else { return }
        localizationController.setLocale(identifier: localizationController.supportedLocalizations[index])
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
