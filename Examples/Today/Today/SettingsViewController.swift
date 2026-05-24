/*
 See LICENSE folder for this sample's licensing information.
 */

import UIKit

final class SettingsViewController: UITableViewController, LocalizedContentUpdating, UserInterfaceLayoutDirectionUpdating {
    private enum Row: Hashable {
        case followSystem
        case locale(AppLocale)
    }

    private let services: TodayLocalizationServices
    private let doneButton = UIBarButtonItem()
    private var rows: [Row] {
        [.followSystem] + services.localizationController.supportedLocales.map(Row.locale)
    }

    init(services: TodayLocalizationServices = .shared) {
        self.services = services
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(LanguageOptionCell.self, forCellReuseIdentifier: LanguageOptionCell.reuseIdentifier)
        doneButton.style = .done
        doneButton.target = self
        doneButton.action = #selector(close)
        reloadLocalizedContent()
        reloadLayoutDirection(services.localizationController.layoutDirection.uiLayoutDirection)
    }

    func reloadLocalizedContent() {
        title = services.resolver.string("settings.title", bundle: .main)
        navigationItem.title = title
        doneButton.title = services.resolver.string("common.done", bundle: .main)
        tableView.reloadData()
    }

    func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
        let appDirection = direction.appLayoutDirection
        view.semanticContentAttribute = appDirection.semanticContentAttribute
        tableView.semanticContentAttribute = appDirection.semanticContentAttribute
        navigationController?.view.semanticContentAttribute = appDirection.semanticContentAttribute
        navigationItem.setBarButtonItem(
            doneButton,
            side: .trailing,
            layoutDirection: direction
        )
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: LanguageOptionCell.reuseIdentifier,
            for: indexPath
        ) as? LanguageOptionCell else {
            return UITableViewCell()
        }

        switch rows[indexPath.row] {
        case .followSystem:
            cell.configure(
                title: services.resolver.string("language.follow.system", bundle: .main),
                subtitle: services.localizationController.currentLocale.localizedDisplayName(
                    preferredBy: services.localizationController.currentLocale
                ),
                titleLayoutDirection: services.localizationController.layoutDirection,
                appLayoutDirection: services.localizationController.layoutDirection,
                isSelected: services.localizationController.followsSystemLocale
            )
        case .locale(let locale):
            cell.configure(
                title: locale.nativeDisplayName,
                subtitle: locale.localizedDisplayName(
                    preferredBy: services.localizationController.currentLocale
                ),
                titleLayoutDirection: locale.layoutDirection,
                appLayoutDirection: services.localizationController.layoutDirection,
                isSelected: !services.localizationController.followsSystemLocale
                    && locale == services.localizationController.currentLocale
            )
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }

        switch rows[indexPath.row] {
        case .followSystem:
            services.localizationController.setFollowsSystemLocale()
        case .locale(let locale):
            services.localizationController.setLocale(identifier: locale.identifier)
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private final class LanguageOptionCell: UITableViewCell {
    static let reuseIdentifier = String(describing: LanguageOptionCell.self)

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        accessoryType = .none
    }

    func configure(
        title: String,
        subtitle: String,
        titleLayoutDirection: AppUserInterfaceLayoutDirection,
        appLayoutDirection: AppUserInterfaceLayoutDirection,
        isSelected: Bool
    ) {
        semanticContentAttribute = appLayoutDirection.semanticContentAttribute
        contentView.semanticContentAttribute = appLayoutDirection.semanticContentAttribute
        let textAlignment = appLayoutDirection.textAlignment

        titleLabel.text = title
        titleLabel.semanticContentAttribute = titleLayoutDirection.semanticContentAttribute
        titleLabel.textAlignment = textAlignment

        subtitleLabel.text = subtitle
        subtitleLabel.semanticContentAttribute = appLayoutDirection.semanticContentAttribute
        subtitleLabel.textAlignment = textAlignment

        accessoryType = isSelected ? .checkmark : .none
    }

    private func configureView() {
        selectionStyle = .default

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel

        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }
}

private extension AppUserInterfaceLayoutDirection {
    var textAlignment: NSTextAlignment {
        self == .rightToLeft ? .right : .left
    }
}
