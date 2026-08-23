import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(MessageUI)
import MessageUI
#endif

struct SupportReportSheet: View {
    let accountName: String
    let accountType: String
    let businessSupportEmail: String?
    let appSupportEmail = "pianivomindfulscheduling@gmail.com"
    let privacyPolicyURL = URL(string: "https://pianivo-mindful-scheduling.onrender.com/privacy/")!
    let privacyChoicesURL = URL(string: "https://pianivo-mindful-scheduling.onrender.com/privacy/choices/")!

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var topic = "App error"
    @State private var message = ""
    @State private var includeDiagnosticDetails = true
    @State private var showMailComposer = false
    @State private var showMailUnavailable = false

    private let topics = [
        "Business support",
        "Booking problem",
        "Payment issue",
        "Login problem",
        "App error",
        "Other"
    ]

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !trimmedMessage.isEmpty && currentRecipientEmail.contains("@")
    }

    private var isBusinessRelatedTopic: Bool {
        topic == "Business support" || topic == "Booking problem"
    }

    private var currentRecipientEmail: String {
        if isBusinessRelatedTopic,
           let email = businessSupportEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
           !email.isEmpty {
            return email
        }
        return appSupportEmail
    }

    private var destinationLabel: String {
        isBusinessRelatedTopic && currentRecipientEmail != appSupportEmail ? "the business" : "Pianivo support"
    }

    private var supportSubject: String {
        "Pianivo Support: \(topic)"
    }

    private var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = currentRecipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: supportSubject),
            URLQueryItem(name: "body", value: supportBody)
        ]
        return components.url
    }

    private var supportBody: String {
        var body = """
        Account: \(accountName)
        Account type: \(accountType)
        Topic: \(topic)

        Issue:
        \(trimmedMessage)
        """

        if includeDiagnosticDetails {
            body += """


            Diagnostic details:
            App version: \(appVersion)
            Device: \(deviceName)
            System: \(systemVersion)
            Sent: \(Date().formatted(date: .abbreviated, time: .shortened))
            """
        }

        return body
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private var deviceName: String {
#if canImport(UIKit)
        UIDevice.current.model
#else
        "Unknown"
#endif
    }

    private var systemVersion: String {
#if canImport(UIKit)
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
#else
        ProcessInfo.processInfo.operatingSystemVersionString
#endif
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Issue type", selection: $topic) {
                        ForEach(topics, id: \.self) { topic in
                            Text(topic).tag(topic)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        TextEditor(text: $message)
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } header: {
                    Text("Support request")
                } footer: {
                    Text("This sends your report to \(destinationLabel) at \(currentRecipientEmail). Include enough detail to reproduce the problem.")
                }

                Section {
                    Toggle("Include app and device details", isOn: $includeDiagnosticDetails)
                }

                Section("Legal") {
                    Link("Privacy Policy", destination: privacyPolicyURL)
                    Link("Privacy Choices", destination: privacyChoicesURL)
                }

                Section {
                    Button {
                        sendSupportRequest()
                    } label: {
                        Label("Send Support Request", systemImage: "paperplane.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSend)
                }
            }
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
#if canImport(MessageUI)
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    recipient: currentRecipientEmail,
                    subject: supportSubject,
                    body: supportBody
                )
            }
#endif
            .alert("Mail Not Available", isPresented: $showMailUnavailable) {
                Button("Copy Email") {
#if canImport(UIKit)
                    UIPasteboard.general.string = currentRecipientEmail
#endif
                }
                Button("Copy Report") {
#if canImport(UIKit)
                    UIPasteboard.general.string = "\(currentRecipientEmail)\n\n\(supportSubject)\n\n\(supportBody)"
#endif
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Set up Mail on this device, or copy the support details and send them to \(currentRecipientEmail).")
            }
        }
    }

    private func sendSupportRequest() {
#if canImport(MessageUI)
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else if let mailtoURL {
            openURL(mailtoURL) { accepted in
                if !accepted {
                    showMailUnavailable = true
                }
            }
        } else {
            showMailUnavailable = true
        }
#else
        showMailUnavailable = true
#endif
    }
}

// MARK: - Appointment Card
struct AppointmentCard: View {
    let appt: Appointment
    var showEmployee: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. Service Color Strip
            // FIX: Ensure the capsule takes up the full height of the text content
            Capsule()
                .fill(appt.service?.themeColor ?? .teal)
                .frame(width: 4)
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(appt.customerName)
                    .font(.headline)
                    .lineLimit(1) // Prevent name from pushing layout down
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(appt.startTime.formatted(date: .omitted, time: .shortened))
                    Text("•")
                    Text(appt.service?.name ?? "Appointment")
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                if showEmployee {
                    Label(appt.employeeName, systemImage: "person.circle")
                        .font(.caption2)
                        .foregroundColor(.teal)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // 2. Status & Stress Badges
            VStack(alignment: .trailing, spacing: 6) {
                // FIX: Use a ZStack or fixed height here to prevent the card
                // from changing height when the stress icon is present.
                if appt.isHighStress {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Placeholder to maintain alignment height
                    Color.clear.frame(height: 12)
                }
                
                Text(appt.status == .completed ? "PAID" : "PENDING")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(appt.status == .completed ? Color.teal.opacity(0.1) : Color.orange.opacity(0.1))
                    .foregroundColor(appt.status == .completed ? .teal : .orange)
                    .clipShape(Capsule())
            }
            .frame(minWidth: 60) // Ensure the badge area has consistent width
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(appt.isHighStress ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle()) // Makes the whole card tappable, not just the text
    }
}

// MARK: - Summary Card
struct SummaryBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            
            Text(value)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7) // FIX: Prevents "..." on small screens
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Mini Status Circle
struct MiniStatusCircle: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.1), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress) // Adds smooth filling effect
        }
        .frame(width: 40, height: 40)
    }
}
