import UIKit

final class OCRResultCell: UITableViewCell {

    // MARK: - UI Elements

    private let albumImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 4
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 14)
        label.numberOfLines = 1
        return label
    }()
    private let labelLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemPurple  // 色はお好みで
        label.numberOfLines = 1
        return label
    }()
    private let catnoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .darkGray
        label.numberOfLines = 1
        return label
    }()

    private let countryYearLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        label.numberOfLines = 1
        return label
    }()

    private let formatLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .blue
        label.numberOfLines = 1
        return label
    }()

    // MARK: - Initializer

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup UI

    private func setupUI() {
        contentView.addSubview(albumImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(labelLabel)      // ← 追加
        contentView.addSubview(catnoLabel)
        contentView.addSubview(countryYearLabel)
        contentView.addSubview(formatLabel)

        albumImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        labelLabel.translatesAutoresizingMaskIntoConstraints = false  // ← 追加
        catnoLabel.translatesAutoresizingMaskIntoConstraints = false
        countryYearLabel.translatesAutoresizingMaskIntoConstraints = false
        formatLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            albumImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            albumImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            albumImageView.widthAnchor.constraint(equalToConstant: 60),
            albumImageView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            // ↓ labelLabel を titleLabel の下に                          ← 追加ブロック
            labelLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            labelLabel.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 8),
            labelLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            // catnoLabel の基準を labelLabel に変更
            catnoLabel.topAnchor.constraint(equalTo: labelLabel.bottomAnchor, constant: 2),  // ← 変更
            catnoLabel.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 8),
            catnoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            countryYearLabel.topAnchor.constraint(equalTo: catnoLabel.bottomAnchor, constant: 2),
            countryYearLabel.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 8),
            countryYearLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            formatLabel.topAnchor.constraint(equalTo: countryYearLabel.bottomAnchor, constant: 2),
            formatLabel.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 8),
            formatLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            formatLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Configure

    func configure(with item: [String: Any]) {

        titleLabel.text = item["title"] as? String ?? "Unknown"

        if let catno = item["catno"] as? String, !catno.isEmpty {
            catnoLabel.text = catno
            catnoLabel.isHidden = false
        } else {
            catnoLabel.text = nil
            catnoLabel.isHidden = true
        }
        
        if let labelArray = item["label"] as? [String] {
            labelLabel.text = labelArray.first
        } else if let labelStr = item["label"] as? String {
            labelLabel.text = labelStr
        } else {
            labelLabel.text = nil
        }
        
        let country = item["country"] as? String ?? ""
        var yearStr = ""

        if let year = item["year"] as? Int, year > 0 {
            yearStr = "\(year)"
        } else if let yearStrFromAPI = item["year"] as? String, !yearStrFromAPI.isEmpty {
            yearStr = yearStrFromAPI
        } else if let released = item["released"] as? String, released.count >= 4 {
            let prefix = released.prefix(4)
            if prefix.allSatisfy({ $0.isNumber }) && prefix != "0000" {
                yearStr = String(prefix)
            }
        }

        countryYearLabel.text = "\(country) \(yearStr)"
            .trimmingCharacters(in: .whitespaces)

        var formatText = ""
        if let formatArray = item["format"] as? [Any] {
            let formats = formatArray.compactMap { element -> String? in
                if let s = element as? String {
                    return s
                } else if let dict = element as? [String: Any],
                          let name = dict["name"] as? String {
                    return name
                }
                return nil
            }
            formatText = formats.joined(separator: ", ")
        } else if let s = item["format"] as? String {
            formatText = s
        }
        formatLabel.text = formatText

        if let coverURLString = item["cover_image"] as? String,
           let url = URL(string: coverURLString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data,
                      let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.albumImageView.image = image
                }
            }.resume()
        } else {
            albumImageView.image = nil
        }
    }
}
