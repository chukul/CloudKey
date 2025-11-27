import SwiftUI

// Quick verification that ProfileEditorView initializes correctly
@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ProfileEditorView(
                session: Session(
                    alias: "Test Profile",
                    profileName: "test",
                    region: "us-east-1",
                    accountId: "123456789012",
                    status: .inactive,
                    type: .assumedRole,
                    roleArn: "arn:aws:iam::123456789012:role/TestRole",
                    mfaSerial: nil
                ),
                onSave: { session in
                    print("✅ Save called with: \(session.alias)")
                },
                onCancel: {
                    print("❌ Cancel called")
                }
            )
        }
    }
}
