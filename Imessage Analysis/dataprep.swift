//
//  dataprep.swift
//  Imessage Analysis
//
//  Created by Landon on 11/9/24.
//

import SwiftUI
import AppKit
import SQLite3
import Contacts
import Foundation

struct DataPrep {
    private var selectedFileURL: URL?

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ImessageAnalysisDataPath = documentsPath.appendingPathComponent("ImessageAnalysisData")
        let messagesPath = ImessageAnalysisDataPath.appendingPathComponent("processed_messages.csv")
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: messagesPath.path) {
            DispatchQueue.main.async {
                
                LoadingManager.shared.displayMessage = "Data has been processed. Now processing data and building graphs. I'll be back in 20 seconds"
            }
            print("Data found - proceeding to analysis")

        } else {
            createFolder()
            
            exportChatData()
                    
            exportContactsToCSV()
            readAndFormatAllChatData()
            updateMessageSendersWithContactNames()
            DispatchQueue.main.async {
                
                LoadingManager.shared.displayMessage = "Now processing data and building graphs. I'll be back in 20 seconds"
            }
        }

    }

    
    func createFolder() {
        // Get the URL to the Documents directory
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            // Create a new folder path
            let newFolderURL = documentsDirectory.appendingPathComponent("ImessageAnalysisData")
            
            do {
                // Create the folder if it doesn't exist
                try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: true, attributes: nil)
                print("Folder created at: \(newFolderURL.path)")
            } catch {
                print("Failed to create folder: \(error.localizedDescription)")
            }
        }
    }

    func updateMessageSendersWithContactNames() -> Result<String, Error> {
        
        DispatchQueue.main.async {
            
            LoadingManager.shared.displayMessage = "Linking phone numbers to contact names"
        }


        do {
            // Get document directory paths
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let ImessageAnalysisDataPath = documentsPath.appendingPathComponent("ImessageAnalysisData")
            
            // Set up file paths
            let contactsPath = ImessageAnalysisDataPath.appendingPathComponent("contacts.csv")
            let messagesPath = ImessageAnalysisDataPath.appendingPathComponent("formatted_all_chat_data.csv")
            let outputPath = ImessageAnalysisDataPath.appendingPathComponent("processed_messages.csv")
            
            // Load and parse contacts
            let contactsData = try String(contentsOf: contactsPath, encoding: .utf8)
            var contacts: [String: String] = [:]
            let contactRows = contactsData.components(separatedBy: .newlines)
            
            for row in contactRows.dropFirst() where !row.isEmpty {
                let columns = parseCSVRow(row)
                guard columns.count >= 4 else { continue }
                
                // Assuming phone numbers are in the 4th column, full name in the 1st
                let fullName = columns[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let phoneNumbers = columns[3].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                
                for phone in phoneNumbers.components(separatedBy: "; ") {
                    var standardizedPhone = phone.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                    if standardizedPhone.count == 10 {
                        standardizedPhone = "1" + standardizedPhone
                    }
                    contacts[standardizedPhone] = fullName
                }
            }
            
            // Read and process messages file
            let messagesData = try String(contentsOf: messagesPath, encoding: .utf8)
            let messageRows = messagesData.components(separatedBy: .newlines)
            
            let headerColumns = parseCSVRow(messageRows[0])
            var output = headerColumns.joined(separator: ",") + "\n"
            
            for row in messageRows.dropFirst() where !row.isEmpty {
                var columns = parseCSVRow(row)
                guard columns.count >= headerColumns.count else { continue }
                
                // Process sender and contact IDs
                var senderNumber = columns[2].replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                if senderNumber.count == 10 {
                    senderNumber = "1" + senderNumber
                }
                
                var contactIdNumber = columns[8].replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                if contactIdNumber.count == 10 {
                    contactIdNumber = "1" + contactIdNumber
                }
                
                if let contactName = contacts[senderNumber] {
                    columns[2] = contactName
                }
                
                if let contactName = contacts[contactIdNumber] {
                    columns[8] = contactName
                }
                
                // Adjust for group chat if needed
                if columns[5].trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
                    columns[8] = "" // Set to empty string if Group Chat is 0
                }
                
                // Format each column correctly for CSV
                let formattedRow = columns.map { escapeForCSV($0) }.joined(separator: ",")
                output += formattedRow + "\n"
            }
            
            // Write processed data to new file
            try output.write(to: outputPath, atomically: true, encoding: .utf8)
            print("Labeled all messages")
            return .success(outputPath.path)
        } catch {
            return .failure(error)
        }
    }

    // Helper function to escape fields for CSV format
    func escapeForCSV(_ field: String) -> String {
        var escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escapedField.contains(",") || escapedField.contains("\"") || escapedField.contains("\n") {
            escapedField = "\"\(escapedField)\""
        }
        return escapedField
    }







    
    
    func readAndFormatAllChatData() -> Result<String, Error> {
        DispatchQueue.main.async {
            
            LoadingManager.shared.displayMessage = "Indexing contacts and Imessages"
        }

        do {
            // Define the file path to "all_chat_data.csv" in the ImessageAnalysisData directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let ImessageAnalysisDataPath = documentsPath.appendingPathComponent("ImessageAnalysisData")
            let messagesPath = ImessageAnalysisDataPath.appendingPathComponent("all_chat_data.csv")
            let outputPath = ImessageAnalysisDataPath.appendingPathComponent("formatted_all_chat_data.csv")
            
            // Check if the file exists
            guard FileManager.default.fileExists(atPath: messagesPath.path) else {
                return .failure(NSError(domain: "readAndFormatAllChatData", code: 1, userInfo: [NSLocalizedDescriptionKey: "File all_chat_data.csv does not exist"]))
            }
            
            // Read the contents of the CSV file
            let csvData = try String(contentsOf: messagesPath, encoding: .utf8)
            let rows = csvData.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            guard !rows.isEmpty else {
                return .failure(NSError(domain: "readAndFormatAllChatData", code: 2, userInfo: [NSLocalizedDescriptionKey: "CSV file is empty"]))
            }
            
            // Parse the header row and prepare output with the header
            let headerRow = parseCSVRow(rows[0])
            var formattedOutput = headerRow.joined(separator: ",") + "\n"
            
            // Process each row after the header
            for row in rows.dropFirst() {
                let columns = parseCSVRow(row)
                guard columns.count == headerRow.count else {
                    print("Skipping row due to inconsistent column count: \(row)")
                    continue // Skip rows with inconsistent column counts
                }
                
                // Enclose each field in quotes and escape any internal quotes
                let formattedRow = columns.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                formattedOutput += formattedRow.joined(separator: ",") + "\n"
            }
            
            // Save the formatted CSV data to a new file
            try formattedOutput.write(to: outputPath, atomically: true, encoding: .utf8)
            
            print("Formatted CSV saved to \(outputPath.path)")
            return .success(outputPath.path)
        } catch {
            return .failure(error)
        }
    }

    // Helper function to parse a CSV row with quoted fields
    func parseCSVRow(_ row: String) -> [String] {
        var result = [String]()
        var currentField = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle() // Toggle quote state
            } else if char == "," && !insideQuotes {
                // End of a field
                result.append(currentField)
                currentField = ""
            } else {
                // Append the character
                currentField.append(char)
            }
        }
        // Append the last field
        result.append(currentField)
        
        // Trim spaces and double quotes from each field
        return result.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }








    func exportContactsToCSV() -> Result<String, Error> {
        do {
            // Set up paths
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let ImessageAnalysisDataPath = documentsPath.appendingPathComponent("ImessageAnalysisData")
            try FileManager.default.createDirectory(at: ImessageAnalysisDataPath, withIntermediateDirectories: true)
            let csvPath = ImessageAnalysisDataPath.appendingPathComponent("contacts.csv")
            DispatchQueue.main.async {
                
                LoadingManager.shared.displayMessage = "Reading contacts from \(csvPath)"
            }


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

    func exportChatData() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let chatdbPath = homeDirectory.appendingPathComponent("Library/Messages/chat.db")
        
        if FileManager.default.fileExists(atPath: chatdbPath.path) {
            print("Found chat.db at \(chatdbPath.path)")
        } else {
            print("chat.db not found at \(chatdbPath.path)")
        }
        DispatchQueue.main.async {
            
            LoadingManager.shared.displayMessage = "Reading Imessage data in \(chatdbPath)"
        }
        let fileManager = FileManager.default
        let outputDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ImessageAnalysisData")
        
        // Create output directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create directory: \(error.localizedDescription)")
            return
        }
        
        let csvOutputPath = outputDir.appendingPathComponent("all_chat_data.csv")
        var db: OpaquePointer?
        if sqlite3_open(chatdbPath.path, &db) != SQLITE_OK {
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
            var csvString = "Timestamp,Readable Time,Sender,Sender ID,Message,Group Chat,Group Chat Name,Sent by Me,To\n"
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let timestamp = sqlite3_column_double(statement, 0)
                // Safely unwrap each column that could be NULL
                let readableTime = sqlite3_column_text(statement, 1).flatMap { String(cString: $0) } ?? "N/A"
                let sender = sqlite3_column_text(statement, 2).flatMap { String(cString: $0) } ?? "Unknown"
                let senderId = sqlite3_column_int64(statement, 3)
                
                // Escape quotes and handle commas in message text
                let messageText = sqlite3_column_text(statement, 4).flatMap { String(cString: $0) } ?? ""
                let escapedMessageText = messageText
                    .replacingOccurrences(of: "\"", with: "\"\"")  // Escape internal quotes
                    .replacingOccurrences(of: "\n", with: " ")     // Remove any newlines
                    .replacingOccurrences(of: "\r", with: " ")     // Remove carriage returns
                
                let isGroupChat = sqlite3_column_int(statement, 5)
                let groupChatName = sqlite3_column_text(statement, 6).flatMap { String(cString: $0) } ?? ""
                let escapedGroupChatName = groupChatName.replacingOccurrences(of: "\"", with: "\"\"")
                
                let isFromMe = sqlite3_column_int(statement, 7)
                let contactIdentifier = sqlite3_column_text(statement, 8).flatMap { String(cString: $0) } ?? ""
                let escapedContactIdentifier = contactIdentifier.replacingOccurrences(of: "\"", with: "\"\"")
                
                // Escape quotes in other fields
                let escapedReadableTime = readableTime.replacingOccurrences(of: "\"", with: "\"\"")
                let escapedSender = sender.replacingOccurrences(of: "\"", with: "\"\"")
                
                // Enclose fields in double quotes to maintain CSV structure
                csvString += """
                "\(timestamp)","\(escapedReadableTime)","\(escapedSender)","\(senderId)","\(escapedMessageText)","\(isGroupChat)","\(escapedGroupChatName)","\(isFromMe)","\(escapedContactIdentifier)"\n
                """
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


