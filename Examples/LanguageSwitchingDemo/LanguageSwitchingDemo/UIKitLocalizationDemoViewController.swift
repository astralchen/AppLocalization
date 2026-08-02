import UIKit
import AppLocalization

final class UIKitLocalizationDemoViewController: UIViewController, LocalizedContentUpdating, UserInterfaceLayoutDirectionUpdating {
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

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = DemoSurfaceLayout.spacing
        layout.itemSize = CGSize(
            width: DemoSurfaceLayout.itemWidth,
            height: DemoSurfaceLayout.itemHeight
        )
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

        modalButton.addTarget(self, action: #selector(showModal), for: .touchUpInside)
        pushButton.addTarget(self, action: #selector(openPushPage), for: .touchUpInside)

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
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
        // UIKit 桥接视图不直接依赖导航控制器。该视图可能由 SwiftUI 宿主控制器包装，
        // 因此通过闭包将事件交回 SwiftUI 根视图，由外层 `NavigationLink` 执行入栈。
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

final class DemoModalViewController: UIViewController, LocalizedContentUpdating, UserInterfaceLayoutDirectionUpdating {
    private let localizationController: LocalizationController
    private let resolver: LocalizedStringResolver
    private let messageLabel = UILabel()
    private lazy var closeButton = UIBarButtonItem(
        title: nil,
        style: .plain,
        target: self,
        action: #selector(close)
    )

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

        reloadLocalizedContent()
        reloadLayoutDirection(localizationController.layoutDirection.uiLayoutDirection)
    }

    func reloadLocalizedContent() {
        title = resolver.string("modal.title", bundle: .main)
        navigationItem.title = title
        closeButton.title = resolver.string("close", bundle: .main)
        messageLabel.text = resolver.string("modal.message", bundle: .main)
    }

    func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
        view.semanticContentAttribute = direction.appLayoutDirection.semanticContentAttribute
        navigationItem.setBarButtonItem(
            closeButton,
            side: .leading,
            layoutDirection: direction
        )
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
