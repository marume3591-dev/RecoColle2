import AppIntents
import SwiftUI
import WidgetKit

struct RecoColleWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.marume3591.RecoColle2.RecoColleWidgetControl",
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "RecoColle2",
                isOn: value,
                action: OpenAppIntent()
            ) { _ in
                Label("RecoColle2", systemImage: "record.circle")
            }
        }
        .displayName("RecoColle2")
        .description("RecoColle2を開く")
    }
}

extension RecoColleWidgetControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { false }
    }
}

struct OpenAppIntent: SetValueIntent {
    static let title: LocalizedStringResource = "RecoColle2を開く"
    @Parameter(title: "value")
    var value: Bool
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
