import SwiftUI
import StoreKit

class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    @Published var showFeedbackPrompt: Bool = false
    @Published var showNegativeFeedbackSheet: Bool = false
    
    private let interactionCountKey = "userInteractionCount"
    // Using the endpoint provided by the user
    private let feedbackEndpoint = "https://reactblog.pl/lumumu/feedback.php"
    
    // Config: How often to ask? (Every 5th valid action)
    private let interactionsBeforePrompt = 5
    
    func logSignificantEvent() {
        let current = UserDefaults.standard.integer(forKey: interactionCountKey)
        let newCount = current + 1
        UserDefaults.standard.set(newCount, forKey: interactionCountKey)
        
        // Check if it's time to ask
        // We ask every 'interactionsBeforePrompt' times to ensure we catch them eventually
        // but not too often if they dismiss it (native review controller handles its own frequency limits too)
        if newCount > 0 && newCount % interactionsBeforePrompt == 0 {
            // Delay slightly so it doesn't pop up INSTANTLY after the save animation starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showFeedbackPrompt = true
            }
        }
    }
    
    func userIsHappy() {
        // Direct to App Store Review
        // SKStoreReviewController handles the logic of "don't show too often" internally for the actual store prompt.
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    func userIsUnhappy() {
        // Open internal feedback form
        showNegativeFeedbackSheet = true
    }
    
    func sendFeedback(message: String, email: String = "Anonymous", completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: feedbackEndpoint) else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let device = UIDevice.current
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        let body: [String: Any] = [
            "message": message,
            "email": email,
            "uid": device.identifierForVendor?.uuidString ?? "Unknown",
            "version": version
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("JSON Error: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Network Error: \(error)")
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    print("Server Error: \(String(describing: response))")
                    completion(false)
                }
            }
        }.resume()
    }
}
