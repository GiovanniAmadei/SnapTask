import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPresented = true
    
    var body: some View {
        WatchTaskFormView(task: nil, initialDate: Date(), isPresented: $isPresented)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if !newValue {
                    dismiss()
                }
            }
    }
}

#Preview {
    CreateTaskView()
}
