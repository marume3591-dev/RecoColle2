import UIKit

// MARK: - 検索クエリ種別

enum DiscogsSearchQuery {
    case text(String)           // アーティスト名・タイトルなどのフリーワード
    case catno(String)          // カタログ番号
}

// MARK: - OCRResultViewController

final class OCRResultViewController: UIViewController {

    // MARK: - Properties

    var results: [[String: Any]] = []           // 1ページ目（呼び出し元から渡される）
    var onSelect: (([String: Any]) -> Void)?
    var searchQuery: DiscogsSearchQuery? = nil  // 追加ページ取得用クエリ

    enum SortOrder {
        case searchOrder, yearAsc, yearDesc, formatAsc, formatDesc
    }

    private var sortOrder: SortOrder = .searchOrder
    private var selectedCountry: String? = nil
    private var selectedFormat: String? = nil
    private var filteredResults: [[String: Any]] = []
    private var availableCountries: [String] = []
    private var availableFormats: [String] = []

    // ページネーション
    private var currentPage: Int = 1
    private var totalPages: Int = 1
    private var isFetching: Bool = false

    // MARK: - UI

    private let filterBar     = UIView()
    private let countLabel    = UILabel()
    private let countryButton = UIButton(type: .system)
    private let formatButton  = UIButton(type: .system)
    private let resetButton   = UIButton(type: .system)
    private let tableView     = UITableView()
    private let emptyLabel    = UILabel()
    private let footerSpinner = UIActivityIndicatorView(style: .medium)

