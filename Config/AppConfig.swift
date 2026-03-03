// File: Config/AppConfig.swift
import Foundation

struct AppConfig {
    // MARK: - Base URL Configuration

    // Production API URL on Render
    static var baseURL: String {
        get {
            if let savedURL = UserDefaults.standard.string(forKey: "api_base_url"), !savedURL.isEmpty {
                return savedURL
            }
            // Default to production
            return productionURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "api_base_url")
        }
    }
    
    // Convenience URLs
    static var authLoginURL: URL {
        URL(string: "\(baseURL)/auth/login")!
    }
    
    static var authTokenURL: URL {
        URL(string: "\(baseURL)/auth/token")!
    }
    
    static var authRefreshURL: URL {
        URL(string: "\(baseURL)/auth/refresh")!
    }
    
    static var meURL: URL {
        // Keep using production for user profile (has full user data)
        URL(string: "\(baseURL)/me")!
    }
    
    static func meHistoryURL(limit: Int, offset: Int) -> URL {
        URL(string: "\(statsBaseURL)/me/history?limit=\(limit)&offset=\(offset)")!
    }

    static func meStatsURL(period: String = "all", offset: Int = 0) -> URL {
        URL(string: "\(statsBaseURL)/me/stats?period=\(period)&offset=\(offset)")!
    }
    
    static var devSyncURL: URL {
        URL(string: "\(baseURL)/dev/sync-now")!
    }

    static var syncNowURL: URL {
        URL(string: "\(statsBaseURL)/sync/now")!
    }

    static var syncStatusURL: URL {
        URL(string: "\(baseURL)/sync/status")!
    }

    // MARK: - Import Endpoints

    static var importsURL: URL {
        URL(string: "\(baseURL)/imports")!
    }

    static func importURL(id: String) -> URL {
        URL(string: "\(baseURL)/imports/\(id)")!
    }

    static func importUploadURL(id: String) -> URL {
        URL(string: "\(baseURL)/imports/\(id)/upload")!
    }

    // Presets for easy switching
    static let localhostURL = "http://127.0.0.1:3000"
    static let productionURL = "https://wrapped-api-5ybf.onrender.com"

    static var statsBaseURL: String {
        return productionURL
    }
}
