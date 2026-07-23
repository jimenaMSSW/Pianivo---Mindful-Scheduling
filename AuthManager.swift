import SwiftUI
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

@MainActor
class AuthManager: ObservableObject {
    @Published var isUnlocked = false
    @Published var authError: String? = nil
    
    func authenticate() {
#if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Book, manage, and track your appointments securely."
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authErr in
                Task { @MainActor in
                    if success {
                        withAnimation { self.isUnlocked = true }
                        self.authError = nil
                    } else {
                        self.authError = authErr?.localizedDescription ?? "Authentication failed."
                    }
                }
            }
        } else {
            // Biometrics/passcode unavailable (Swift Playgrounds, simulator) — auto-unlock
            withAnimation { isUnlocked = true }
        }
#else
        // LocalAuthentication not available — auto-unlock
        withAnimation { isUnlocked = true }
#endif
    }
    
    func logout() {
        withAnimation {
            isUnlocked = false
            authError = nil
        }
    }
}
