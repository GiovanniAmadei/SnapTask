import Foundation

extension Recurrence {
    func isActiveOn(date: Date) -> Bool {
        // Primero verificamos si la fecha está dentro del rango de la recurrencia
        if let endDate = self.endDate {
            if date > endDate {
                return false
            }
        }
        
        let calendar = Calendar.current
        
        // Verificamos si la fecha es posterior a la fecha de inicio
        if date < calendar.startOfDay(for: self.startDate) {
            return false
        }
        
        switch self.type {
        case .daily:
            return true
            
        case .weekly(let days):
            let weekday = calendar.component(.weekday, from: date)
            return days.contains(weekday)
            
        case .monthly(let days):
            let day = calendar.component(.day, from: date)
            return days.contains(day)
        }
    }
} 