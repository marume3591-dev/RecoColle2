import UIKit

final class OCRResultViewController: UITableViewController {

    // MARK: - Properties

    var results: [[String: Any]] = []           // Discogs検索結果（検索順）
    var onSelect: (([String: Any]) -> Void)?

    enum SortOrder {
        case searchOrder
        case yearAsc
        case yearDesc
        case formatAsc
        case formatDesc
    }

    private var sortOrder: SortOrder = .yearAsc  // searchOrder → yearAscに変更

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(OCRResultCell.self,
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = 100

        setupSortMenu()

        // 年は非同期で補完
//        for i in results.indices {
//            fetchYearIfNeeded(at: IndexPath(row: i, section: 0))
//        }
    }

    // MARK: - Sort Menu

    private func setupSortMenu() {
        let menu = UIMenu(title: "Sort", children: [
            UIAction(title: "Search Order", state: .on) { _ in
                self.applySort(.searchOrder)
            },
            UIAction(title: "Year (Oldest First)") { _ in
                self.applySort(.yearAsc)
            },
            UIAction(title: "Year (Newest First)") { _ in
                self.applySort(.yearDesc)
            },
            UIAction(title: "Format (A→Z)") { _ in  // ★ タイトル変更
                self.applySort(.formatAsc)
            },
            UIAction(title: "Format (Z→A)") { _ in  // ★ 追加
                self.applySort(.formatDesc)
            }
        ])

        navigationItem.rightBarButtonItem =
            UIBarButtonItem(title: "Sort",
                            image: nil,
                            primaryAction: nil,
                            menu: menu)
    }

    private func applySort(_ order: SortOrder) {
        sortOrder = order

        switch order {
        case .searchOrder:
            // 何もしない（Discogsの返却順）
            break

        case .yearAsc:
            results.sort {
                (yearValue($0) ?? Int.max) < (yearValue($1) ?? Int.max)
            }

        case .yearDesc:
            results.sort {
                (yearValue($0) ?? 0) > (yearValue($1) ?? 0)
            }
        
        case .formatAsc:
            results.sort {
                formatValue($0) < formatValue($1)
            }

        case .formatDesc:
                results.sort {
                    formatValue($0) > formatValue($1)
                }
        }
        

        tableView.reloadData()
    }

    private func yearValue(_ item: [String: Any]) -> Int? {
        if let year = item["year"] as? Int, year > 0 {
            return year
        }
        if let yearStr = item["year"] as? String,
           let year = Int(yearStr) {
            return year
        }
        if let released = item["released"] as? String,
           released.count >= 4 {
            let y = released.prefix(4)
            return Int(y)
        }
        return nil
    }
    
    private func formatValue(_ item: [String: Any]) -> String {
        if let formatArray = item["format"] as? [Any] {
            let formats = formatArray.compactMap { element -> String? in
                if let s = element as? String { return s }
                if let dict = element as? [String: Any],
                   let name = dict["name"] as? String { return name }
                return nil
            }
            return formats.joined(separator: ", ")
        }
        if let s = item["format"] as? String { return s }
        return ""
    }
    // MARK: - Year Fetch

    private func fetchYearIfNeeded(at indexPath: IndexPath) {
        guard indexPath.row < results.count else { return }
        guard results[indexPath.row]["year"] == nil else { return }

        let item = results[indexPath.row]

        guard
            let id = item["id"] as? Int,
            let type = item["type"] as? String
        else { return }

        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"

        let endpoint: String
        switch type {
        case "release":
            endpoint = "https://api.discogs.com/releases/\(id)"
        case "master":
            endpoint = "https://api.discogs.com/masters/\(id)"
        default:
            return
        }

        let urlString = "\(endpoint)?key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any]
            else { return }

            var yearString = ""

            if let year = json["year"] as? Int, year > 0 {
                yearString = "\(year)"
            } else if let released = json["released"] as? String,
                      released.count >= 4 {
                let prefix = released.prefix(4)
                if prefix.allSatisfy({ $0.isNumber }),
                   prefix != "0000" {
                    yearString = String(prefix)
                }
            }

            DispatchQueue.main.async {
                self.results[indexPath.row]["year"] = yearString

                if self.sortOrder != .searchOrder {
                    self.applySort(self.sortOrder)
                } else if let cell =
                            self.tableView.cellForRow(at: indexPath)
                            as? OCRResultCell {
                    cell.configure(with: self.results[indexPath.row])
                }
            }
        }.resume()
    }

    // MARK: - TableView

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "cell",
            for: indexPath
        ) as! OCRResultCell

        let item = results[indexPath.row]
        cell.configure(with: item)
        fetchYearIfNeeded(at: indexPath) 

        return cell
    }
    
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        onSelect?(results[indexPath.row])
        navigationController?.popViewController(animated: true)
    }
}
