import SwiftUI

struct SettingsButtonsView: View {

    weak var controller: SettingsTableViewController?

    private var versionText: String {
        "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")"
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 24) {

                // Version
                Text(versionText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // About
                settingsButton(
                    title: LocalizedStringKey("about_button"),
                    description: LocalizedStringKey("about_description"),
                    icon: "info.circle",
                    color: .secondary
                ) {
                    guard let controller = controller else { return }
                    let aboutVC = AboutViewController()
                    aboutVC.modalPresentationStyle = .formSheet
                    controller.present(aboutVC, animated: true)
                }

                // STORE
                sectionTitle(LocalizedStringKey("store_section"))

                settingsButton(
                    title: LocalizedStringKey("iap_button"),
                    description: LocalizedStringKey("iap_description"),
                    icon: "cart.fill",
                    color: .orange
                ) {
                    controller?.item(UIButton())
                }

                settingsButton(
                    title: LocalizedStringKey("review_button"),
                    description: LocalizedStringKey("review_description"),
                    icon: "star.fill",
                    color: .yellow
                ) {
                    if let url = URL(string: "https://apps.apple.com/app/id6474089598?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                }
                // WIDGET
                sectionTitle(LocalizedStringKey("widget_section"))

                settingsButton(
                    title: LocalizedStringKey("widget_guide_button"),
                    description: LocalizedStringKey("widget_guide_description"),
                    icon: "rectangle.stack",
                    color: .blue
                ) {
                    guard let controller = controller else { return }
                    let vc = UIHostingController(rootView: WidgetGuideView())
                    vc.modalPresentationStyle = .formSheet
                    controller.present(vc, animated: true)
                }
                
                // DATA
                sectionTitle(LocalizedStringKey("data_section"))

                settingsButton(
                    title: LocalizedStringKey("export_data_button"),
                    description: LocalizedStringKey("export_data_description"),
                    icon: "square.and.arrow.up",
                    color: .blue
                ) {
                    controller?.dataExport(UIButton())
                }

                settingsButton(
                    title: LocalizedStringKey("import_data_button"),
                    description: LocalizedStringKey("import_data_description"),
                    icon: "square.and.arrow.down",
                    color: .green
                ) {
                    controller?.dataImport(UIButton())
                }

                settingsButton(
                    title: LocalizedStringKey("delete_all_button"),
                    description: LocalizedStringKey("delete_all_description"),
                    icon: "trash",
                    color: .red
                ) {
                    controller?.dataDelete(UIButton())
                }

                Spacer(minLength: 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Section Title

    func sectionTitle(_ text: LocalizedStringKey) -> some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: Settings Button

    func settingsButton(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            HStack(spacing: 16) {
                SwiftUI.Image(systemName: icon)
                    .font(Font.title3)
                    .foregroundColor(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
