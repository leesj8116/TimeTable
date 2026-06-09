import SwiftUI

struct WaitingMemoView: View {
    @AppStorage("waitingMemo") private var memo: String = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $memo)
                .padding(12)
                .navigationTitle("대기")
        }
    }
}

#Preview {
    WaitingMemoView()
}
