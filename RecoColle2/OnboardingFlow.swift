import SwiftUI

// MARK: - Models

enum AddMethod: CaseIterable {
    case barcode, jacket, discogs

    var iconName: String {
        switch self {
        case .barcode: return "barcode.viewfinder"
        case .jacket:  return "camera"
        case .discogs: return "magnifyingglass"
        }
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Main Onboarding Container

struct OnboardingFlowView: View {
    var onComplete: (() -> Void)? = nil
    @State private var currentStep: Int = 0
    @State private var selectedMethod: AddMethod = .barcode

    var body: some View {
        ZStack {
            switch currentStep {
            case 0:
                WelcomeScreen(onStart: { currentStep = 1 })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 1:
                MethodSelectScreen(
                    selectedMethod: $selectedMethod,
                    onBack: { currentStep = 0 },
                    onNext: { currentStep = 2 }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 2:
                ScanScreen(
                    onBack: { currentStep = 1 },
                    onComplete: { currentStep = 3 }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 3:
                ConfirmScreen(
                    onBack: { currentStep = 2 },
                    onSave: { onComplete?() }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut, value: current)
            }
        }
    }
}

// MARK: - Screen 1: Welcome

struct WelcomeScreen: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 48)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: 64, height: 64)
                SwiftUI.Image(systemName: "opticaldisc")
                    .font(Font.system(size: 30, weight: Font.Weight.light))
                    .foregroundColor(Color.primary)
            }
            .padding(.bottom, 28)

            Text(NSLocalizedString("onboarding_title", comment: ""))
                .font(Font.system(size: 28, weight: Font.Weight.medium))
                .lineSpacing(4)
                .padding(.bottom, 14)

            Text(NSLocalizedString("onboarding_message", comment: ""))
                .font(Font.system(size: 15))
                .foregroundColor(Color.secondary)
                .lineSpacing(5)

            Spacer()

            Button(action: onStart) {
                Text(NSLocalizedString("onboarding_start_button", comment: ""))
                    .font(Font.system(size: 16, weight: Font.Weight.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.primary)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .cornerRadius(14)
            }
            .padding(.bottom, 16)

            StepIndicator(total: 4, current: 0)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 600 : .infinity)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Screen 2: Add Item Mock

struct MethodSelectScreen: View {
    @Binding var selectedMethod: AddMethod
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 2) {
                            SwiftUI.Image(systemName: "chevron.left")
                                .font(Font.system(size: 16, weight: Font.Weight.medium))
                            Text(NSLocalizedString("back_button_title", comment: ""))
                                .font(Font.system(size: 17))
                        }
                        .foregroundColor(Color.blue)
                    }
                    Spacer()
                }
                Text(NSLocalizedString("add_item_nav_title", comment: ""))
                    .font(Font.system(size: 17, weight: Font.Weight.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemGroupedBackground))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 130, height: 130)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                )
                            SwiftUI.Image(systemName: "photo")
                                .font(Font.system(size: 44))
                                .foregroundColor(Color(UIColor.systemGray3))
                        }
                        Text(NSLocalizedString("tap_to_add_cover", comment: ""))
                            .font(Font.system(size: 13))
                            .foregroundColor(Color.secondary)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 0) {
                        FormLabel(NSLocalizedString("field_artist", comment: ""))
                        FormTextField()
                        FormLabel(NSLocalizedString("field_title", comment: ""))
                        FormTextField()
                        FormLabel(NSLocalizedString("field_format", comment: ""))
                        FormTextField()

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                FormLabel(NSLocalizedString("field_country", comment: ""))
                                FormTextField()
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                FormLabel(NSLocalizedString("field_year", comment: ""))
                                FormTextField()
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                FormLabel(NSLocalizedString("field_catno", comment: ""))
                                FormTextField()
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                FormLabel(NSLocalizedString("field_label", comment: ""))
                                FormTextField()
                            }
                        }

                        FormLabel(NSLocalizedString("field_memo", comment: ""))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.systemBackground))
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
                            )
                            .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)

                    VStack(spacing: 10) {
                        HStack(alignment: .bottom, spacing: 10) {
                            PulsingBarcodeButton(onTap: onNext)
                            AddActionButton(icon: "number", title: "Cat No", onTap: {})
                        }
                        HStack(spacing: 10) {
                            AddActionButton(icon: "doc.text.viewfinder", title: "Scan Title", onTap: {})
                            AddActionButton(icon: "music.note", title: "Shazam", onTap: {})
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    HStack(spacing: 0) {
                        Button(action: {}) {
                            Text("Collection")
                                .font(Font.system(size: 15, weight: Font.Weight.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(Color.white)
                        }
                        .clipShape(RoundedCornerShape(radius: 8, corners: [.topLeft, .bottomLeft]))

                        Button(action: {}) {
                            Text("Wants")
                                .font(Font.system(size: 15))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.systemGray5))
                                .foregroundColor(Color.secondary)
                        }
                        .clipShape(RoundedCornerShape(radius: 8, corners: [.topRight, .bottomRight]))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))

            StepIndicator(total: 4, current: 1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Pulsing Barcode Button

struct PulsingBarcodeButton: View {
    let onTap: () -> Void
    @State private var bouncing = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Text(NSLocalizedString("tap_here_to_register", comment: ""))
                    .font(Font.system(size: 12, weight: Font.Weight.medium))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
                Triangle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 6)
                    .offset(y: 6)
            }
            .padding(.bottom, 4)

            SwiftUI.Image(systemName: "hand.point.up.fill")
                .font(Font.system(size: 20))
                .foregroundColor(Color.blue)
                .rotationEffect(.degrees(180))
                .offset(y: bouncing ? -4 : 4)
                .animation(
                    Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: bouncing
                )
                .onAppear { bouncing = true }
                .padding(.bottom, 4)

            Button(action: onTap) {
                HStack(spacing: 6) {
                    SwiftUI.Image(systemName: "barcode.viewfinder")
                        .font(Font.system(size: 15))
                        .foregroundColor(Color.blue)
                    Text("Barcode")
                        .font(Font.system(size: 15))
                        .foregroundColor(Color.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1.5)
                )
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct FormLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(Font.system(size: 14))
            .foregroundColor(Color.primary)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

struct FormTextField: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(UIColor.systemBackground))
            .frame(height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
            )
    }
}

