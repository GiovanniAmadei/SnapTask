import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TaskFormViewModel()
    
    var body: some View {
        WatchTaskFormView(viewModel: viewModel, isPresented: .constant(true))
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
    }
}

#Preview {
    CreateTaskView()
} 