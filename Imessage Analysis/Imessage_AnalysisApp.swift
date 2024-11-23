import SwiftUI
import Foundation
import Cocoa

final class LoadingManager: ObservableObject {
    static let shared = LoadingManager()
    @Published var isLoading: Bool = false
    @Published var displayMessage: String = "Starting"
    @Published var targetGC: String = ""
    @Published var targetContact: String = ""
    private init() {}
}

struct ContentView: View {
    @ObservedObject private var loadingManager = LoadingManager.shared
    @State private var isAnimating = false
    @State private var targContact: String = ""
    @State private var targGC: String = ""
    @State private var firstClick = true
    @State private var buttonText = "Access iMessages"
    @State private var dataPrepCompleted = false // New state to track completion

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                Button(action: {
                    handleButtonClick()
                }) {
                    Text(buttonText)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer(minLength: 30)
                
                HStack {
                    VStack {
                        Text("Specific Contact Analysis")
                            .font(.headline)
                            .padding(.bottom, 5)
                        TextField("Case sensitive", text: $targContact)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                    }
                    Spacer()
                    VStack {
                        Text("Specific Group Chat Analysis")
                            .font(.headline)
                            .padding(.bottom, 5)
                        TextField("Case sensitive", text: $targGC)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                if dataPrepCompleted { // Show only after DataPrep completes
                    MessagesAnalysisView()
                        .transition(.slide)
                }
            }
            .padding(.top)
            .frame(minWidth: 1100, minHeight: 700)
            
            if loadingManager.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack {
                    CustomSpinner(isAnimating: $isAnimating)
                        .frame(width: 350, height: 150)
                    Text(loadingManager.displayMessage)
                        .foregroundColor(.gray)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .frame(width: 150, height: 150)
            }
        }
        .animation(.easeInOut, value: loadingManager.isLoading)
    }
    
    private func handleButtonClick() {
        if !checkFullDiskAccess() {
            showFullDiskAccessAlert()
        } else {
            if firstClick {
                firstClick = false
                buttonText = "Reset"
                Task {
                    await startDataAnalysis()
                }
            } else {
                resetApp()
            }
        }
    }
    
    private func startDataAnalysis() async {
        LoadingManager.shared.isLoading = true
        isAnimating = true
        LoadingManager.shared.targetGC = targGC
        LoadingManager.shared.targetContact = targContact

        // Start DataPrep processing asynchronously
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let dataPrep = DataPrep() // Perform DataPrep operation
                
                DispatchQueue.main.async {
                    LoadingManager.shared.isLoading = false
                    isAnimating = false
                    dataPrepCompleted = true // Update to true only after completion
                    continuation.resume()
                }
            }
        }
    }
    
    private func resetApp() {
        buttonText = "Access iMessages"
        firstClick = true
        targContact = ""
        targGC = ""
        dataPrepCompleted = false // Reset the view load condition
    }
}

func showFullDiskAccessAlert() {
    let alert = NSAlert()
    alert.messageText = "Full Disk Access Required"
    let linkText = "(Link to Code)"
    let linkURL = URL(string: "https://github.com/landonWcummings/imessageanalysisapp")!
    
    let informativeText = """
    This app requires Full Disk Access to function. You are 3 clicks away:
    1. Open System Preferences.
    2. Go to Security & Privacy > Privacy > Full Disk Access.
    3. Click the slider enabling disk access for this app (or add it if it does not appear on the list).
    
    Understand why this app needs disk access:
    - iMessage Analysis will only ever access two files: the iMessages database and the contacts database.
    
    NOTE:
    - iMessage Analysis is completely open source \(linkText).
    - iMessage Analysis will never connect to the internet. Everything runs locally on your machine.
    
    After granting access, please restart the app.
    """
    
    let fullText = NSMutableAttributedString(string: informativeText)
    if let linkRange = fullText.string.range(of: linkText) {
        let nsRange = NSRange(linkRange, in: fullText.string)
        fullText.addAttribute(.link, value: linkURL, range: nsRange)
    }
    
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 350))
    textView.textStorage?.setAttributedString(fullText)
    textView.isEditable = false
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = false
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    alert.accessoryView = textView
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open System Preferences")
    alert.addButton(withTitle: "Cancel")
    
    if alert.runModal() == .alertFirstButtonReturn {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

func checkFullDiskAccess() -> Bool {
    let fileManager = FileManager.default
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let chatDBPath = homeDirectory.appendingPathComponent("Library/Messages/chat.db")
    
    if fileManager.isReadableFile(atPath: chatDBPath.path) {
        do {
            let fileHandle = try FileHandle(forReadingFrom: chatDBPath)
            fileHandle.closeFile()
            print("Full Disk Access is granted.")
            return true
        } catch {
            print("Failed to read chat.db: \(error.localizedDescription)")
            return false
        }
    } else {
        print("chat.db is not readable.")
        return false
    }
}

struct CustomSpinner: View {
    @Binding var isAnimating: Bool
    @State private var rotation: Double = 0
    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1.0)
            .stroke(Color.blue, lineWidth: 5)
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .opacity(isAnimating ? 1.0 : 0.0)
    }
}

@main
struct Imessage_AnalysisApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(DefaultWindowStyle())
    }
}



