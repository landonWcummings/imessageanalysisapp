import SwiftUI
import Charts
import Foundation

// MARK: - Data Models
struct Message: Identifiable {
    let id = UUID()
    let readableTime: Date
    let sentByMe: Bool
    let groupChat: Bool
    let groupChatName: String?
    let sender: String
    let to: String
}

struct ActivityDataPoint: Identifiable {
    let id = UUID()
    let intervalStart: Date
    let sent: Int
    let received: Int
    var total: Int {
        return sent + received
    }
}

struct PersonLineDataPoint: Identifiable {
    let id = UUID()
    let intervalStart: Date
    let messageType: String // "DM Messages" or "Total Interactions"
    let count: Int
}

struct TimeActivityDataPoint: Identifiable {
    let id = UUID()
    let timeSegment: String
    let sent: Int
    let received: Int
    var total: Int {
        return sent + received
    }
}

struct ActivityLineDataPoint: Identifiable {
    let id = UUID()
    let intervalStart: Date
    let messageType: String // "Sent", "Received", or "Total"
    let count: Int
}


struct GroupChatParticipation: Identifiable {
    let id = UUID()
    let groupChatName: String
    let participationRate: Double
}

struct ContactInteraction: Identifiable {
    let id = UUID()
    let contact: String
    let totalMessages: Int
}

struct SenderMessageCount: Identifiable {
    let id = UUID()
    let sender: String
    let messageCount: Int
    let percentage: Double
}

struct PersonActivityDataPoint: Identifiable {
    let id = UUID()
    let intervalStart: Date
    let dmMessages: Int
    let totalInteractions: Int
}

// MARK: - MessagesAnalysisView
struct MessagesAnalysisView: View {
    @State private var messages: [Message] = []
    @State private var activityData: [ActivityDataPoint] = []
    @State private var activityLineData: [ActivityLineDataPoint] = []
    @State private var sentCounts: [Date: Int] = [:]
    @State private var recCounts: [Date: Int] = [:]
    @State private var averageSent: Double = 0.0
    @State private var timeActivityData: [TimeActivityDataPoint] = []
    @State private var groupChatParticipationData: [GroupChatParticipation] = []
    @State private var groupChatCounts: [String: Int] = [:]
    @State private var contactCounts: [String: Int] = [:]
    @State private var totalInteractionsData: [ContactInteraction] = []
    @State private var specificGCData: [SenderMessageCount] = []
    @State private var personLineData: [PersonLineDataPoint] = []
    @State private var specificPersonData: [PersonActivityDataPoint] = []
    @State var targetGC = ""
    @State var targetContact = ""
   
    var body: some View {
        
        ScrollView {
            VStack(spacing: 30) {
                lifetimeActivityChart
                sentMessagesAverageChart
                timeOfDayActivityCharts
                groupChatParticipationChart
                topGroupChatsChart
                topContactsChart
                topContactsTotalInteractionsChart
                specificGroupChatPieChart
                specificPersonActivityChart
            }
            .padding()
        }
        .onAppear {
            print("working")
            loadData()
        }
    }
   
    // MARK: - Charts and Views
   
