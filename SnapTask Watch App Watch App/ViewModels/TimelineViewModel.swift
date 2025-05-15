import Foundation
import SwiftUI

class TimelineViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var selectedDayOffset: Int = 0
    
    // Proprietà calcolata per la stringa del mese e anno
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    // Proprietà calcolata per il giorno della settimana
    var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }
    
    // Funzione per selezionare una data specifica
    func selectDate(_ offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) {
            selectedDate = newDate
            selectedDayOffset = offset
        }
    }
    
    // Funzione per selezionare una data specifica
    func selectSpecificDate(_ date: Date) {
        selectedDate = date
        if let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day {
            selectedDayOffset = days
        }
    }
    
    // Funzione per ottenere i task per la data selezionata
    func tasksForSelectedDate() -> [TodoTask] {
        let taskManager = TaskManager.shared
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        
        return taskManager.tasks.filter { task in
            let taskDate = Calendar.current.startOfDay(for: task.startTime)
            
            // Include i task del giorno selezionato
            if taskDate == startOfDay {
                return true
            }
            
            // Include i task ricorrenti attivi nella data selezionata
            if let recurrence = task.recurrence, recurrence.isActiveOn(date: selectedDate) {
                return true
            }
            
            return false
        }
        .sorted { $0.startTime < $1.startTime }
    }
} 