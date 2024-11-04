import SwiftUI
import AppKit
import SQLite3
import Contacts
import Foundation


struct ContentView: View {
    @State private var selectedFileURL: URL?
    @State private var showAnalysisView = false
    var body: some View {
        VStack {
            Button(action: {
                print("Button tapped")
                openFilePicker()
                createFolder()
                if let dbURL = selectedFileURL {
                    exportChatData(to: dbURL) // Call function to export chat data
                }
                exportContactsToCSV()
                updateMessageSendersWithContactNames()
                showAnalysisView = true
            }) {
                Text("Access Imessages")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            if let fileURL = selectedFileURL {
                Text("Selected file: \(fileURL.lastPathComponent)")
            }
            if showAnalysisView {
                MessagesAnalysisView()
                    .transition(.slide) // Optional: Add a transition animation
            }

        }
        .padding()
    }
    func createFolder() {
        // Get the URL to the Documents directory
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            // Create a new folder path
            let newFolderURL = documentsDirectory.appendingPathComponent("MyAppData")
            
            do {
                // Create the folder if it doesn't exist
                try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: true, attributes: nil)
                print("Folder created at: \(newFolderURL.path)")
            } catch {
                print("Failed to create folder: \(error.localizedDescription)")
            }
        }
    }

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["db"]  // Accept only .db files
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Select chat.db File" // Optional: Set panel title
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Library/Messages") // Default directory for iMessage database

        if panel.runModal() == .OK {
            if let url = panel.url, url.lastPathComponent == "chat.db" { // Ensure it’s the correct file
                selectedFileURL = url
            } else {
                print("Selected file is not chat.db") // Handle incorrect file selection
            }
        }
    }
    func updateMessageSendersWithContactNames() -> Result<String, Error> {
        do {
            // Get document directory paths
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let myAppDataPath = documentsPath.appendingPathComponent("MyAppData")
            
            // Set up file paths
            let contactsPath = myAppDataPath.appendingPathComponent("contacts.csv")
            let messagesPath = myAppDataPath.appendingPathComponent("all_chat_data.csv")
            let outputPath = myAppDataPath.appendingPathComponent("processed_messages.csv")
            
            // Load and parse contacts
            let contactsData = try String(contentsOf: contactsPath, encoding: .utf8)
            var contacts: [String: String] = [:]
            let contactRows = contactsData.components(separatedBy: .newlines)

            // Parse contacts starting after header
            for row in contactRows.dropFirst() where !row.isEmpty {
                let columns = row.components(separatedBy: ",")
                guard columns.count >= 2 else { continue }
                
                // Get phone numbers and full name (assuming phone numbers are in 4th column, full name in 1st)
                let fullName = columns[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let phoneNumbers = columns[3].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                
                // Split phone numbers if multiple exist (separated by semicolon)
                for phone in phoneNumbers.components(separatedBy: "; ") {
                    // Clean and standardize phone number
                    var standardizedPhone = phone.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                    if standardizedPhone.count == 10 {
                        standardizedPhone = "1" + standardizedPhone
                    }
                    contacts[standardizedPhone] = fullName
                }
            }
            
            // Read messages file
            let messagesData = try String(contentsOf: messagesPath, encoding: .utf8)
            let messageRows = messagesData.components(separatedBy: .newlines)
            var output = messageRows[0].replacingOccurrences(of: "Contact Identifier", with: "To") + "\n" // Change "old_header_name" to the actual header of the eighth column

            // Prepare output with header
            
            
            // Process each message row
            for row in messageRows.dropFirst() where !row.isEmpty {
                var columns = row.components(separatedBy: ",")
                guard columns.count >= 9 else { continue }
                
                // Get sender column (third column) and clean it
                var senderNumber = columns[2].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                senderNumber = senderNumber.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                if senderNumber.count == 10 {
                    senderNumber = "1" + senderNumber
                }
                
                var contactidNumber = columns[8].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                contactidNumber = contactidNumber.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                if contactidNumber.count == 10 {
                    contactidNumber = "1" + senderNumber
                }


                // Replace sender with contact name if exists
                if let contactName = contacts[senderNumber] {
                    columns[2] = "\"\(contactName)\""
                }
                
                // Replace sender with contact name if exists
                if let contactName = contacts[contactidNumber] {
                    columns[8] = "\"\(contactName)\""
                }
                
                if columns[5].trimmingCharacters(in: .whitespacesAndNewlines) == "0" {
                    columns[8] = "\"\"" // Set to empty string if Group Chat is 0
                }
                
                

                // Add processed row to output
                output += columns.joined(separator: ",") + "\n"
            }
            
            // Write processed data to new file
            try output.write(to: outputPath, atomically: true, encoding: .utf8)
            print("Labeled all messages")
            return .success(outputPath.path)
        } catch {
            return .failure(error)
        }
    }







    func exportContactsToCSV() -> Result<String, Error> {
        do {
            // Set up paths
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let myAppDataPath = documentsPath.appendingPathComponent("MyAppData")
            try FileManager.default.createDirectory(at: myAppDataPath, withIntermediateDirectories: true)
            let csvPath = myAppDataPath.appendingPathComponent("contacts.csv")
            
            // Get AddressBook database path
            guard let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? else {
                throw NSError(domain: "ContactsExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get home directory"])
            }
            
            let dbPath = "\(homeDir)/Library/Application Support/AddressBook/Sources/E5E82F88-A657-4108-A5BE-1FEEC0F6DFBA/AddressBook-v22.abcddb"
            
            // Open database
            var db: OpaquePointer?
            if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
                throw NSError(domain: "ContactsExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not open database"])
            }
            defer { sqlite3_close(db) }
            
            // Prepare CSV string
            var csvString = "Full Name,First Name,Last Name,Phone Number\n"
            
            // SQL query
            let query = """
                SELECT 
                    TRIM(COALESCE(ZABCDRECORD.ZFIRSTNAME, '') || ' ' || COALESCE(ZABCDRECORD.ZLASTNAME, '')) as full_name,
                    COALESCE(ZABCDRECORD.ZFIRSTNAME, '') as first_name,
                    COALESCE(ZABCDRECORD.ZLASTNAME, '') as last_name,
                    (SELECT GROUP_CONCAT(ZFULLNUMBER, '; ')
                     FROM ZABCDPHONENUMBER
                     WHERE ZABCDPHONENUMBER.ZOWNER = ZABCDRECORD.Z_PK) as phones
                FROM ZABCDRECORD
                WHERE ZFIRSTNAME IS NOT NULL 
                   OR ZLASTNAME IS NOT NULL
                ORDER BY full_name
            """
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    // Helper function to safely convert SQLite text to String
                    func getColumnText(_ columnIndex: Int32) -> String {
                        guard let cString = sqlite3_column_text(stmt, columnIndex) else {
                            return ""
                        }
                        return String(cString: cString)
                    }
                    
                    let fullName = getColumnText(0)
                    let firstName = getColumnText(1)
                    let lastName = getColumnText(2)
                    let phones = getColumnText(3)
                    
                    // Split phone numbers by semicolon
                    let phoneNumbers = phones.split(separator: ";").map { phone in
                        // Remove all non-numeric characters
                        var cleanedPhone = phone.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                        
                        // If the cleaned phone number has 10 digits, prepend "1"
                        if cleanedPhone.count == 10 {
                            cleanedPhone = "1" + cleanedPhone
                        }
                        
                        return cleanedPhone
                    }
                    
                    // Add each phone number as a separate row
                    for phone in phoneNumbers {
                        let row = "\"\(fullName)\",\"\(firstName)\",\"\(lastName)\",\"\(phone)\"\n"
                        csvString += row
                    }
                }
            }
            
            // Write to file
            try csvString.write(to: csvPath, atomically: true, encoding: .utf8)
            print("All contacts saved")
            return .success(csvPath.path)
        } catch {
            return .failure(error)
        }
    }


    func exportChatData(to dbURL: URL) {
        let fileManager = FileManager.default
        let outputDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("MyAppData")
        
        // Create output directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create directory: \(error.localizedDescription)")
            return
        }

        let csvOutputPath = outputDir.appendingPathComponent("all_chat_data.csv")

        var db: OpaquePointer?
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("Error opening database")
            return
        }

        let query = """
        SELECT 
            message.date/1000000000 + strftime('%s', '2001-01-01') AS timestamp,
            datetime(message.date/1000000000 + strftime('%s', '2001-01-01'), 'unixepoch', 'localtime') AS readable_time,
            CASE 
                WHEN message.is_from_me = 1 THEN 'Me'
                ELSE handle.id
            END AS sender,
            handle.ROWID AS sender_id,
            message.text AS message_text,
            CASE 
                WHEN chat.style = 43 THEN 1 
                ELSE 0 
            END AS is_group_chat,
            chat.display_name AS group_chat_name,
            message.is_from_me,
            handle.id AS contact_identifier
        FROM message 
        LEFT JOIN handle ON message.handle_id = handle.ROWID 
        LEFT JOIN chat_message_join ON message.ROWID = chat_message_join.message_id
        LEFT JOIN chat ON chat_message_join.chat_id = chat.ROWID
        WHERE message.text IS NOT NULL
        ORDER BY message.date DESC
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            var csvString = "Timestamp,Readable Time,Sender,Sender ID,Message,Group Chat,Group Chat Name,Sent by Me,Contact Identifier\n"

            while sqlite3_step(statement) == SQLITE_ROW {
                let timestamp = sqlite3_column_double(statement, 0)

                // Safely unwrap each column that could be NULL
                let readableTime = sqlite3_column_text(statement, 1).flatMap { String(cString: $0) } ?? "N/A"
                let sender = sqlite3_column_text(statement, 2).flatMap { String(cString: $0) } ?? "Unknown"
                let senderId = sqlite3_column_int64(statement, 3)
                let messageText = sqlite3_column_text(statement, 4).flatMap { String(cString: $0) } ?? ""
                let isGroupChat = sqlite3_column_int(statement, 5)
                let groupChatName = sqlite3_column_text(statement, 6).flatMap { String(cString: $0) } ?? "N/A"
                let isFromMe = sqlite3_column_int(statement, 7)
                let contactIdentifier = sqlite3_column_text(statement, 8).flatMap { String(cString: $0) } ?? ""

                csvString += "\(timestamp),\"\(readableTime)\",\"\(sender)\",\(senderId),\"\(messageText)\",\(isGroupChat),\"\(groupChatName)\",\(isFromMe),\"\(contactIdentifier)\"\n"
            }

            // Write CSV string to file
            do {
                try csvString.write(to: csvOutputPath, atomically: true, encoding: .utf8)
                print("All relevant chat data has been exported to \(csvOutputPath.path)")
            } catch {
                print("Failed to write CSV file: \(error.localizedDescription)")
            }
        } else {
            print("Error preparing statement: \(String(cString: sqlite3_errmsg(db)))")
        }

        sqlite3_finalize(statement)
        sqlite3_close(db)
    }

}

@main
struct Imessage_AnalysisApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView() // This will load the MessagesAnalysisView
        }
    }
}
