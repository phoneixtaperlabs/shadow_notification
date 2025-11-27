import Foundation
import os.log

// MARK: - AutopilotLogger Actor (Main Definition)
actor ShadowNotiLogger {
    
    // MARK: - Singleton & Configuration
    private static var _shared: ShadowNotiLogger?
    
    static var shared: ShadowNotiLogger {
        guard let logger = _shared else {
            fatalError("AutopilotLogger.configure() must be called before accessing AutopilotLogger.shared")
        }
        return logger
    }
    
    static func configure(subsystem: String,
                          category: String,
                          logDirectory: URL? = nil,
                          retentionDays: Int = 30,
                          minimumLogLevel: LogType = .debug) {
        if _shared == nil {
            let logger = ShadowNotiLogger(subsystem: subsystem,
                                       category: category,
                                       logDirectory: logDirectory,
                                       retentionDays: retentionDays,
                                       minimumLogLevel: minimumLogLevel)
            _shared = logger
            
            // 초기화 후 바로 설정 작업 수행
            Task {
                await logger.setupLogger()
            }
        } else {
            print("Warning: AutopilotLogger already configured. Configuration can only be set once at startup.")
        }
    }
    
    // MARK: - Nested Types
    private struct LogEntry {
        let message: String
        let type: LogType
        let file: String
        let function: String
        let line: Int
    }
    
    enum LogType: String, Comparable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
        
        static func < (lhs: LogType, rhs: LogType) -> Bool {
            let order: [LogType] = [.debug, .info, .warning, .error]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    // MARK: - Properties
    private let osLog: OSLog
    private let logDirectory: URL
    private var currentLogFileURL: URL?
    private var logFileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    private let timestampFormatter: DateFormatter
    private let iso8601Formatter: ISO8601DateFormatter
    private let retentionDays: Int
    private var currentLogDate: String = ""
    private(set) var minimumLogLevel: LogType
    
    // AsyncStream Infrastructure
    private var logStreamContinuation: AsyncStream<LogEntry>.Continuation?
    private var consumerTask: Task<Void, Never>?
    
    // MARK: - Initialization & Deinitialization
    private init(subsystem: String,
                 category: String,
                 logDirectory: URL? = nil,
                 retentionDays: Int = 7,
                 minimumLogLevel: LogType = .debug) {
        
        self.osLog = OSLog(subsystem: subsystem, category: category)
        self.minimumLogLevel = minimumLogLevel
        self.retentionDays = retentionDays
        
        // Formatters 초기화
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter.timeZone = TimeZone.current
        
        self.timestampFormatter = DateFormatter()
        self.timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.timestampFormatter.timeZone = TimeZone.current
        
        self.iso8601Formatter = ISO8601DateFormatter()
        
        // Log Directory 설정
        let fileManager = FileManager.default
        if let customLogDirectory = logDirectory {
            self.logDirectory = customLogDirectory
        } else {
            self.logDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("com.taperlabs.shadow", isDirectory: true)
                .appendingPathComponent("logs", isDirectory: true)
        }
        
        // Directory 생성
        try? fileManager.createDirectory(at: self.logDirectory, withIntermediateDirectories: true)
        
        
        // 초기 파일 설정
        self.currentLogDate = self.dateFormatter.string(from: Date())
    }
    
    
    deinit {
        logStreamContinuation?.finish()
        try? self.logFileHandle?.close()
        os_log("AutopilotLogger deinitialized", log: self.osLog, type: .info)
    }
    
    /// 스트림에서 받은 로그를 처리하는 내부 메서드
    private func logInternal(entry: LogEntry) {
        guard entry.type >= minimumLogLevel else { return }
        writeToFile(entry: entry)
    }
    
    private func setupLogger() {
        // AsyncStream 및 Consumer Task 설정
        let (logStream, continuation) = AsyncStream.makeStream(of: LogEntry.self, bufferingPolicy: .bufferingNewest(1000))
        self.logStreamContinuation = continuation
        
        // Consumer Task 설정
        self.consumerTask = Task {
            for await entry in logStream {
                print("Entry 입니다~~~ \(entry)")
                self.logInternal(entry: entry)
            }
        }
        
        // 파일 설정
        self.setupLogFile()
        self.cleanupOldLogFiles()
        
        // 초기화 로그 기록
        self.log(message: "AutopilotLogger setup completed with minimumLogLevel: \(minimumLogLevel.rawValue), retentionDays: \(retentionDays)",
                 type: .info, file: #file, function: #function, line: #line)
    }
}

// MARK: - Public Logging API
extension ShadowNotiLogger {
    
    /// 내부적으로 사용되는 기본 로그 메서드. 로그 엔트리를 비동기 스트림으로 전달합니다.
    func log(message: String,
             type: LogType,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        // 1. OSLog는 즉시 기록 (Thread-safe)
        os_log("%{public}@", log: self.osLog, type: type.osLogType, message)
        
        // 2. 파일 로깅은 LogEntry를 만들어 AsyncStream으로 보냅니다.
        let entry = LogEntry(message: message, type: type, file: file, function: function, line: line)
        logStreamContinuation?.yield(entry)
    }
    
    nonisolated func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Task {
            await log(message: message, type: .debug, file: file, function: function, line: line)
        }
    }
    
    nonisolated func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Task {
            await log(message: message, type: .info, file: file, function: function, line: line)
        }
    }
    
    nonisolated func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Task {
            await log(message: message, type: .warning, file: file, function: function, line: line)
        }
    }
    
    nonisolated func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Task {
            await log(message: message, type: .error, file: file, function: function, line: line)
        }
    }
}

