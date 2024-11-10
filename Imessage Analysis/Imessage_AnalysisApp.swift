import SwiftUI
import Foundation
import Cocoa


final class LoadingManager: ObservableObject {
    static let shared = LoadingManager() // Singleton instance
    @Published var isLoading: Bool = false
    @Published var displayMessage: String = "Starting"
    @Published var targetGC: String = ""
    @Published var targetContact: String = ""
    private init() {} // Private initializer to enforce singleton
}

struct ContentView: View {
    @ObservedObject private var loadingManager = LoadingManager.shared // Observe the loading manager
    @State private var showAnalysisView = false
    @State private var isAnimating = false // Controls the animation state of the spinner
    @State private var targContact: String = "" // First text input state
    @State private var targGC: String = "" // Second text input stat
    @State private var firstClick: Bool = true
    

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                // Access Imessages Button above the input fields
                Button(action: {
                    
                    if !checkFullDiskAccess() {
                        // Prompt the user to grant Full Disk Access
                        showFullDiskAccessAlert()
                    }else{
                        if firstClick {
                            print("Button tapped")
                            firstClick = false
                            

                            LoadingManager.shared.isLoading = true // Start loading
                            isAnimating = true // Start animation

                            // Run long-running tasks in the background
                            DispatchQueue.global().async {
                                DispatchQueue.main.async {
                                    LoadingManager.shared.targetGC = targGC
                                    LoadingManager.shared.targetContact = targContact
                                    
                                }

                                
                                let datastartup = DataPrep() // Perform DataPrep operation
                                MessagesAnalysisView() // Perform MessageAnalysis operation

                                // Once the operations are done, update on the main thread
                                DispatchQueue.main.async {
                                    LoadingManager.shared.isLoading = false // Stop loading
                                    isAnimating = false // Stop animation
                                    showAnalysisView = true // Show analysis view
                                }
                            }
                            
                        }else{
                            print("second time")
                            showAnalysisView = false
                            firstClick = true
                            
                            
                        }
                        
                    }
                    
                }) {
                    Text("Access Imessages")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 30) // Add some space between the button and input fields
                
                // HStack for input fields
                HStack {
                    // Left input box with label above it
                    VStack {
                        Text("Specific Contact Analysis") // Label for first input field
                            .font(.headline)
                            .padding(.bottom, 5)
                        TextField("Case sensitive", text: $targContact)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                    }
                    
                    Spacer() // To create space between the two input fields
                    
                    // Right input box with label above it
                    VStack {
                        Text("Specific Group Chat Analysis") // Label for second input field
                            .font(.headline)
                            .padding(.bottom, 5)
                        TextField("Case sensitive", text: $targGC)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                    }
                }
                .padding(.horizontal) // Add padding around HStack
                .padding(.bottom, 20) // Add padding at the bottom if needed
                
                
                if showAnalysisView {
                    
                    MessagesAnalysisView()
                        .transition(.slide)
                }
            }
            .padding(.top)
            .frame(minWidth: 1100, minHeight: 700)
            
            // Display loading overlay when isLoading is true
            if loadingManager.isLoading {
                Color.black.opacity(0.3) // Semi-transparent background
                    .ignoresSafeArea()
                
                VStack {
                    CustomSpinner(isAnimating: $isAnimating) // Custom spinner view
                        .frame(width: 350, height: 150) // Adjust size as desired
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

}



func showFullDiskAccessAlert() {
    let alert = NSAlert()
    alert.messageText = "Full Disk Access Required"
    let linkText = "(Link to Code)"
    let linkURL = URL(string: "https://github.com/landonWcummings/imessageanalysisapp")!

    // Find the range of the link text and add the link attribute
    
    // Informative text explaining the need for disk access
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
    
    // Creating an attributed string for the alert with a hyperlink
    let fullText = NSMutableAttributedString(string: informativeText)
    if let linkRange = fullText.string.range(of: linkText) {
        let nsRange = NSRange(linkRange, in: fullText.string)
        fullText.addAttribute(.link, value: linkURL, range: nsRange)
    }

    // Setting up the accessory view as a non-editable NSTextView
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 350))
    textView.textStorage?.setAttributedString(fullText)
    textView.isEditable = false
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = false
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true

    // Add the accessory view to the alert
    alert.accessoryView = textView
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open System Preferences")
    alert.addButton(withTitle: "Cancel")

    // Handle the alert button actions
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
        // Attempt to read a small portion of the file
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


// Custom Spinner View
struct CustomSpinner: View {
    @Binding var isAnimating: Bool
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1.0) // Partial circle for spinner appearance
            .stroke(Color.blue, lineWidth: 5) // Customize color and width
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(rotation)) // Rotate the circle
            .onAppear {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360 // Rotate full circle every second
                }
            }
            .opacity(isAnimating ? 1.0 : 0.0) // Hide when not animating
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