    var lifetimeActivityChart: some View {
        VStack(alignment: .leading) {
            Text("Lifetime Activity: Messages Sent, Received, and Total (over 10 day intervals)")
                .font(.headline)
            
            Chart {
                ForEach(activityLineData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.intervalStart),
                        y: .value("Messages", dataPoint.count)
                    )
                    .foregroundStyle(by: .value("Message Type", dataPoint.messageType))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartForegroundStyleScale([
                "Sent": Color.blue,
                "Received": Color.orange,
                "Total": Color.green
            ])
            .chartLegend(position: .bottom)
            .chartXAxisLabel("Date")
            .chartYAxisLabel("Number of Messages")
            .frame(height: 300)
        }
    }





   
    var sentMessagesAverageChart: some View {
        VStack(alignment: .leading) {
            Text("Total Messages Sent in 10-Day Intervals and Average")
                .font(.headline)
            Chart {
                ForEach(sentCounts.sorted(by: { $0.key < $1.key }), id: \.key) { date, count in
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Sent", count)
                    )
                    .foregroundStyle(Color.blue)
                }
                RuleMark(y: .value("Average", averageSent))
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
            }
            .chartXAxisLabel("Date")
            .chartYAxisLabel("Number of Sent Messages")
            .frame(height: 300)
        }
    }
   
    var timeOfDayActivityCharts: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Message Activity by Time of Day (20 minute segments)")
                .font(.headline)

            Chart {
                ForEach(timeActivityData) { dataPoint in
                    BarMark(
                        x: .value("Time Segment", dataPoint.timeSegment),
                        y: .value("Sent", dataPoint.sent)
                    )
                    .foregroundStyle(Color.blue)
                    
                    BarMark(
                        x: .value("Time Segment", dataPoint.timeSegment),
                        y: .value("Received", dataPoint.received)
                    )
                    .foregroundStyle(Color.orange)
                }
            }
            .chartXAxis {
                AxisMarks(preset: .aligned, position: .bottom) { _ in
                    AxisValueLabel(orientation: .vertical) // Rotate labels to be vertical
                }
            }
            .chartXAxisLabel("Time of Day")
            .chartYAxisLabel("Number of Messages")
            .frame(height: 300)
        }
    }

   
    var groupChatParticipationChart: some View {
        VStack(alignment: .leading) {
            Text("Top Group Chats by Participation Rate")
                .font(.headline)
            Chart {
                ForEach(groupChatParticipationData) { dataPoint in
                    BarMark(
                        x: .value("Participation Rate", dataPoint.participationRate),
                        y: .value("Group Chat", dataPoint.groupChatName)
                    )
                    .foregroundStyle(Color.blue)
                    .annotation(position: .trailing) {
                        Text("\(Int(dataPoint.participationRate * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .chartXAxisLabel("Participation Rate")
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading)
            }
            .frame(height: 600)
        }
    }
   
    var topGroupChatsChart: some View {
        VStack(alignment: .leading) {
            Text("Top Group Chats by Number of Messages")
                .font(.headline)
            Chart {
                ForEach(groupChatCounts.sorted(by: { $0.value > $1.value }).prefix(30), id: \.key) { name, count in
                    BarMark(
                        x: .value("Messages", count),
                        y: .value("Group Chat", name)
                    )
                    .foregroundStyle(Color.blue)
                    // Display group name on the left and exact message count on the right of each bar
                    .annotation(position: .trailing) {
                        HStack {
                            Text("\(count)") // Right-side annotation (Message Count)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .chartXAxisLabel("Number of Messages")
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading)
            }
            .frame(height: 600)
        }
    }

   
    var topContactsChart: some View {
        VStack(alignment: .leading) {
            Text("Top Contacts by Total Direct Messages")
                .font(.headline)
            Chart {
                ForEach(contactCounts.sorted(by: { $0.value > $1.value }).prefix(30), id: \.key) { contact, count in
                    BarMark(
                        x: .value("Messages", count),
                        y: .value("Contact", contact)
                    )
                    .foregroundStyle(Color.blue)
                    .annotation(position: .trailing) {
                        Text("\(count)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .chartXAxisLabel("Total Messages")
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading)
            }
            .frame(height: 600)
        }
    }
   
    var topContactsTotalInteractionsChart: some View {
        VStack(alignment: .leading) {
            Text("Top Contacts by Total Interactions (includes group chats)")
                .font(.headline)
            Chart {
                ForEach(totalInteractionsData.prefix(30)) { dataPoint in
                    BarMark(
                        x: .value("Messages", dataPoint.totalMessages),
                        y: .value("Contact", dataPoint.contact)
                    )
                    .foregroundStyle(Color.blue)
                    .annotation(position: .trailing) {
                        Text("\(dataPoint.totalMessages)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .chartXAxisLabel("Total Messages")
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading)
            }
            .frame(height: 600)
        }
    }
   
    var specificGroupChatPieChart: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Message Distribution by Sender in Group Chat:")
                    .foregroundColor(.black)
                Text(targetGC)
                    .foregroundColor(.red)
            }
            
            if specificGCData.isEmpty {
                Text("No data available for the specified group chat.")
                    .foregroundColor(.red)
            } else {
                Chart {
                    ForEach(specificGCData) { dataPoint in
                        SectorMark(
                            angle: .value("Messages", dataPoint.messageCount),
                            innerRadius: .ratio(0.5),
                            angularInset: 1
                        )
                        .foregroundStyle(by: .value("Sender", dataPoint.sender))
                        .annotation(position: .overlay) {
                            Text("\(dataPoint.sender): \(dataPoint.messageCount) (\(String(format: "%.1f", dataPoint.percentage))%)")
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 600)
            }
        }
    }





   
    var specificPersonActivityChart: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Message Activity with ")
                    .foregroundColor(.black)
                Text(targetContact)
                    .foregroundColor(.red)
                Text(" Over Time")
                    .foregroundColor(.black)
            }
            if personLineData.isEmpty {
                Text("No data available for the specified contact.")
                    .foregroundColor(.red)
            } else {
                Chart {
                    ForEach(personLineData) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.intervalStart),
                            y: .value("Messages", dataPoint.count)
                        )
                        .foregroundStyle(by: .value("Message Type", dataPoint.messageType))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartForegroundStyleScale([
                    "DM Messages": Color.blue,
                    "Total Interactions": Color.green
                ])
                .chartLegend(position: .bottom)
                .chartXAxisLabel("Date")
                .chartYAxisLabel("Number of Messages")
                .frame(height: 300)
            }
        }
    }

   
    // MARK: - Data Loading and Processing
   
    func loadData() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access the documents directory.")
            return
        }
        let fileURL = documentsDirectory.appendingPathComponent("ImessageAnalysisData/processed_messages.csv")
        print("location: \(fileURL)")
       
        do {
            let csvString = try String(contentsOf: fileURL, encoding: .utf8)
           
            self.messages = parseCSV(csvString: csvString)
            print("data loaded successfully")
           
            // Print available group chat names and contacts
            let groupChatNames = Set(messages.compactMap { $0.groupChatName })
                       
            let contactNames = Set(messages.map { $0.sender }).union(messages.map { $0.to })
                       
            processData()
        } catch {
            print("Error reading CSV file: \(error)")
            return
        }
    }
   
    func processData() {
        DispatchQueue.global().async {
            targetGC = LoadingManager.shared.targetGC
            targetContact = LoadingManager.shared.targetContact
            
            let sentMes = messages.filter { $0.sentByMe }
            let recMes = messages.filter { !$0.sentByMe }
            let groupChats = messages.filter { $0.groupChat }
            let individualMessages = messages.filter { !$0.groupChat }
            let groupingsize = 10 // days
            
            lifetimeActivityAnalysis(sentMes: sentMes, recMes: recMes, groupingsize: groupingsize)
            timeActivityAnalysis(sentMes: sentMes, recMes: recMes)
            groupChatParticipationAnalysis(groupChats: groupChats)
            topGroupChatsAnalysis(groupChats: groupChats)
            directMessagesAnalysis(individualMessages: individualMessages)
            totalInteractionsAnalysis(individualMessages: individualMessages, groupChats: groupChats)
            specificGroupChatAnalysis(groupChats: groupChats)
            specificPersonAnalysis(individualMessages: individualMessages, groupChats: groupChats)
            DispatchQueue.main.async {
                
                LoadingManager.shared.isLoading = false
            }
        }
    }
   
    // MARK: - Analysis Functions
    // MARK: - Analysis Functions
   
    func lifetimeActivityAnalysis(sentMes: [Message], recMes: [Message], groupingsize: Int) {
        let calendar = Calendar.current
        
        // Find the earliest and latest dates in the data
        guard let minDate = messages.min(by: { $0.readableTime < $1.readableTime })?.readableTime,
              let maxDate = messages.max(by: { $0.readableTime < $1.readableTime })?.readableTime else {
            print("No messages to analyze.")
            return
        }
        
        let referenceDate = calendar.startOfDay(for: minDate)
        // Generate all intervals from minDate to maxDate
        var allIntervalStarts: [Date] = []
        var intervalStart = referenceDate
        while intervalStart <= maxDate {
            allIntervalStarts.append(intervalStart)
            intervalStart = calendar.date(byAdding: .day, value: groupingsize, to: intervalStart) ?? intervalStart
        }
        // Count messages per interval
        for message in sentMes {
            let intervalStart = intervalLabel(for: message.readableTime, referenceDate: referenceDate, groupingsize: groupingsize)
            sentCounts[intervalStart, default: 0] += 1
        }
        for message in recMes {
            let intervalStart = intervalLabel(for: message.readableTime, referenceDate: referenceDate, groupingsize: groupingsize)
            recCounts[intervalStart, default: 0] += 1
        }
        // Ensure all intervals are represented in both sentCounts and recCounts
        for interval in allIntervalStarts {
            if sentCounts[interval] == nil {
                sentCounts[interval] = 0
            }
            if recCounts[interval] == nil {
                recCounts[interval] = 0
            }
        }
        // Create ActivityDataPoints from aligned intervals
        var tempActivityData: [ActivityDataPoint] = []
        for interval in allIntervalStarts {
            let sent = sentCounts[interval] ?? 0
            let received = recCounts[interval] ?? 0
            let dataPoint = ActivityDataPoint(intervalStart: interval, sent: sent, received: received)
            tempActivityData.append(dataPoint)
        }
        self.activityData = tempActivityData.sorted(by: { $0.intervalStart < $1.intervalStart })
        // Calculate average sent messages
        let totalSentMessages = sentCounts.values.reduce(0, +)
        self.averageSent = Double(totalSentMessages) / Double(sentCounts.count)
        
        // Transform activityData into activityLineData
        var tempActivityLineData: [ActivityLineDataPoint] = []
        for dataPoint in self.activityData {
            tempActivityLineData.append(ActivityLineDataPoint(intervalStart: dataPoint.intervalStart, messageType: "Sent", count: dataPoint.sent))
            tempActivityLineData.append(ActivityLineDataPoint(intervalStart: dataPoint.intervalStart, messageType: "Received", count: dataPoint.received))
            tempActivityLineData.append(ActivityLineDataPoint(intervalStart: dataPoint.intervalStart, messageType: "Total", count: dataPoint.total))
        }
        self.activityLineData = tempActivityLineData
    }


    // Helper function to align dates to intervals
    private func intervalLabel(for date: Date, referenceDate: Date, groupingsize: Int) -> Date {
        let calendar = Calendar.current
        let daysSinceReference = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
        let intervalIndex = daysSinceReference / groupingsize
        return calendar.date(byAdding: .day, value: intervalIndex * groupingsize, to: referenceDate) ?? referenceDate
    }









   
    func timeActivityAnalysis(sentMes: [Message], recMes: [Message]) {
        let timegroup = 20 // minutes
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
       
        var sentCounts: [String: Int] = [:]
        var recCounts: [String: Int] = [:]
       
        // Sent Messages
        for message in sentMes {
            let roundedDate = message.readableTime.rounded(to: TimeInterval(timegroup * 60))
            let timeString = dateFormatter.string(from: roundedDate)
            sentCounts[timeString, default: 0] += 1
        }
       
        // Received Messages
        for message in recMes {
            let roundedDate = message.readableTime.rounded(to: TimeInterval(timegroup * 60))
            let timeString = dateFormatter.string(from: roundedDate)
            recCounts[timeString, default: 0] += 1
        }
       
        // Prepare Time Activity Data
        let allTimeSegments = Set(sentCounts.keys).union(recCounts.keys).sorted()
        var tempTimeActivityData: [TimeActivityDataPoint] = []
        for timeSegment in allTimeSegments {
            let sent = sentCounts[timeSegment] ?? 0
            let received = recCounts[timeSegment] ?? 0
            let dataPoint = TimeActivityDataPoint(timeSegment: timeSegment, sent: sent, received: received)
            tempTimeActivityData.append(dataPoint)
        }
        self.timeActivityData = tempTimeActivityData.sorted(by: { $0.timeSegment < $1.timeSegment })
    }
   
    func groupChatParticipationAnalysis(groupChats: [Message]) {
        let topnumGC = 30
        let groupChatMessages = groupChats.compactMap { $0.groupChatName }
        let groupChatCountsDict = Dictionary(grouping: groupChatMessages, by: { $0 }).mapValues { $0.count }
        let sortedGroupChatCounts = groupChatCountsDict.sorted(by: { $0.value > $1.value }).prefix(topnumGC)
       
        var tempParticipationData: [GroupChatParticipation] = []
        for (name, _) in sortedGroupChatCounts {
            let gcMessages = messages.filter { $0.groupChatName == name }
            let sentGcMessages = gcMessages.filter { $0.sentByMe }
            let participationRate = Double(sentGcMessages.count) / Double(gcMessages.count)
            let dataPoint = GroupChatParticipation(groupChatName: name, participationRate: participationRate)
            tempParticipationData.append(dataPoint)
        }
        self.groupChatParticipationData = tempParticipationData.sorted(by: { $0.participationRate > $1.participationRate })
    }
   
    func topGroupChatsAnalysis(groupChats: [Message]) {
        let groupChatMessages = groupChats.compactMap { $0.groupChatName }
        self.groupChatCounts = Dictionary(grouping: groupChatMessages, by: { $0 }).mapValues { $0.count }
    }
   
    func directMessagesAnalysis(individualMessages: [Message]) {
        let contacts = individualMessages.map { $0.to }
        self.contactCounts = Dictionary(grouping: contacts, by: { $0 }).mapValues { $0.count }
    }
   
    func totalInteractionsAnalysis(individualMessages: [Message], groupChats: [Message]) {
        let dmCountsDict = Dictionary(grouping: individualMessages.map { $0.to }, by: { $0 }).mapValues { $0.count }
        let groupChatMessages = groupChats
       
        let groupChatCountsDict = Dictionary(grouping: groupChatMessages.map { $0.sender }, by: { $0 }).mapValues { $0.count }
        var totalInteractionsDict: [String: Int] = [:]
       
        for (contact, dmCount) in dmCountsDict {
            let groupChatCount = groupChatCountsDict[contact] ?? 0
            totalInteractionsDict[contact] = dmCount + groupChatCount
        }
       
        var tempTotalInteractionsData: [ContactInteraction] = []
        for (contact, totalMessages) in totalInteractionsDict {
            let dataPoint = ContactInteraction(contact: contact, totalMessages: totalMessages)
            tempTotalInteractionsData.append(dataPoint)
        }
        self.totalInteractionsData = tempTotalInteractionsData.sorted(by: { $0.totalMessages > $1.totalMessages })
    }
   
    func specificGroupChatAnalysis(groupChats: [Message]) {
        let groupChatMessages = groupChats.filter { $0.groupChatName == targetGC }
        let totalMessages = groupChatMessages.count
        let senderCounts = Dictionary(grouping: groupChatMessages.map { $0.sender }, by: { $0 }).mapValues { $0.count }
        
        var tempSpecificGCData: [SenderMessageCount] = []
        for (sender, count) in senderCounts {
            let percentage = Double(count) / Double(totalMessages) * 100
            let dataPoint = SenderMessageCount(sender: sender, messageCount: count, percentage: percentage)
            tempSpecificGCData.append(dataPoint)
        }
        
        self.specificGCData = tempSpecificGCData.sorted(by: { $0.messageCount > $1.messageCount })
    }

   
    func specificPersonAnalysis(individualMessages: [Message], groupChats: [Message]) {
        let groupingsize = 10 // days
        let calendar = Calendar.current
        guard let minDate = messages.min(by: { $0.readableTime < $1.readableTime })?.readableTime,
              let maxDate = messages.max(by: { $0.readableTime < $1.readableTime })?.readableTime else {
            print("No messages to analyze.")
            return
        }
        let referenceDate = calendar.startOfDay(for: minDate)
        func intervalLabel(for date: Date) -> Date {
            let daysSinceReference = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
            let intervalIndex = daysSinceReference / groupingsize
            return calendar.date(byAdding: .day, value: intervalIndex * groupingsize, to: referenceDate) ?? referenceDate
        }
        let dmMessages = individualMessages.filter { $0.to == targetContact }
        let groupChatMessagesFromTarget = groupChats.filter { $0.sender == targetContact }
        let targetGroupChats = Set(groupChatMessagesFromTarget.compactMap { $0.groupChatName })
        let groupChatMessagesFromMe = groupChats.filter { $0.sentByMe && targetGroupChats.contains($0.groupChatName ?? "") }
        var dmCounts: [Date: Int] = [:]
        var groupChatTargetCounts: [Date: Int] = [:]
        var groupChatMeCounts: [Date: Int] = [:]
        for message in dmMessages {
            let intervalStart = intervalLabel(for: message.readableTime)
            dmCounts[intervalStart, default: 0] += 1
        }
        for message in groupChatMessagesFromTarget {
            let intervalStart = intervalLabel(for: message.readableTime)
            groupChatTargetCounts[intervalStart, default: 0] += 1
        }
        for message in groupChatMessagesFromMe {
            let intervalStart = intervalLabel(for: message.readableTime)
            groupChatMeCounts[intervalStart, default: 0] += 1
        }
        var intervalStart = intervalLabel(for: minDate)
        while intervalStart <= maxDate {
            if dmCounts[intervalStart] == nil {
                dmCounts[intervalStart] = 0
            }
            if groupChatTargetCounts[intervalStart] == nil {
                groupChatTargetCounts[intervalStart] = 0
            }
            if groupChatMeCounts[intervalStart] == nil {
                groupChatMeCounts[intervalStart] = 0
            }
            intervalStart = calendar.date(byAdding: .day, value: groupingsize, to: intervalStart) ?? intervalStart
        }
        let allIntervalStarts = Set(dmCounts.keys)
            .union(groupChatTargetCounts.keys)
            .union(groupChatMeCounts.keys)
            .sorted()
        var tempPersonActivityData: [PersonActivityDataPoint] = []
        var tempPersonLineData: [PersonLineDataPoint] = []
        
        for intervalStart in allIntervalStarts {
            let dmCount = dmCounts[intervalStart] ?? 0
            let groupChatTargetCount = groupChatTargetCounts[intervalStart] ?? 0
            let groupChatMeCount = groupChatMeCounts[intervalStart] ?? 0
            let totalInteractions = dmCount + groupChatTargetCount + groupChatMeCount
            let dataPoint = PersonActivityDataPoint(intervalStart: intervalStart, dmMessages: dmCount, totalInteractions: totalInteractions)
            tempPersonActivityData.append(dataPoint)
            
            // Add line data points for each type
            tempPersonLineData.append(PersonLineDataPoint(intervalStart: intervalStart, messageType: "DM Messages", count: dmCount))
            tempPersonLineData.append(PersonLineDataPoint(intervalStart: intervalStart, messageType: "Total Interactions", count: totalInteractions))
        }
        self.specificPersonData = tempPersonActivityData.sorted(by: { $0.intervalStart < $1.intervalStart })
        self.personLineData = tempPersonLineData
    }





    // MARK: - Helper Functions
    @State var skiplinecount = 0

    func parseCSV(csvString: String) -> [Message] {
        var messages: [Message] = []
        let lines = csvString.components(separatedBy: .newlines)
        
        guard let headerLine = lines.first else {
            print("CSV is empty")
            return messages
        }
        
        let headers = parseCSVRow(headerLine) // Use parseCSVRow to handle quoted fields
        
        // Ensure headers match expected columns
        guard let readableTimeIndex = headers.firstIndex(of: "Readable Time"),
              let sentByMeIndex = headers.firstIndex(of: "Sent by Me"),
              let groupChatIndex = headers.firstIndex(of: "Group Chat"),
              let groupChatNameIndex = headers.firstIndex(of: "Group Chat Name"),
              let senderIndex = headers.firstIndex(of: "Sender"),
              let toIndex = headers.firstIndex(of: "To") else {
            print("CSV headers are missing required columns.")
            return messages
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Adjust to your date format
        
        for line in lines.dropFirst() {
            let columns = parseCSVRow(line) // Use parseCSVRow here to handle commas within quotes
            
            // Check if the row matches the expected header column count
            if columns.count != headers.count {
                print("Skipping malformed line: \(line)")
                skiplinecount += 1
                print("Skipped \(skiplinecount) lines.")
                continue
            }
            
            // Extract values from each column based on header indices
            let readableTimeString = columns[readableTimeIndex]
            let sentByMeString = columns[sentByMeIndex]
            let groupChatString = columns[groupChatIndex]
            let groupChatNameString = columns[groupChatNameIndex].isEmpty ? nil : columns[groupChatNameIndex]
            let senderString = columns[senderIndex].isEmpty ? "Unknown" : columns[senderIndex]
            let toString = columns[toIndex].isEmpty ? "Unknown" : columns[toIndex]
            
            // Convert date string to Date object
            guard let readableTime = dateFormatter.date(from: readableTimeString) else {
                print("Skipping line with invalid date: \(line)")
                continue
            }
            
            // Parse boolean fields
            let sentByMe = (sentByMeString == "1")
            let groupChat = (groupChatString == "1")
            
            // Create Message instance and add to array
            let message = Message(
                readableTime: readableTime,
                sentByMe: sentByMe,
                groupChat: groupChat,
                groupChatName: groupChatNameString,
                sender: senderString,
                to: toString
            )
            messages.append(message)
        }
        
        return messages
    }
    func parseCSVRow(_ row: String) -> [String] {
        var result = [String]()
        var currentField = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle() // Toggle insideQuotes on each quote
            } else if char == "," && !insideQuotes {
                // End of field if not inside quotes
                result.append(currentField)
                currentField = ""
            } else {
                // Append character to current field
                currentField.append(char)
            }
        }
        
        // Append the last field
        result.append(currentField)
        
        // Trim spaces and remove extra quotes around fields
        return result.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }





}

// MARK: - Extensions
extension Date {
    func rounded(to interval: TimeInterval) -> Date {
        let timeInterval = self.timeIntervalSinceReferenceDate
        let roundedInterval = (timeInterval / interval).rounded() * interval
        return Date(timeIntervalSinceReferenceDate: roundedInterval)
    }
}


  
   

