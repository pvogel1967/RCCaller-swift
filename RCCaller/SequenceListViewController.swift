//
//  SequenceListViewController.swift
//  RCCaller
//
//  Created by Vogel, Peter on 7/7/20.
//  Copyright © 2020 Vogel, Peter. All rights reserved.
//

import UIKit

class SequenceListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SequencesObserver {
    
    
    @IBOutlet weak var tableView: UITableView!
    
    let sequenceManager = SequenceManager.shared
    
    override func viewDidLoad() {
        sequenceManager.addObserver(o: self)
    }
    
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("Should perform segue: \(identifier) sender is: \(sender)")
        if (identifier == "segAddSequence") {
            return true
        } else {
            guard let sequenceCell = sender as? UITableViewCell else {return false}
            guard let indexPath = tableView.indexPath(for: sequenceCell) else {return false}
            print("sender indexPath is \(indexPath)")
            if (indexPath.section == 0 && indexPath.row < sequenceManager.localSequences.count) {
                return true
            }
            
        }
        return false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "segAddSequence") {
            guard let destVC = segue.destination as? EditSequenceViewController else {return}
            var newSequence = Sequence()
            newSequence.name = "New Sequence"
            newSequence.amaId = "400"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            newSequence.year = formatter.string(from: Date())
            newSequence.maneuvers = []
            destVC.sequence = newSequence
        } else if (segue.identifier == "segEditSequence") {
            guard let sequenceCell = sender as? UITableViewCell else {return}
            guard let indexPath = tableView.indexPath(for: sequenceCell) else {return}
            guard indexPath.section == 0 else {return}
            guard indexPath.row < sequenceManager.localSequences.count else {return}
            guard let destVC = segue.destination as? EditSequenceViewController else {return}
            destVC.sequence = sequenceManager.localSequences[indexPath.row]
        }
    }
    
    //SequencesObserver
    func sequencesUpdatedNotification() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
        


    //tableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return "Standard Sequences"
        case 0:
            return "Locally Saved Sequences"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return sequenceManager.serverSequences.count
        case 0:
            return sequenceManager.localSequences.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sequenceNameCell", for: indexPath)
        var sequences = sequenceManager.serverSequences
        if indexPath.section == 0 {
            sequences = sequenceManager.localSequences
        }
        cell.textLabel?.text = sequences[indexPath.row].name
        return cell
    }

    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let section = indexPath.section
        let row = indexPath.row
        if (section == 1) { return nil}
        if (section == 0) {
            let deleteTitle = "Delete"
            let deleteAction = UITableViewRowAction(style: .destructive, title: deleteTitle) {(action, indexPath) in
                do {
                    try self.sequenceManager.deleteLocalSequence(localIndex: row)
                } catch {
                    //TODO
                    print("error deleting a local sequence")
                }
            }
            return [deleteAction]
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = "copy"
        let action = UIContextualAction(style:.normal, title: title, handler: {(action, view, completionHandler) in
            var sourceSequence = self.sequenceManager.serverSequences[0]
            if (indexPath.section == 0) {
                if (indexPath.row < self.sequenceManager.localSequences.count) {
                    sourceSequence = self.sequenceManager.localSequences[indexPath.row]
                }
            } else {
                if (indexPath.row < self.sequenceManager.serverSequences.count) {
                    sourceSequence = self.sequenceManager.serverSequences[indexPath.row]
                }
            }
            do {
                try self.sequenceManager.copySequence(sequence: sourceSequence)
            } catch {
                print("error copying a sequence: \(error)")
                //TODO
            }
            completionHandler(true)
        })
        action.image = UIImage(systemName: "doc.on.doc")
        action.backgroundColor = .green
        let config = UISwipeActionsConfiguration(actions:[action])
        return config
    }
}
