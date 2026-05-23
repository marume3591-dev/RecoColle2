import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // iOS 18以降iPadでタブバーが上部に移動するのを防ぐ
        if #available(iOS 18.0, *) {
            traitOverrides.horizontalSizeClass = .compact
        }

        let discogsAction = UIAction(
            title: "Open Discogs",
            image: UIImage(systemName: "safari")
        ) { _ in
            if let url = URL(string: "https://www.discogs.com") {
                UIApplication.shared.open(url)
            }
        }

        let menu = UIMenu(title: "", children: [discogsAction])

        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            primaryAction: nil,
            menu: menu
        )

        navigationItem.leftBarButtonItem = menuButton
        
        
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            
            appearance.backgroundColor = .systemBackground
            
            appearance.stackedLayoutAppearance.selected.iconColor = .systemBlue
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.systemBlue
            ]
            
            appearance.stackedLayoutAppearance.normal.iconColor = .secondaryLabel
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.secondaryLabel
            ]
            
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
        
    }
}
