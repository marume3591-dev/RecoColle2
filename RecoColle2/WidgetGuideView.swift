import SwiftUI

struct WidgetGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // ヘッダー
                    VStack(spacing: 8) {
                        SwiftUI.Image(systemName: "rectangle.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("widget_guide_title", comment: ""))
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(NSLocalizedString("widget_guide_subtitle", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    
                    // ステップ
                    VStack(spacing: 16) {
                        GuideStep(
                            number: 1,
                            title: NSLocalizedString("widget_step1_title", comment: ""),
                            description: NSLocalizedString("widget_step1_description", comment: ""),
                            icon: "hand.tap"
                        )
                        GuideStep(
                            number: 2,
                            title: NSLocalizedString("widget_step2_title", comment: ""),
                            description: NSLocalizedString("widget_step2_description", comment: ""),
                            icon: "plus.circle"
                        )
                        GuideStep(
                            number: 3,
                            title: NSLocalizedString("widget_step3_title", comment: ""),
                            description: NSLocalizedString("widget_step3_description", comment: ""),
                            icon: "magnifyingglass"
                        )
                        GuideStep(
                            number: 4,
                            title: NSLocalizedString("widget_step4_title", comment: ""),
                            description: NSLocalizedString("widget_step4_description", comment: ""),
                            icon: "checkmark.circle"
                        )
                    }
                    
                    // 補足
                    Text(NSLocalizedString("widget_guide_note", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle(NSLocalizedString("widget_guide_button", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("close_button", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ステップカード
struct GuideStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 36, height: 36)
                Text("\(number)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    SwiftUI.Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
