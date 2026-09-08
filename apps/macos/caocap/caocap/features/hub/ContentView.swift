import SwiftUI

struct ContentView: View {
    @Bindable var authentication: AuthenticationManager
    @Bindable var devices: DevicePresence
    @Bindable var relay: RemoteCommandRelay
    @Bindable var gate: ComputerUseInstallGate
    @Bindable var workspace: ComputerUseWorkspace
    var body: some View {
        Form {
            Section("Account") {
                switch authentication.authState {
                case .signedIn(let uid):
                    Text(authentication.identityLabel).font(.headline)
                    Text(uid).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("Sign Out") { authentication.signOut() }
                case .signedOut: signInButtons
                case .failed(let message): Text(message).foregroundStyle(.red); signInButtons
                }
                if let code = authentication.githubSignIn.userCode {
                    Text("Enter this code on GitHub: \(code)").textSelection(.enabled)
                    Button("Cancel GitHub Sign-In") { authentication.githubSignIn.cancel() }
                }
            }
            Section("This Mac") {
                Toggle("Enable requests from my iPhone", isOn: $relay.requestsEnabled)
                    .disabled(!isSignedIn)
                Text("CoCaptain can write a short TextEdit document and return its saved text to your iPhone. Screenshots of that document are sent to the model while it works.")
                    .font(.callout).foregroundStyle(.secondary)
                Label(gate.status?.installed == true ? "Computer-use driver included" : "Driver missing — install a complete CAOCAP build", systemImage: gate.status?.installed == true ? "checkmark.circle" : "exclamationmark.circle")
                Label("Accessibility", systemImage: gate.status?.accessibilityGranted == true ? "checkmark.circle" : "circle")
                Label("Screen Recording", systemImage: gate.status?.screenRecordingGranted == true ? "checkmark.circle" : "circle")
                Button("Grant Permissions") { Task { await gate.requestPermissions() } }
                LabeledContent("Working folder", value: workspace.folderDisplayName)
                Button("Choose Folder…") { workspace.chooseFolder() }
                Button("Refresh Setup Status") { Task { await gate.refresh() } }
            }
            Section("Linked Devices") {
                if devices.otherDevices.isEmpty { Text("Sign in on your iPhone with the same account to see it here.").foregroundStyle(.secondary) }
                ForEach(devices.otherDevices) { device in Text(device.menuLabel()) }
            }
            Section("Last Request") { Text(relay.lastRequest) }
        }
        .formStyle(.grouped).frame(minWidth: 440, minHeight: 560)
        .task { await gate.refresh() }
    }
    private var isSignedIn: Bool { if case .signedIn = authentication.authState { true } else { false } }
    private var signInButtons: some View {
        VStack(alignment: .leading) {
            Button("Sign in with Apple") { Task { await authentication.signInWithApple() } }
            Button("Continue with Google") { Task { await authentication.signInWithGoogle() } }
            Button("Continue with GitHub") { Task { await authentication.signInWithGitHub() } }
        }.disabled(authentication.isSigningIn)
    }
}
