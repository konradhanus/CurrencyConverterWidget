# Feedback System Design & Implementation Guide

## 1. Executive Summary (Head of Design)

**Objective:** maximize App Store ratings (5 stars) while intercepting negative feedback before it reaches the public store.

**The "Sweet Spot":**
The perfect moment to ask for feedback is **immediately after a "Win" state**. In our currency converter, this is when the user successfully **saves an expense** (`saveExpense`). They have completed their task, the app worked, and they feel productive.

**The Flow:**
1.  **Intercept:** Ask "Enjoying [App Name]?"
2.  **Filter:**
    *   **YES** -> Redirect to App Store Review Controller (Native).
    *   **NO** -> Open internal "Feedback Form" (Safe space for complaints).
3.  **Resolution:** Send negative feedback silently to our server (`feedback.php`), making the user feel heard without damaging our public score.

---

## 2. Architecture & UX Flow

### ASCII Wireframes

**Step 1: The Intercept (Modal Alert)**
Triggered after user saves an expense (e.g., every 5th save).

```text
+---------------------------------------+
|           Enjoying the app?           |
|                                       |
|    We'd love to know how it's going!  |
|                                       |
|   [  Not Really  ]    [  Yes, I am! ] |
+---------------------------------------+
       |                      |
       | (User taps "Not Really")
       v
+---------------------------------------+
|           How can we improve?         |
|                                       |
|  [ Text Area for typing feedback... ] |
|  [ ................................ ] |
|  [ ................................ ] |
|                                       |
|          [   Send Feedback   ]        |
+---------------------------------------+
       |
       | (Sends POST request to server)
       v
   (Thank you popup & Close)
```

**Step 2: The Happy Path (Native Store Review)**
Triggered if user taps "Yes, I am!"

```text
(System Native Prompt)
+---------------------------------------+
|      Rate "Currency Widget"           |
|                                       |
|       * * * * *                       |
|   Tap a star to rate on the           |
|         App Store                     |
|                                       |
|      [ Cancel ]   [ Submit ]          |
+---------------------------------------+
```

---

## 3. Technical Implementation Plan

We will create a `FeedbackManager` singleton to handle the logic, counting, and networking.

### A. FeedbackManager.swift
*   **Responsibility:** Tracks how many times user saved expenses. Decides when to show the prompt. Handles API calls.
*   **Endpoint:** `https://reactblog.pl/feedback.php`
*   **Logic:**
    *   Increment counter on `saveExpense()`.
    *   If counter % 5 == 0 (example), show Intercept Alert.

### B. FeedbackView.swift (The "Safe Space")
*   **UI:** Clean, minimal sheet with a text editor.
*   **UX:** Auto-focus keyboard, clear "Send" button that shows a loading state.

### C. Integration in ContentView.swift
*   Hook into the `saveExpense` function in `CalculatorView`.

---

## 4. Code Specifications

### 1. `FeedbackManager.swift`

```swift
import SwiftUI
import StoreKit

class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    @Published var showFeedbackPrompt: Bool = false
    @Published var showNegativeFeedbackSheet: Bool = false
    
    private let interactionCountKey = "userInteractionCount"
    private let feedbackEndpoint = "https://reactblog.pl/feedback.php"
    
    // Config: How often to ask? (e.g., every 5th valid action)
    private let interactionsBeforePrompt = 5
    
    func logSignificantEvent() {
        let current = UserDefaults.standard.integer(forKey: interactionCountKey)
        let newCount = current + 1
        UserDefaults.standard.set(newCount, forKey: interactionCountKey)
        
        // Check if it's time to ask
        if newCount > 0 && newCount % interactionsBeforePrompt == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showFeedbackPrompt = true
            }
        }
    }
    
    func userIsHappy() {
        // Direct to App Store Review
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    func userIsUnhappy() {
        // Open internal feedback form
        showNegativeFeedbackSheet = true
    }
    
    func sendFeedback(message: String, email: String = "Anonymous", completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: feedbackEndpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "message": message,
            "email": email,
            "uid": UIDevice.current.identifierForVendor?.uuidString ?? "Unknown",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}
```

### 2. `FeedbackView.swift`

```swift
import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var isSending: Bool = false
    @State private var didSend: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("How can we improve?")) {
                    TextEditor(text: $message)
                        .frame(height: 150)
                    TextField("Your Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                }
                
                Section {
                    Button(action: sendFeedback) {
                        HStack {
                            Spacer()
                            if isSending {
                                ProgressView()
                            } else if didSend {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("Sent!")
                            } else {
                                Text("Send Feedback")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(message.isEmpty || isSending || didSend)
                }
            }
            .navigationTitle("Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
```

### 3. Integration in `ContentView.swift`

Add the `alert` and `sheet` modifiers to the main `ContentView` or `CalculatorView`.

```swift
// Inside CalculatorView or ContentView body
.alert("Enjoying Currency Widget?", isPresented: $feedbackManager.showFeedbackPrompt) {
    Button("Not really") {
        feedbackManager.userIsUnhappy()
    }
    Button("Yes, it's great!") {
        feedbackManager.userIsHappy()
    }
}
.sheet(isPresented: $feedbackManager.showNegativeFeedbackSheet) {
    FeedbackView()
}
```

---

## 5. Next Steps for Developer

1.  Copy `FeedbackManager` and `FeedbackView` code into the project.
2.  Inject `FeedbackManager.shared.logSignificantEvent()` into the `saveExpense()` function in `CalculatorView`.
3.  Attach the `.alert` and `.sheet` modifiers to the root of `CalculatorView`.

This strategy ensures we aggressively filter for quality, boosting your App Store presence while gaining valuable insights from dissatisfied users directly.