struct AddActionButton: View {
    let icon: String
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                SwiftUI.Image(systemName: icon)
                    .font(Font.system(size: 15))
                    .foregroundColor(Color.blue)
                Text(title)
                    .font(Font.system(size: 15))
                    .foregroundColor(Color.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Screen 3: Scan

struct ScanScreen: View {
    let onBack: () -> Void
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            RecordBackCoverView()
                .ignoresSafeArea()

            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Text(NSLocalizedString("cancel_scan", comment: ""))
                            .font(Font.system(size: 17))
                            .foregroundColor(Color.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Spacer()

                Button(action: onComplete) {
                    Text(NSLocalizedString("scan_button_title", comment: ""))
                        .font(Font.system(size: 17, weight: Font.Weight.medium))
                        .foregroundColor(Color.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Record Back Cover View

struct RecordBackCoverView: View {
    var body: some View {
        ZStack {
            Color(red: 0.92, green: 0.90, blue: 0.86)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.35))
                        .frame(width: 80, height: 80)
                        .overlay(
                            VStack(spacing: 2) {
                                Circle()
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.25))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .fill(Color(red: 0.25, green: 0.25, blue: 0.4))
                                            .frame(width: 12, height: 12)
                                    )
                            }
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MILES DAVIS")
                            .font(Font.system(size: 13, weight: Font.Weight.bold))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                        Text("Kind of Blue")
                            .font(Font.system(size: 11))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                        Text("Columbia Records")
                            .font(Font.system(size: 10))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                            .padding(.top, 2)
                        Text("CS 8163")
                            .font(Font.system(size: 10))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("SIDE 1")
                        .font(Font.system(size: 9, weight: Font.Weight.bold))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .padding(.bottom, 2)
                    TrackRow(number: "1", title: "So What", duration: "9:22")
                    TrackRow(number: "2", title: "Freddie Freeloader", duration: "9:46")
                    TrackRow(number: "3", title: "Blue in Green", duration: "5:37")
                    Text("SIDE 2")
                        .font(Font.system(size: 9, weight: Font.Weight.bold))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                    TrackRow(number: "1", title: "All Blues", duration: "11:33")
                    TrackRow(number: "2", title: "Flamenco Sketches", duration: "9:26")
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    BarcodeView()
                        .frame(width: 140, height: 80)
                    Text("4 988002 123456")
                        .font(Font.system(size: 9))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                }
                .frame(maxWidth: .infinity)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("© 1959 Columbia Records")
                        .font(Font.system(size: 8))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                    Text("Manufactured in U.S.A.")
                        .font(Font.system(size: 8))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
}

struct TrackRow: View {
    let number: String
    let title: String
    let duration: String

    var body: some View {
        HStack {
            Text(number + ".")
                .font(Font.system(size: 10))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                .frame(width: 16, alignment: .leading)
            Text(title)
                .font(Font.system(size: 10))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            Spacer()
            Text(duration)
                .font(Font.system(size: 10))
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
        }
    }
}

struct BarcodeView: View {
    let pattern: [CGFloat] = [2,1,3,1,2,2,1,3,2,1,2,1,3,2,1,2,3,1,2,1,2,3,1,2,1,3,2,1,2,2,1,3,1,2]

    var body: some View {
        GeometryReader { geo in
            let totalUnits = pattern.reduce(0, +) * 1.8
            let unitWidth = geo.size.width / totalUnits
            HStack(spacing: 0) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { index, w in
                    Rectangle()
                        .fill(index % 2 == 0 ? Color.black : Color.clear)
                        .frame(width: w * unitWidth, height: geo.size.height)
                }
            }
            .background(Color.white)
        }
    }
}

// MARK: - Screen 4: Confirm

struct ConfirmScreen: View {
    let onBack: () -> Void
    let onSave: () -> Void
    @State private var bouncingSave = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 2) {
                            SwiftUI.Image(systemName: "chevron.left")
                                .font(Font.system(size: 16, weight: Font.Weight.medium))
                            Text(NSLocalizedString("back_button_title", comment: ""))
                                .font(Font.system(size: 17))
                        }
                        .foregroundColor(Color.blue)
                    }
                    Spacer()
                }
                Text(NSLocalizedString("add_item_nav_title", comment: ""))
                    .font(Font.system(size: 17, weight: Font.Weight.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemGroupedBackground))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.2, blue: 0.35),
                                             Color(red: 0.1, green: 0.22, blue: 0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 130, height: 130)
                            .overlay(
                                SwiftUI.Image(systemName: "music.note")
                                    .font(Font.system(size: 44, weight: Font.Weight.light))
                                    .foregroundColor(Color.white.opacity(0.7))
                            )
                            .cornerRadius(8)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 0) {
                        FormLabel(NSLocalizedString("field_artist", comment: ""))
                        FilledFormTextField(text: "Miles Davis")
                        FormLabel(NSLocalizedString("field_title", comment: ""))
                        FilledFormTextField(text: "Kind of Blue")
                        FormLabel(NSLocalizedString("field_format", comment: ""))
                        FilledFormTextField(text: "LP, Vinyl")

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                FormLabel(NSLocalizedString("field_country", comment: ""))
                                FilledFormTextField(text: "US")
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                FormLabel(NSLocalizedString("field_year", comment: ""))
                                FilledFormTextField(text: "1959")
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                FormLabel(NSLocalizedString("field_catno", comment: ""))
                                FilledFormTextField(text: "CS 8163")
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                FormLabel(NSLocalizedString("field_label", comment: ""))
                                FilledFormTextField(text: "Columbia")
                            }
                        }

                        FormLabel(NSLocalizedString("field_memo", comment: ""))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.systemBackground))
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
                            )
                            .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 0) {
                        Button(action: {}) {
                            Text("Collection")
                                .font(Font.system(size: 15, weight: Font.Weight.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(Color.white)
                        }
                        .clipShape(RoundedCornerShape(radius: 8, corners: [.topLeft, .bottomLeft]))

                        Button(action: {}) {
                            Text("Wants")
                                .font(Font.system(size: 15))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.systemGray5))
                                .foregroundColor(Color.secondary)
                        }
                        .clipShape(RoundedCornerShape(radius: 8, corners: [.topRight, .bottomRight]))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    // 保存ボタン＋ガイド
                    VStack(spacing: 0) {
                        ZStack(alignment: .bottom) {
                            Text(NSLocalizedString("tap_here_to_register", comment: ""))
                                .font(Font.system(size: 12, weight: Font.Weight.medium))
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                            Triangle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 6)
                                .offset(y: 6)
                        }
                        .padding(.bottom, 4)

                        SwiftUI.Image(systemName: "hand.point.up.fill")
                            .font(Font.system(size: 20))
                            .foregroundColor(Color.blue)
                            .rotationEffect(.degrees(180))
                            .offset(y: bouncingSave ? -4 : 4)
                            .animation(
                                Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                value: bouncingSave
                            )
                            .onAppear { bouncingSave = true }
                            .padding(.bottom, 4)

                        Button(action: onSave) {
                            Text(NSLocalizedString("save_button", comment: ""))
                                .font(Font.system(size: 17, weight: Font.Weight.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.blue)
                                .foregroundColor(Color.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))

            StepIndicator(total: 4, current: 3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
        }
        .background(Color(UIColor.systemGroupedBackground))
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 700 : .infinity)
        .frame(maxWidth: .infinity)
    }
}

struct FilledFormTextField: View {
    let text: String
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemBackground))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
                )
            Text(text)
                .font(Font.system(size: 15))
                .foregroundColor(Color.primary)
                .padding(.leading, 10)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowView()
}
