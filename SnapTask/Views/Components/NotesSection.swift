import SwiftUI

struct TaskNotesSection: View {
    @Binding var notes: String
    @State private var isEditing = false
    @State private var tempNotes = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !isEditing && !notes.isEmpty {
                    Button("Edit") {
                        startEditing()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if isEditing {
                VStack(spacing: 12) {
                    TextEditor(text: $tempNotes)
                        .font(.body)
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden) // Rimuove il background bianco
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .frame(minHeight: 80, maxHeight: 120)
                    
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                        )
                        
                        Spacer()
                        
                        Button("Save") {
                            saveNotes()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                    }
                }
            } else {
                if notes.isEmpty {
                    Button(action: {
                        startEditing()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            
                            Text("Add your thoughts about this completion...")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Spacer()
                            
                            Button("Clear") {
                                clearNotes()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }
    
    private func startEditing() {
        tempNotes = notes
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
    }
    
    private func cancelEditing() {
        tempNotes = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
    }
    
    private func saveNotes() {
        notes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
    }
    
    private func clearNotes() {
        notes = ""
    }
}

#Preview {
    VStack(spacing: 20) {
        TaskNotesSection(notes: .constant(""))
        TaskNotesSection(notes: .constant("This task was more challenging than expected. Need to allocate more time next time."))
    }
    .padding()
}
