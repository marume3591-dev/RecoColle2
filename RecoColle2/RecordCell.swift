import UIKit

final class RecordCell: UITableViewCell {
    
    static let identifier = "RecordCell"
    
    // MARK: - UI
    
    private let cardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.backgroundColor = UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 0.16, alpha: 1)  // 少し明るめ
            } else {
                return .secondarySystemGroupedBackground
            }
        }
        view.layer.cornerRadius = 16
        
        // 影（ダークモードでもちゃんと浮く）
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowRadius = 10
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        view.layer.borderWidth = 0.8
        view.layer.borderColor = UIColor.separator.cgColor
        
        return view
    }()
    
    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 0
        iv.backgroundColor = .secondarySystemBackground
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    
    private let artistLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 1
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)  // 15 → 13に変更
        label.textColor = .systemGreen  // 色をつけると見やすい
        label.numberOfLines = 1
        return label
    }()
    
    private let releaseYearLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // セル自体は透明
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(cardView)
        
        let verticalStack = UIStackView(arrangedSubviews: [
            titleLabel,
            artistLabel,
            infoLabel,
            releaseYearLabel,
            priceLabel
        ])
        verticalStack.axis = .vertical
        verticalStack.spacing = 4
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        
        let horizontalStack = UIStackView(arrangedSubviews: [
            coverImageView,
            verticalStack
        ])
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 12
        horizontalStack.alignment = .top
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        
        cardView.addSubview(horizontalStack)
        
        NSLayoutConstraint.activate([
            
            // カードの余白（ここが大事）
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // カード内の余白
            horizontalStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            horizontalStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            horizontalStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            horizontalStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            
            coverImageView.widthAnchor.constraint(equalToConstant: 90),
            coverImageView.heightAnchor.constraint(equalToConstant: 90)
        ])
        // 長押しヒントアイコンを追加
        let moreIcon = UIImageView(image: UIImage(systemName: "ellipsis.circle"))
        moreIcon.tintColor = .secondaryLabel
        moreIcon.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(moreIcon)
        NSLayoutConstraint.activate([
            moreIcon.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            moreIcon.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
            moreIcon.widthAnchor.constraint(equalToConstant: 16),
            moreIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Configure
    
    func configure(
        title: String,
        artist: String,
        info: String,
        releaseYear: String?,
        price: String?,
        image: UIImage?,
        isNoImage: Bool = false
    ) {
        if let price = price {
            priceLabel.text = price
        } else {
            priceLabel.text = " "  // 空白で高さを確保
        }
        priceLabel.isHidden = false
        
        titleLabel.text = title
        artistLabel.text = artist
        infoLabel.text = info
        
        if let year = releaseYear, !year.isEmpty {
            releaseYearLabel.text = year
            releaseYearLabel.isHidden = false
        } else {
            releaseYearLabel.isHidden = true
        }
        
        if let price = price {
            priceLabel.text = price
            priceLabel.isHidden = false
        } else {
            priceLabel.isHidden = true
        }
        
        coverImageView.image = image
        coverImageView.contentMode = isNoImage ? .scaleToFill : .scaleAspectFill  // ← AspectFit → scaleToFill に変更

    }
    
    func updatePrice(_ price: String?) {
        DispatchQueue.main.async {
            self.priceLabel.text = price ?? " "  // nilなら空白
            self.priceLabel.isHidden = false
        }
    }
}