// MARK: - Actor State & Control
extension ShadowNotiLogger {
    
    /// 로그 레벨을 동적으로 변경합니다.
    func updateMinimumLogLevel(_ level: LogType) {
        minimumLogLevel = level
        log(message: "Minimum log level changed to: \(level.rawValue)",
            type: .info, file: #file, function: #function, line: #line)
    }
    
    /// 앱 종료 전, 버퍼에 남아있는 모든 로그를 처리하고 파일을 닫습니다.
    func shutdown() async {
        logStreamContinuation?.finish()
        await consumerTask?.value
        try? self.logFileHandle?.close()
        self.logFileHandle = nil
    }
}

// MARK: - Private File Management
extension ShadowNotiLogger {
    
    private func writeToFile(entry: LogEntry) {
        rotateLogFileIfNeeded()
        
        guard let logFileHandle = self.logFileHandle else {
            print("Log file handle is nil. Retrying setup...")
            setupLogFile()
            // 핸들 재설정 후 다시 시도 (재귀 호출 대신 guard로 안전하게 처리)
            guard let newHandle = self.logFileHandle else {
                print("Failed to recreate log file handle. Log will be dropped.")
                return
            }
            // 핸들 생성 성공 시, 파일에 쓰기
            do {
                try writeEntry(entry, to: newHandle)
            } catch {
                print("Failed to write to new log file handle: \(error)")
            }
            return
        }
        
        do {
            try writeEntry(entry, to: logFileHandle)
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }
    
    private func writeEntry(_ entry: LogEntry, to handle: FileHandle) throws {
        let utcTimestamp = iso8601Formatter.string(from: Date())
        let localTimestamp = timestampFormatter.string(from: Date())
        let threadID = Thread.current.hashValue
        
        let logMessage = "[UTC: \(utcTimestamp)] [LOCAL: \(localTimestamp)] [\(entry.type.rawValue)] [Thread: \(threadID)] [\(entry.function)] \(entry.message)\n"
        
        guard let data = logMessage.data(using: .utf8) else {
            print("Failed to encode log entry to UTF-8")
            return
        }
        
        try handle.write(contentsOf: data)
    }
    
    func setupLogFile() {
        // Close existing handle
        try? logFileHandle?.close()
        logFileHandle = nil
        
        // Create log file URL for current date
        let logFileName = "\(currentLogDate)-autopilot.log"
        currentLogFileURL = logDirectory.appendingPathComponent(logFileName)
        
        guard let logFileURL = currentLogFileURL else {
            print("Failed to create log file URL")
            return
        }
        
        let fileManager = FileManager.default
        
        // Create log file if it doesn't exist
        let fileExists = fileManager.fileExists(atPath: logFileURL.path)
        if !fileExists {
            let success = fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
            if !success {
                print("Failed to create log file at path: \(logFileURL.path)")
                return
            }
        }
        
        // Open file handle for writing
        do {
            logFileHandle = try FileHandle(forWritingTo: logFileURL)
            logFileHandle?.seekToEndOfFile()
            
            // Write header if this is a new file
            if !fileExists || logFileHandle?.offsetInFile == 0 {
                let header = "--- Screenshot Module Log File: \(currentLogDate) ---\n"
                if let headerData = header.data(using: .utf8) {
                    try logFileHandle?.write(contentsOf: headerData)
                }
            }
        } catch {
            print("Failed to open log file: \(error)")
            logFileHandle = nil
        }
    }
    
    func rotateLogFileIfNeeded(force: Bool = false) {
        let today = dateFormatter.string(from: Date())
        
        // Check if we need to rotate (new day or force)
        if today != currentLogDate || force {
            let previousDate = currentLogDate
            currentLogDate = today
            
            print("Rotating log file from \(previousDate) to \(today)")
            
            // Setup new log file
            setupLogFile()
            
            // Clean up old files
            cleanupOldLogFiles()
        }
    }
    
    func cleanupOldLogFiles() {
        let fileManager = FileManager.default
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
            
            // DateFormatter는 파일 이름 파싱용으로 재사용
            let fileDateFormatter = DateFormatter()
            fileDateFormatter.dateFormat = "yyyy-MM-dd"
            
            for fileURL in fileURLs where fileURL.pathExtension == "log" {
                // 파일 이름에서 날짜 부분 추출 (e.g., "2025-08-26")
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                let dateString = String(fileName.split(separator: "-").prefix(3).joined(separator: "-"))
                
                if let fileDate = fileDateFormatter.date(from: dateString) {
                    if fileDate < cutoffDate {
                        do {
                            try fileManager.removeItem(at: fileURL)
                            print("Deleted old log file: \(fileURL.lastPathComponent)")
                        } catch {
                            print("Failed to delete old log file \(fileURL.lastPathComponent): \(error)")
                        }
                    }
                }
            }
        } catch {
            print("Failed to cleanup old log files: \(error)")
        }
    }
}
