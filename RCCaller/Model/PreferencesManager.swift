//
//  PreferencesManager.swift
//  RCCaller
//
//  Created by Vogel, Peter on 6/18/20.
//  Copyright © 2020 Vogel, Peter. All rights reserved.
//

import Foundation
class PreferencesManager {
    
    static let shared = PreferencesManager()
    private let userDefaults = UserDefaults.standard
    
    private init() {
        if (!userDefaults.bool(forKey: "initialized")) {
            userDefaults.set(false, forKey: "useTilt")
            userDefaults.set(false, forKey: "repeatOnly")
            userDefaults.set("Roll", forKey: "tiltAxis")
            userDefaults.set(15, forKey: "triggerAngle")
            userDefaults.set(5, forKey: "resetAngle")
            userDefaults.set("sportsman", forKey: "preferredSequence")
            userDefaults.set(true, forKey: "initialized")
        }
    }
    
    
    
    var useTilt:Bool {
        get {
            return userDefaults.bool(forKey: "useTilt")
        }
        set {
            userDefaults.set(newValue, forKey: "useTilt")
        }
    }
    
    var repeatOnly: Bool {
        get {
            return userDefaults.bool(forKey: "repeatOnly")
        }
        set {
            userDefaults.set(newValue, forKey: "repeatOnly")
        }
    }
    
    var tiltAxis:String {
        get {
            return userDefaults.string(forKey: "tiltAxis") ?? "roll"
        }
        set (newAxis) {
            userDefaults.set(newAxis, forKey: "tiltAxis")
        }
    }
    
    var triggerAngle:Int {
        get {
            return userDefaults.integer(forKey: "triggerAngle")
        }
        set (newAngle) {
            userDefaults.set(newAngle, forKey: "triggerAngle")
        }
    }
    
    var resetAngle:Int {
        get {
            return userDefaults.integer(forKey: "resetAngle")
        }
        set (newAngle) {
            userDefaults.set(newAngle, forKey: "resetAngle")
        }
    }
    
    var preferredSequence:String {
        get {
            return userDefaults.string(forKey: "preferredSequence") ?? "sportsman"
        }
        set (newSequence) {
            userDefaults.set(newSequence, forKey: "preferredSequence")
        }
    }
}
