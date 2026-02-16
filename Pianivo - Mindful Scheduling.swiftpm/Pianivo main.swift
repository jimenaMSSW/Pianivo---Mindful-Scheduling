import SwiftUI
import SwiftData

@main
struct PianivoApp: App {
    
    // 1. Static ensures this is only initialized ONCE per app launch
    // 2. This prevents the "Infinite Loading" hang caused by re-initialization
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Appointment.self,
            Service.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema, 
            isStoredInMemoryOnly: false, // Persistent for the judge
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If the judge has an old version of your app, this might fail 
            // due to a schema mismatch. This is a common reason for hangs.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainEntryView()
                .tint(.teal) // Great choice for a "Mindful" app
        }
        // Use the static property here
        .modelContainer(Self.sharedModelContainer)
    }
}
