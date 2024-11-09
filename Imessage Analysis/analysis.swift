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

struct TimeActivityDataPoint: Identifiable {
    let id = UUID()
    let timeSegment: String
    let sent: Int
    let received: Int
    var total: Int {
        return sent + received
    }
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
    @State private var sentCounts: [Date: Int] = [:]
    @State private var recCounts: [Date: Int] = [:]
    @State private var averageSent: Double = 0.0
    @State private var timeActivityData: [TimeActivityDataPoint] = []
    @State private var groupChatParticipationData: [GroupChatParticipation] = []
    @State private var groupChatCounts: [String: Int] = [:]
    @State private var contactCounts: [String: Int] = [:]
    @State private var totalInteractionsData: [ContactInteraction] = []
    @State private var specificGCData: [SenderMessageCount] = []
    @State private var specificPersonData: [PersonActivityDataPoint] = []
   
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
            Text("Lifetime Activity: Messages Sent, Received, and Total")
                .font(.headline)
            Chart {
                ForEach(activityData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.intervalStart),
                        y: .value("Sent", dataPoint.sent)
                    )
                    .foregroundStyle(Color.blue)
                   
                    LineMark(
                        x: .value("Date", dataPoint.intervalStart),
                        y: .value("Received", dataPoint.received)
                    )
                    .foregroundStyle(Color.orange)
                   
