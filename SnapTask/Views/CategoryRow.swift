import SwiftUI

struct CategoryRow: View {
    let category: Category
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 20, height: 20)
            Text(category.name)
        }
    }
} 