/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit
import AppLocalization

final class SettingsViewController: UITableViewController, UIKitLocalizationApplying {
    private enum Row: Hashable {
        case followSystem
        case locale(AppLocale)
    }

    private let services: TodayLocalizationServices
    private let doneButton = UIBarButtonItem()
    private var rows: [Row] {
        [.followSystem] + services.localizationController.supportedLocalizations.map { Row.locale(AppLocale(identifier: $0)) }
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
        navigationItem.rightBarButtonItem = doneButton
        applyLocalization(LocalizationUpdate(snapshot: services.localizationController.currentSnapshot))
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        guard update.requiresLocalizedContentRefresh else { return }
        title = services.resolver.string("settings.title", bundle: .main)
        navigationItem.title = title
        doneButton.title = services.resolver.string("common.done", bundle: .main)
        for path in tableView.indexPathsForVisibleRows ?? [] {
            if let cell = tableView.cellForRow(at: path) as? LanguageOptionCell { configure(cell, at: path) }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: LanguageOptionCell.reuseIdentifier,
            for: indexPath
        ) as! LanguageOptionCell

        configure(cell, at: indexPath)

        return cell
    }

    private func configure(_ cell: LanguageOptionCell, at indexPath: IndexPath) {
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

    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard let cell = cell as? LanguageOptionCell else { return }
        configure(cell, at: indexPath)
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

private final class LanguageOptionCell: UITableViewCell, UIKitLocalizationApplying {
    static let reuseIdentifier = String(describing: LanguageOptionCell.self)

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var titleLayoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    private var appLayoutDirection: UIUserInterfaceLayoutDirection = .leftToRight

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
        titleLayoutDirection: UIUserInterfaceLayoutDirection,
        appLayoutDirection: UIUserInterfaceLayoutDirection,
        isSelected: Bool
    ) {
        self.titleLayoutDirection = titleLayoutDirection
        self.appLayoutDirection = appLayoutDirection

        titleLabel.text = title
        subtitleLabel.text = subtitle
        accessoryType = isSelected ? .checkmark : .none
        applyLayoutDirections()
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        appLayoutDirection = update.snapshot.layoutDirection
        applyLayoutDirections()
    }

    private func applyLayoutDirections() {
        // 候选语言只决定标题文本自身的 bidi 书写语义；标题与副标题仍应对齐到
        // 当前 App 的语义前缘。否则在中文界面中，Arabic 标题会独自靠右，
        // 与同一行靠左的中文副标题视觉断裂。
        titleLabel.semanticContentAttribute = titleLayoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        titleLabel.textAlignment = appLayoutDirection == .rightToLeft ? .right : .left

        subtitleLabel.semanticContentAttribute = appLayoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        subtitleLabel.textAlignment = appLayoutDirection == .rightToLeft ? .right : .left
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
