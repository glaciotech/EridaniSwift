//
//  Log.swift
//
//
//  Created by Peter Liddle on 4/25/25.
//
import OSLog

public struct Log {
    // Define a subsystem and category
    static let subsystem = "com.example.Ventus"
    static let category = "Prompts"

    // Create a logger with the given subsystem and category
    static let logger = OSLog(subsystem: subsystem, category: category)
    
    public static func debug(_ text: String) {
        os_log(.debug, log: logger, "%{public}@", text)
    }
    
    public static func info(_ text: String) {
        os_log(.info, log: logger, "%{public}@", text)
    }
    
    public  static func error(_ text: String) {
        os_log(.error, log: logger, "%{public}@", text)
    }
}
