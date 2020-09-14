//
//  SequenceManager.swift
//  RCCaller
//
//  Created by Vogel, Peter on 6/24/20.
//  Copyright © 2020 Vogel, Peter. All rights reserved.
//

import Foundation

class Maneuver:Codable {
    var description: String = ""
    var kFactor: Int = 0
}

class Sequence: Codable {
    var _id: String?
    var name: String = ""
    var amaId: String = ""
    var year: String?
    var maneuvers: [Maneuver] = []
}

struct CatalogManeuver: Codable {
    var index: Int
    var _id: String
    var cat: String
    var description: String
    var direction: String
    var kfactor: Int
    var number: String
    var type:String
    var entryAlt: String
    var entryAtt: String
    var exitAlt: String
    var exitAtt: String
}

struct UnknownSequence: Codable {
    var error: String?
    var totalK: Int
    var maneuvers: [CatalogManeuver] = []
    var sixCount: Int?
    var fiveCount: Int?
    var arestiUrl: String?
    var arestiImage: String?
    var arestiRURL: String?
    var arestiRImage: String?
    var arestiPDF: String?
}

protocol SequencesObserver {
    func sequencesUpdatedNotification()
}

class SequenceManager {
    static let shared = SequenceManager()
    private let APIRoot = "https://www.faiunknowngenerator.com/sequence"
    var sequences: [Sequence] {
        get {
            return localSequences + serverSequences
        }
    }
    var serverSequences: [Sequence] = []
    var localSequences: [Sequence] = []
    private let userDefaults = UserDefaults.standard
    private lazy var observers = [SequencesObserver]()
    private let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    
    private init() {
        do {
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            print("created directory: \(support)")
        } catch {
            print("error creating support dir: \(error)")
        }
        loadSequences()
    }
    
    func addObserver(o:SequencesObserver) {
        observers.append(o);
    }
    
    func removeObserver(o:SequencesObserver) {
        if let idx = observers.firstIndex(where: {$0 as AnyObject === o as AnyObject}) {
            observers.remove(at: idx);
        }
    }
    
