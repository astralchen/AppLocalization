import UIKit

final class UIKitLocalizationDemoViewController: UIViewController, LocalizedContentUpdating, UserInterfaceLayoutDirectionUpdating {
    private let localizationController: LocalizationController
    private let resolver: LocalizedStringResolver
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let modalButton = UIButton(type: .system)
    private let pushButton = UIButton(type: .system)
    private let collectionView: UICollectionView
    private let cellReuseIdentifier = "LanguageDemoCell"
    private let onPushRequested: () -> Void

    init(
        localizationController: LocalizationController,
        resolver: LocalizedStringResolver,
        onPushRequested: @escaping () -> Void
    ) {
        self.localizationController = localizationController
        self.resolver = resolver
        self.onPushRequested = onPushRequested

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.itemSize = CGSize(width: 132, height: 64)
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
        view.layer.cornerRadius = 8
        view.clipsToBounds = true

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        modalButton.addTarget(self, action: #selector(showModal), for: .touchUpInside)
        pushButton.addTarget(self, action: #selector(openPushPage), for: .touchUpInside)

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, modalButton, pushButton, collectionView])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            collectionView.heightAnchor.constraint(equalToConstant: 76)
        ])

        reloadLocalizedContent()
        reloadLayoutDirection(localizationController.layoutDirection.uiLayoutDirection)
    }

    func reloadLocalizedContent() {
        title = resolver.string("uikit.title", bundle: .main)
        navigationItem.title = title
        titleLabel.text = resolver.string("uikit.title", bundle: .main)
        subtitleLabel.text = resolver.string("uikit.subtitle", bundle: .main)
        modalButton.setTitle(resolver.string("show.modal", bundle: .main), for: .normal)
        pushButton.setTitle(resolver.string("pop.open", bundle: .main), for: .normal)
        collectionView.reloadData()
    }

    func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
        let appDirection = direction.appLayoutDirection
        view.semanticContentAttribute = appDirection.semanticContentAttribute
        collectionView.applyUserInterfaceLayoutDirection(appDirection)
    }

    @objc private func openPushPage() {
        // UIKit representable 不直接依赖 navigationController。
        // 它可能被 SwiftUI HostingController 包住，直接 push 容易拿不到正确导航栈；
        // 所以通过 closure 把事件交回 SwiftUI root，由外层 NavigationLink 统一执行 push。
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
        3
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.backgroundColor = .systemBackground
        cell.contentView.layer.cornerRadius = 8
        cell.contentView.layer.borderColor = UIColor.separator.cgColor
        cell.contentView.layer.borderWidth = 1

        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .callout)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.text = resolver.string("collection.item.\(indexPath.item + 1)", bundle: .main)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
        ])

        return cell
    }
}

final class DemoModalViewController: UIViewController, LocalizedContentUpdating, UserInterfaceLayoutDirectionUpdating {
    private let localizationController: LocalizationController
    private let resolver: LocalizedStringResolver
    private let messageLabel = UILabel()

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
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(close)
        )

        reloadLocalizedContent()
        reloadLayoutDirection(localizationController.layoutDirection.uiLayoutDirection)
    }

    func reloadLocalizedContent() {
        title = resolver.string("modal.title", bundle: .main)
        navigationItem.title = title
        navigationItem.rightBarButtonItem?.title = resolver.string("close", bundle: .main)
        messageLabel.text = resolver.string("modal.message", bundle: .main)
    }

    func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
        view.semanticContentAttribute = direction.appLayoutDirection.semanticContentAttribute
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
