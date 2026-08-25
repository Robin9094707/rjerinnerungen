import SwiftUI

struct DurationPicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            wheel(title: "Std.", selection: $hours, range: 0..<24)
            wheel(title: "Min.", selection: $minutes, range: 0..<60)
            wheel(title: "Sek.", selection: $seconds, range: 0..<60)
        }
        .frame(height: 170)
    }

    private func wheel(
        title: String,
        selection: Binding<Int>,
        range: Range<Int>
    ) -> some View {
        VStack(spacing: 0) {
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value)")
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