    private func writeSequences(_ sequences:[Sequence], toFile:String) throws -> String {
        let targetFile = support.appendingPathComponent(toFile)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let sequencesJson = try encoder.encode(sequences)
            if (!FileManager.default.fileExists(atPath: targetFile.path)) {
                FileManager.default.createFile(atPath: targetFile.path, contents: nil, attributes: nil)
            }
            let fileHandle = try FileHandle(forWritingTo: targetFile)
            fileHandle.write(sequencesJson)
            fileHandle.closeFile()
            print("Wrote sequences file at: \(targetFile)")
            return targetFile.path
        } catch {
            print("Error writing sequences file \(targetFile.path): \(error)")
            throw error
        }
    }
    
    private func saveLocalSequences() throws {
        do {
            try writeSequences(self.localSequences, toFile: "localSequences.json")
        } catch {
            print("Error writing local sequences file: \(error)")
            throw error
        }
    }
    
    private func writeServerSequenceCache() throws{
        do {
            try writeSequences(self.serverSequences, toFile: "serverSequencesCache.json")
        } catch {
            print("Error writing server sequences cache: \(error)")
            throw error
        }
    }
    
    private func readSequencesFromFile(fileName: String) throws ->[Sequence]  {
        let sequencesFile = support.appendingPathComponent(fileName)
        do {
            let sequencesFileHandle = try FileHandle(forReadingFrom: sequencesFile)
            let sequencesJson = sequencesFileHandle.readDataToEndOfFile()
            sequencesFileHandle.closeFile()
            if let sequencesJsonString = String(data:sequencesJson, encoding: .utf8) {
                print("Got sequences from \(fileName): \(sequencesJsonString)")
            }
            if let sequenceArray = try? JSONDecoder().decode([Sequence].self, from: sequencesJson) {
                return sequenceArray
            }
        } catch {
            print("Error reading \(fileName) for sequences: \(error)")
            throw error
        }
        return []
    }
    
    private func readLocalSequences() {
        do {
            self.localSequences = try readSequencesFromFile(fileName: "localSequences.json")
        } catch {
            print("Error reading local sequences")
            self.localSequences = []
        }
    }
    
    private func readCachedSequences() throws {
        self.serverSequences = try readSequencesFromFile(fileName: "serverSequencesCache.json")
    }
    
    private func fixAmaIds(_ sequences:[Sequence])->[Sequence] {
        return sequences.map({
            if ($0.amaId.contains("-")) {
                let tmp = $0
                let elements = $0.amaId.split(separator: "-")
                var newId = "archive:\(elements[0])"
                for i in 1..<elements.count-1 {
                    newId+="-\(elements[i])"
                }
                tmp.amaId = String(newId)
                tmp.year = String(elements[elements.count-1])
                //print("Changing \($0.amaId) to \(tmp.amaId) with year \(tmp.year)")
                return tmp
            }
            return $0
        })
    }
    
    private func notifyObservers() {
        for o in self.observers {
            o.sequencesUpdatedNotification()
        }
    }
    
    func loadSequences(forceUpdate:Bool = false) {
        var needsUpdate = false;
        if let lastUpdate = userDefaults.object(forKey:"lastSequenceUpdate") as? Date {
            let updateDelay:TimeInterval = lastUpdate.timeIntervalSinceNow
            print("time since last update: \(updateDelay)");
            if (updateDelay < (-48*60*60)) { // 48 hours ago, 2 days
                needsUpdate = true
            }
        } else {
            needsUpdate = true
        }
        readLocalSequences()
        //always attempt the cache even if we need to update it
        do {
            try readCachedSequences()
        } catch {
            print("Error reading cached server sequences: \(error)")
            needsUpdate = true
        }
        if (forceUpdate || needsUpdate) {
            if let url = URL.init(string:"\(APIRoot)/sequences") {
                let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
                    guard error == nil else {
                        print("\(error)")
                        return
                    }
                    guard let s = data else {
                        print("empty data")
                        return
                    }
                    if let sequences = try? JSONDecoder().decode([Sequence].self, from: s) {
                        self.serverSequences = self.fixAmaIds(sequences)
                        self.serverSequences = self.serverSequences.sorted(by: {
                            if ($0.amaId == $1.amaId) {
                                let year0 = $0.year ?? "0"
                                let year1 = $1.year ?? "1"
                                return year0 < year1
                            } else {
                                return $0.amaId < $1.amaId
                            }
                        })
                        //print(self.serverSequences)
                        do {
                            try self.writeServerSequenceCache()
                            self.userDefaults.setValue(Date(), forKey: "lastSequenceUpdate")
                        } catch {
                            print("Got error writing server sequences cache: \(error)")
                        }
                        self.notifyObservers()

                    }
                }
                task.resume()
            }
        } else {
            notifyObservers()
        }
    }
    
    private func sequenceFromUnknown(_ unknown:UnknownSequence) -> Sequence {
        let ret = Sequence()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        ret._id = UUID().uuidString
        ret.name = "Unknown: \(formatter.string(from: Date()))"
        ret.amaId = "local unk:\(ret.name)"
        ret.maneuvers = unknown.maneuvers.map({
            let newM = Maneuver()
            //let descriptionSuffix = "\(($0.entryAtt == "I") ? ", entry inverted" : "") \(($0.exitAtt == "I") ? ", exit inverted" : "")"
            //newM.description = "\($0.description)\(descriptionSuffix)"
            newM.description = $0.description
            newM.kFactor = $0.kfactor
            return newM
        })
        return ret
    }
    
    func getUnknownSequence(completionBlock:@escaping (Sequence)->Void) {
        if let url=URL.init(string:"\(APIRoot)/generate") {
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                guard error == nil else {
                    print("\(error)")
                    return
                }
                guard let s = data else {
                    print("empty data")
                    return
                }
                do {
                    print("decoding: \(s)")
                    let sequence = try JSONDecoder().decode(UnknownSequence.self, from: s)
                    print(sequence)
                    completionBlock(self.sequenceFromUnknown(sequence))
                } catch {
                    print ("error decoding unknown sequence: \(error)")
                }
            }
            task.resume()
        }
    }
    
    func copySequence(sequence: Sequence) throws {
        let tmpSequence = Sequence()
        tmpSequence._id = UUID().uuidString
        tmpSequence.amaId = "copy of \(sequence.amaId)"
        tmpSequence.name = "copy of \(sequence.name)"
        tmpSequence.year = sequence.year
        tmpSequence.maneuvers = sequence.maneuvers.map({return $0})
        localSequences.append(tmpSequence)
        try saveLocalSequences()
        notifyObservers()
    }
    
    func addLocalSequence(sequence:Sequence) throws {
        let tmpSequence = sequence
        if (sequence._id == nil) {
            tmpSequence._id = UUID().uuidString
        }
        guard localSequences.first(where: {$0._id == tmpSequence._id}) == nil else {
            print("attempt to add a sequence that is already in the list")
            return
        }
        localSequences.append(sequence)
        try saveLocalSequences()
        notifyObservers()
    }
    
    func saveSequence(sequence:Sequence) throws {
        if var sequenceToSave = localSequences.first(
            where: {
                sequence._id != nil && $0._id == sequence._id
            }) {
            sequenceToSave.maneuvers = sequence.maneuvers.map({return $0})
            sequenceToSave.amaId = sequence.amaId
            sequenceToSave.name = sequence.name
            sequenceToSave.year = sequence.year
            try saveLocalSequences()
            notifyObservers()
        } else {
            try addLocalSequence(sequence: sequence)
        }
        return
    }
    
    func deleteLocalSequence(localIndex:Int) throws {
        localSequences.remove(at: localIndex)
        try saveLocalSequences()
        notifyObservers()

    }
    
}
