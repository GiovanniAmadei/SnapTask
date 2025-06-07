import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var showingContent = false
    
    private let steps = [
        WelcomeStep(
            icon: "heart.fill",
            title: "Benvenuto in SnapTask Pro Alpha!",
            subtitle: "Un messaggio personale da Giovanni Amadei",
            description: "Ciao! Sono Giovanni, uno sviluppatore indipendente. Ho creato SnapTask perché avevo bisogno di un'app per la produttività che funzionasse davvero, senza compromessi. Grazie di cuore per aver accettato di testare la versione alpha - il tuo feedback sarà preziosissimo per rendere SnapTask ancora migliore.",
            color: .pink
        ),
        WelcomeStep(
            icon: "sparkles",
            title: "Cosa troverai",
            subtitle: "Funzionalità all'avanguardia",
            description: "Timer Pomodoro avanzato, statistiche dettagliate, sincronizzazione CloudKit, widgets per la home screen, e molto altro. Ogni dettaglio è stato curato per offrirti la migliore esperienza di produttività possibile.",
            color: .blue
        ),
        WelcomeStep(
            icon: "bubble.left.and.bubble.right",
            title: "Il tuo parere conta davvero",
            subtitle: "Un progetto guidato dagli utenti",
            description: "Questa è una versione alpha, quindi potresti incontrare alcuni bug. Ti prego di segnalarmeli tramite la sezione Feedback nelle Impostazioni. SnapTask è un progetto a lungo termine che evolve in base al feedback degli utenti - ogni tuo suggerimento mi aiuterà a creare l'app per la produttività perfetta.",
            color: .orange
        ),
        WelcomeStep(
            icon: "gift.fill",
            title: "Completamente gratuita",
            subtitle: "Il tuo supporto fa la differenza",
            description: "SnapTask è e rimarrà sempre gratuita. Se ti piace quello che sto costruendo e vuoi aiutarmi a portare avanti questo progetto, considera di supportarlo. Il tuo contributo mi permetterà di dedicare più tempo a migliorare l'app e aggiungere nuove funzionalità.",
            color: .purple
        ),
        WelcomeStep(
            icon: "rocket.fill",
            title: "Iniziamo insieme!",
            subtitle: "Pronto per essere più produttivo?",
            description: "Grazie ancora per essere parte di questo viaggio. Come sviluppatore solo, il tuo supporto significa tutto per me. Spero che SnapTask Pro diventi il tuo compagno ideale per organizzare la giornata e raggiungere i tuoi obiettivi.",
            color: .green
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.1),
                    Color.pink.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= currentStep ? steps[currentStep].color : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Main content
                if showingContent {
                    VStack(spacing: 32) {
                        // Icon
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(steps[currentStep].color)
                            .transition(.opacity)
                        
                        // Text content
                        VStack(spacing: 16) {
                            Text(steps[currentStep].title)
                                .font(.title.bold())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text(steps[currentStep].subtitle)
                                .font(.title3.weight(.medium))
                                .foregroundColor(steps[currentStep].color)
                                .multilineTextAlignment(.center)
                            
                            Text(steps[currentStep].description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                    }
                    .id(currentStep)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if currentStep < steps.count - 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } label: {
                            HStack {
                                Text("Continua")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "arrow.right")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [steps[currentStep].color, steps[currentStep].color.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                    } else {
                        Button {
                            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
                            dismiss()
                        } label: {
                            HStack {
                                Text("Inizia a usare SnapTask")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "checkmark")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                    }
                    
                    Group {
                        if currentStep > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep -= 1
                                }
                            } label: {
                                Text("Indietro")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Spazio vuoto per mantenere l'altezza costante
                            Text("")
                                .font(.body.weight(.medium))
                                .opacity(0)
                        }
                    }
                    
                    // Skip button
                    if currentStep < steps.count - 1 {
                        Button {
                            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
                            dismiss()
                        } label: {
                            Text("Salta introduzione")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
                showingContent = true
            }
        }
    }
}

struct WelcomeStep {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
}

#Preview {
    WelcomeView()
}
