import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var isSending: Bool = false
    @State private var didSend: Bool = false
    @EnvironmentObject var loc: LocalizationManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text(loc.localized("feedback_improve_header"))) {
                        TextEditor(text: $message)
                            .frame(height: 150)
                        TextField(loc.localized("feedback_email_placeholder"), text: $email)
                            .keyboardType(.emailAddress)
                    }
                    
                    Section {
                        Button(action: sendFeedback) {
                            HStack {
                                Spacer()
                                if isSending {
                                    ProgressView()
                                } else {
                                    Text(loc.localized("feedback_send_button"))
                                        .fontWeight(.bold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(message.isEmpty || isSending || didSend)
                    }
                }
                .navigationTitle(loc.localized("feedback_view_title"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(loc.localized("btn_close")) { dismiss() }
                    }
                }
                
                if didSend {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                                .background(Circle().fill(Color.white).padding(2))
                            Text(loc.localized("feedback_sent"))
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    .transition(.opacity.animation(.easeInOut))
                }
            }
        }
    }
    
    private func sendFeedback() {
        isSending = true
        FeedbackManager.shared.sendFeedback(message: message, email: email) { success in
            isSending = false
            if success {
                didSend = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
}