    // スクロールトップボタン
    private let scrollTopButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "arrow.up", withConfiguration: config), for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.85)
        button.tintColor = .white
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.alpha = 0
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Discogs credentials

    private let key       = "VTvQRnPmaaybKvVDYsej"
    private let secret    = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
    private let userAgent = "RecoColle2/1.0 (marume3591@icloud.com)"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        buildFilterOptions()
        setupFilterBar()
        setupTableView()
        setupEmptyLabel()
        setupScrollTopButton()
        setupSortMenu()

        applySort(sortOrder)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.bringSubviewToFront(scrollTopButton)
    }

    // MARK: - Filter Options

    private func buildFilterOptions() {
        var countries = Set<String>()
        var formats   = Set<String>()
        for item in results {
            if let c = item["country"] as? String, !c.isEmpty { countries.insert(c) }
            extractFormats(from: item).forEach { formats.insert($0) }
        }
        availableCountries = countries.sorted()
        availableFormats   = formats.sorted()
    }

    private func extractFormats(from item: [String: Any]) -> [String] {
        if let arr = item["format"] as? [Any] {
            return arr.compactMap { el -> String? in
                if let s = el as? String { return s }
                if let d = el as? [String: Any], let n = d["name"] as? String { return n }
                return nil
            }
        }
        if let s = item["format"] as? String { return [s] }
        return []
    }

    // MARK: - Setup UI

    private func setupFilterBar() {
        filterBar.backgroundColor = .secondarySystemBackground
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterBar)

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        filterBar.addSubview(separator)

        countryButton.setTitle("Country ▾", for: .normal)
        countryButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        countryButton.addTarget(self, action: #selector(showCountryFilter), for: .touchUpInside)

        formatButton.setTitle("Format ▾", for: .normal)
        formatButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        formatButton.addTarget(self, action: #selector(showFormatFilter), for: .touchUpInside)

        resetButton.setTitle("Reset", for: .normal)
        resetButton.setTitleColor(.systemRed, for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        resetButton.addTarget(self, action: #selector(resetFilters), for: .touchUpInside)

        countLabel.font = .systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabel
        countLabel.textAlignment = .center
        countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [countryButton, formatButton, countLabel, resetButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        filterBar.addSubview(stack)

        NSLayoutConstraint.activate([
            filterBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: 44),

            separator.leadingAnchor.constraint(equalTo: filterBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: filterBar.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: filterBar.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            stack.leadingAnchor.constraint(equalTo: filterBar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: filterBar.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: filterBar.centerYAnchor)
        ])
    }

    private func setupTableView() {
        footerSpinner.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 50)
        footerSpinner.hidesWhenStopped = true
        tableView.tableFooterView = footerSpinner

        tableView.register(OCRResultCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 100
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyLabel() {
        emptyLabel.text = "条件に一致するリリースがありません"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 15)
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupScrollTopButton() {
        view.addSubview(scrollTopButton)
        view.bringSubviewToFront(scrollTopButton)
        NSLayoutConstraint.activate([
            scrollTopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollTopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            scrollTopButton.widthAnchor.constraint(equalToConstant: 44),
            scrollTopButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        scrollTopButton.addTarget(self, action: #selector(scrollToTop), for: .touchUpInside)
    }

    @objc private func scrollToTop() {
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }

    private func updateScrollTopButtonVisibility(offsetY: CGFloat) {
        let shouldShow = offsetY > 200
        let currentlyVisible = scrollTopButton.alpha > 0.5
        if shouldShow && !currentlyVisible {
            scrollTopButton.alpha = 1
        } else if !shouldShow && currentlyVisible {
            scrollTopButton.alpha = 0
        }
    }

    // MARK: - Count Label

    private func updateCountLabel() {
        let total    = results.count
        let filtered = filteredResults.count
        let suffix   = totalPages > currentPage ? "+" : "件"
        if selectedCountry != nil || selectedFormat != nil {
            countLabel.text = "\(filtered) / \(total)\(suffix)"
        } else {
            countLabel.text = "\(total)\(suffix)"
        }
    }

    // MARK: - Filter Actions

    @objc private func showCountryFilter() {
        let alert = UIAlertController(title: "Country", message: nil, preferredStyle: .actionSheet)

        let allAction = UIAlertAction(title: "すべて", style: .default) { _ in
            self.selectedCountry = nil
            self.applyFilter()
        }
        if selectedCountry == nil { allAction.setValue(true, forKey: "checked") }
        alert.addAction(allAction)

        for country in availableCountries {
            let action = UIAlertAction(title: country, style: .default) { _ in
                self.selectedCountry = country
                self.applyFilter()
            }
            if selectedCountry == country { action.setValue(true, forKey: "checked") }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = countryButton
            popover.sourceRect = countryButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func showFormatFilter() {
        let alert = UIAlertController(title: "Format", message: nil, preferredStyle: .actionSheet)

        let allAction = UIAlertAction(title: "すべて", style: .default) { _ in
            self.selectedFormat = nil
            self.applyFilter()
        }
        if selectedFormat == nil { allAction.setValue(true, forKey: "checked") }
        alert.addAction(allAction)

        for fmt in availableFormats {
            let action = UIAlertAction(title: fmt, style: .default) { _ in
                self.selectedFormat = fmt
                self.applyFilter()
            }
            if selectedFormat == fmt { action.setValue(true, forKey: "checked") }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = formatButton
            popover.sourceRect = formatButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func resetFilters() {
        selectedCountry = nil
        selectedFormat  = nil
        countryButton.setTitle("Country ▾", for: .normal)
        formatButton.setTitle("Format ▾", for: .normal)
        // ソートも初期状態に戻す
        sortOrder = .searchOrder
        navigationItem.rightBarButtonItem?.title = sortButtonTitle()
        navigationItem.rightBarButtonItem?.menu  = buildSortMenu()
        applyFilter()
    }

    // MARK: - Filter

    private func applyFilter() {
        filteredResults = results.filter { item in
            if let country = selectedCountry {
                guard let c = item["country"] as? String, c == country else { return false }
            }
            if let format = selectedFormat {
                guard extractFormats(from: item).contains(format) else { return false }
            }
            return true
        }
        sortInPlace(&filteredResults, order: sortOrder)

        countryButton.setTitle(selectedCountry.map { "\($0) ✕" } ?? "Country ▾", for: .normal)
        formatButton.setTitle(selectedFormat.map  { "\($0) ✕" } ?? "Format ▾",   for: .normal)

        var countries = Set<String>()
        var formats   = Set<String>()
        for item in results {
            if let c = item["country"] as? String, !c.isEmpty { countries.insert(c) }
            extractFormats(from: item).forEach { formats.insert($0) }
        }
        availableCountries = countries.sorted()
        availableFormats   = formats.sorted()

        updateCountLabel()
        emptyLabel.isHidden = !filteredResults.isEmpty
        tableView.reloadData()
    }

    // MARK: - Sort

    private func setupSortMenu() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: sortButtonTitle(), image: nil, primaryAction: nil, menu: buildSortMenu())
    }

    private func sortButtonTitle() -> String {
        switch sortOrder {
        case .searchOrder: return "Sort"
        case .yearAsc:     return "Year ↑"
        case .yearDesc:    return "Year ↓"
        case .formatAsc:   return "Format A→Z"
        case .formatDesc:  return "Format Z→A"
        }
    }

    private func buildSortMenu() -> UIMenu {
        let items: [(String, SortOrder)] = [
            ("Search Order",        .searchOrder),
            ("Year (Oldest First)", .yearAsc),
            ("Year (Newest First)", .yearDesc),
            ("Format (A→Z)",        .formatAsc),
            ("Format (Z→A)",        .formatDesc)
        ]
        let actions = items.map { (title, order) in
            UIAction(title: title, state: self.sortOrder == order ? .on : .off) { _ in
                self.applySort(order)
            }
        }
        return UIMenu(title: "Sort", children: actions)
    }

    private func applySort(_ order: SortOrder) {
        sortOrder = order
        sortInPlace(&results, order: order)
        applyFilter()
        // ボタンタイトルとメニューを更新
        navigationItem.rightBarButtonItem?.title = sortButtonTitle()
        navigationItem.rightBarButtonItem?.menu  = buildSortMenu()
    }

    private func sortInPlace(_ array: inout [[String: Any]], order: SortOrder) {
        switch order {
        case .searchOrder: break
        case .yearAsc:    array.sort { (yearValue($0) ?? Int.max) < (yearValue($1) ?? Int.max) }
        case .yearDesc:   array.sort { (yearValue($0) ?? 0)       > (yearValue($1) ?? 0) }
        case .formatAsc:  array.sort { formatSortValue($0) < formatSortValue($1) }
        case .formatDesc: array.sort { formatSortValue($0) > formatSortValue($1) }
        }
    }

    // MARK: - Pagination

    func setInitialPagination(currentPage: Int, totalPages: Int) {
        self.currentPage = currentPage
        self.totalPages  = totalPages
    }

    private func loadNextPageIfNeeded() {
        guard !isFetching,
              currentPage < totalPages,
              let query = searchQuery else { return }

        isFetching = true
        footerSpinner.startAnimating()

        let nextPage = currentPage + 1

        let urlString: String
        switch query {
        case .text(let q):
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString = "https://api.discogs.com/database/search?q=\(encoded)&type=release&per_page=50&page=\(nextPage)&key=\(key)&secret=\(secret)"
        case .catno(let c):
            let encoded = c.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString = "https://api.discogs.com/database/search?catno=\(encoded)&type=release&per_page=50&page=\(nextPage)&key=\(key)&secret=\(secret)"
        }

        guard let url = URL(string: urlString) else { isFetching = false; return }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self,
                  let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                DispatchQueue.main.async { self?.stopFetching() }
                return
            }

            let newItems = json["results"] as? [[String: Any]] ?? []

            if let pagination = json["pagination"] as? [String: Any],
               let pages = pagination["pages"] as? Int {
                DispatchQueue.main.async { self.totalPages = pages }
            }

            DispatchQueue.main.async {
                self.currentPage = nextPage
                self.results.append(contentsOf: newItems)
                self.applyFilter()
                self.stopFetching()
            }
        }.resume()
    }

    private func stopFetching() {
        isFetching = false
        footerSpinner.stopAnimating()
        updateCountLabel()
    }

    // MARK: - Year Fetch

    private func fetchYearIfNeeded(at indexPath: IndexPath) {
        guard indexPath.row < filteredResults.count else { return }
        let item = filteredResults[indexPath.row]

        // year が有効な値（Int > 0 または空でない String）なら取得不要
        if let y = item["year"] as? Int, y > 0 { return }
        if let s = item["year"] as? String, !s.isEmpty { return }

        guard let id   = item["id"]   as? Int,
              let type = item["type"] as? String else { return }

        let base = type == "master"
            ? "https://api.discogs.com/masters/\(id)"
            : "https://api.discogs.com/releases/\(id)"
        guard let url = URL(string: "\(base)?key=\(key)&secret=\(secret)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }

            var yearString = ""
            if let y = json["year"] as? Int, y > 0 {
                yearString = "\(y)"
            } else if let r = json["released"] as? String, r.count >= 4 {
                let p = r.prefix(4)
                if p.allSatisfy({ $0.isNumber }) && p != "0000" { yearString = String(p) }
            }

            DispatchQueue.main.async {
                // results 本体を更新
                if let idx = self.results.firstIndex(where: { ($0["id"] as? Int) == id }) {
                    self.results[idx]["year"] = yearString.isEmpty ? "--" : yearString
                }
                // filteredResults を更新
                if indexPath.row < self.filteredResults.count,
                   (self.filteredResults[indexPath.row]["id"] as? Int) == id {
                    self.filteredResults[indexPath.row]["year"] = yearString.isEmpty ? "--" : yearString
                }
                // セルを再描画
                if let cell = self.tableView.cellForRow(at: indexPath) as? OCRResultCell {
                    cell.configure(with: self.filteredResults[indexPath.row])
                }
            }
        }.resume()
    }

    // MARK: - Helpers

    private func yearValue(_ item: [String: Any]) -> Int? {
        if let y = item["year"] as? Int,    y > 0    { return y }
        if let s = item["year"] as? String, let y = Int(s) { return y }
        if let r = item["released"] as? String, r.count >= 4 { return Int(r.prefix(4)) }
        return nil
    }

    private func formatSortValue(_ item: [String: Any]) -> String {
        extractFormats(from: item).joined(separator: ", ")
    }
}

// MARK: - UITableViewDataSource / Delegate

extension OCRResultViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        filteredResults.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "cell", for: indexPath) as! OCRResultCell
        cell.configure(with: filteredResults[indexPath.row])
        fetchYearIfNeeded(at: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        onSelect?(filteredResults[indexPath.row])
        navigationController?.popViewController(animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY       = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight   = scrollView.frame.size.height

        // トップボタンの表示切替
        updateScrollTopButtonVisibility(offsetY: offsetY)

        // 末尾で次ページ取得
        if offsetY > contentHeight - frameHeight - 100 {
            loadNextPageIfNeeded()
        }
    }
}