                    LineMark(
                        x: .value("Date", dataPoint.intervalStart),
                        y: .value("Total", dataPoint.total)
                    )
                    .foregroundStyle(Color.green)
                }
            }
            .chartXAxisLabel("Date")
            .chartYAxisLabel("Number of Messages")
            .frame(height: 300)
        }
    }
   
    var sentMessagesAverageChart: some View {
        VStack(alignment: .leading) {
            Text("Total Messages Sent in Intervals with Average")
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
            Text("Message Activity by Time of Day")
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
                    .annotation(position: .trailing) {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(.gray)
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
                        Text(contact)
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
                        Text(dataPoint.contact)
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
            Text("Message Distribution by Sender in Group Chat")
                .font(.headline)
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
                            Text("\(dataPoint.sender): \(dataPoint.messageCount)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 400)
            }
        }
    }
   
    var specificPersonActivityChart: some View {
        VStack(alignment: .leading) {
            Text("Message Activity with Specific Person Over Time")
                .font(.headline)
            if specificPersonData.isEmpty {
                Text("No data available for the specified contact.")
                    .foregroundColor(.red)
            } else {
                Chart {
                    ForEach(specificPersonData) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.intervalStart),
                            y: .value("DM Messages", dataPoint.dmMessages)
                        )
                        .foregroundStyle(Color.blue)
                       
                        LineMark(
                            x: .value("Date", dataPoint.intervalStart),
                            y: .value("Total Interactions", dataPoint.totalInteractions)
                        )
                        .foregroundStyle(Color.green)
                    }
                }
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
        let fileURL = documentsDirectory.appendingPathComponent("MyAppData/processed_messages.csv")
        print("location: \(fileURL)")
       
        do {
            let csvString = try String(contentsOf: fileURL, encoding: .utf8)
           
            self.messages = parseCSV(csvString: csvString)
            print("data loaded successfully")
           
            // Print available group chat names and contacts
            let groupChatNames = Set(messages.compactMap { $0.groupChatName })
            print("Available group chat names:")
            for name in groupChatNames {
                print(name)
            }
           
            let contactNames = Set(messages.map { $0.sender }).union(messages.map { $0.to })
            print("Available contact names:")
            for name in contactNames {
                print(name)
            }
           
            processData()
        } catch {
            print("Error reading CSV file: \(error)")
            return
        }
    }
   
    func processData() {
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
    }
   
    // MARK: - Analysis Functions
    // MARK: - Analysis Functions
   
    func lifetimeActivityAnalysis(sentMes: [Message], recMes: [Message], groupingsize: Int) {
        let calendar = Calendar.current
        guard let minDate = messages.min(by: { $0.readableTime < $1.readableTime })?.readableTime else {
            print("No messages to analyze.")
            return
        }
       
        let referenceDate = minDate
       
        func intervalLabel(for date: Date) -> Date {
            let daysSinceReference = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
            let intervalIndex = daysSinceReference / groupingsize
            guard let intervalStartDate = calendar.date(byAdding: .day, value: intervalIndex * groupingsize, to: referenceDate) else {
                return referenceDate
            }
            return intervalStartDate
        }
       
        // Sent Messages
        for message in sentMes {
            let intervalStart = intervalLabel(for: message.readableTime)
            sentCounts[intervalStart, default: 0] += 1
        }
       
        // Received Messages
        for message in recMes {
            let intervalStart = intervalLabel(for: message.readableTime)
            recCounts[intervalStart, default: 0] += 1
        }
       
        // Prepare Activity Data
        let allIntervalStarts = Set(sentCounts.keys).union(recCounts.keys).sorted()
        var tempActivityData: [ActivityDataPoint] = []
        for intervalStart in allIntervalStarts {
            let sent = sentCounts[intervalStart] ?? 0
            let received = recCounts[intervalStart] ?? 0
            let dataPoint = ActivityDataPoint(intervalStart: intervalStart, sent: sent, received: received)
            tempActivityData.append(dataPoint)
        }
        self.activityData = tempActivityData.sorted(by: { $0.intervalStart < $1.intervalStart })
       
        // Average Sent Messages
        let totalSentMessages = sentCounts.values.reduce(0, +)
        self.averageSent = Double(totalSentMessages) / Double(sentCounts.count)
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
        let targetGC = "XC Juniors" // Replace with your target group chat name
        let groupChatMessages = groupChats.filter { $0.groupChatName == targetGC }
        let senderCounts = Dictionary(grouping: groupChatMessages.map { $0.sender }, by: { $0 }).mapValues { $0.count }
       
        var tempSpecificGCData: [SenderMessageCount] = []
        for (sender, count) in senderCounts {
            let dataPoint = SenderMessageCount(sender: sender, messageCount: count)
            tempSpecificGCData.append(dataPoint)
        }
        self.specificGCData = tempSpecificGCData
    }
   
    func specificPersonAnalysis(individualMessages: [Message], groupChats: [Message]) {
        let target = "rumana" // Replace with your target contact name
        let groupingsize = 10 // days
        let calendar = Calendar.current
        guard let minDate = messages.min(by: { $0.readableTime < $1.readableTime })?.readableTime else {
            return
        }
        let referenceDate = minDate
       
        func intervalLabel(for date: Date) -> Date {
            let daysSinceReference = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
            let intervalIndex = daysSinceReference / groupingsize
            guard let intervalStartDate = calendar.date(byAdding: .day, value: intervalIndex * groupingsize, to: referenceDate) else {
                return referenceDate
            }
            return intervalStartDate
        }
       
        // Direct Messages with Target
        let dmMessages = individualMessages.filter { $0.to == target }
       
        // Group Chat Messages from Target
        let groupChatMessagesFromTarget = groupChats.filter { $0.sender == target }
       
        // Group Chats where Target Participated
        let targetGroupChats = Set(groupChatMessagesFromTarget.compactMap { $0.groupChatName })
       
        // Your Messages in those Group Chats
        let groupChatMessagesFromMe = groupChats.filter { $0.sentByMe && targetGroupChats.contains($0.groupChatName ?? "") }
       
        var dmCounts: [Date: Int] = [:]
        for message in dmMessages {
            let intervalStart = intervalLabel(for: message.readableTime)
            dmCounts[intervalStart, default: 0] += 1
        }
       
        var groupChatTargetCounts: [Date: Int] = [:]
        for message in groupChatMessagesFromTarget {
            let intervalStart = intervalLabel(for: message.readableTime)
            groupChatTargetCounts[intervalStart, default: 0] += 1
        }
       
        var groupChatMeCounts: [Date: Int] = [:]
        for message in groupChatMessagesFromMe {
            let intervalStart = intervalLabel(for: message.readableTime)
            groupChatMeCounts[intervalStart, default: 0] += 1
        }
       
        let allIntervalStarts = Set(dmCounts.keys)
            .union(groupChatTargetCounts.keys)
            .union(groupChatMeCounts.keys)
            .sorted()
       
        var tempPersonActivityData: [PersonActivityDataPoint] = []
        for intervalStart in allIntervalStarts {
            let dmCount = dmCounts[intervalStart] ?? 0
            let groupChatTargetCount = groupChatTargetCounts[intervalStart] ?? 0
            let groupChatMeCount = groupChatMeCounts[intervalStart] ?? 0
            let totalInteractions = dmCount + groupChatTargetCount + groupChatMeCount
            let dataPoint = PersonActivityDataPoint(intervalStart: intervalStart, dmMessages: dmCount, totalInteractions: totalInteractions)
            tempPersonActivityData.append(dataPoint)
        }
        self.specificPersonData = tempPersonActivityData.sorted(by: { $0.intervalStart < $1.intervalStart })
    }
    // MARK: - Helper Functions
   
    func parseCSV(csvString: String) -> [Message] {
        var messages: [Message] = []
        let lines = csvString.components(separatedBy: .newlines)
       
        guard let headerLine = lines.first else {
            print("CSV is empty")
            return messages
        }
        let headers = headerLine.components(separatedBy: ",")
       
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
            let columns = line.components(separatedBy: ",")
            if columns.count != headers.count {
                print("Skipping malformed line: \(line)")
                continue
            }
           
            let readableTimeString = columns[readableTimeIndex]
            let sentByMeString = columns[sentByMeIndex]
            let groupChatString = columns[groupChatIndex]
            let groupChatNameString = columns[groupChatNameIndex].isEmpty ? nil : columns[groupChatNameIndex]
            let senderString = columns[senderIndex].isEmpty ? "Unknown" : columns[senderIndex]
            let toString = columns[toIndex].isEmpty ? "Unknown" : columns[toIndex]
           
            guard let readableTime = dateFormatter.date(from: readableTimeString) else {
                print("Skipping line with invalid date: \(line)")
                continue
            }
           
            let sentByMe = (sentByMeString == "1")
            let groupChat = (groupChatString == "1")
           
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
}

// MARK: - Extensions
extension Date {
    func rounded(to interval: TimeInterval) -> Date {
        let timeInterval = self.timeIntervalSinceReferenceDate
        let roundedInterval = (timeInterval / interval).rounded() * interval
        return Date(timeIntervalSinceReferenceDate: roundedInterval)
    }
}


  
   

