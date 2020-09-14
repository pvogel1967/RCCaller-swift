//
//  EditSequenceViewController.swift
//  RCCaller
//
//  Created by Vogel, Peter on 7/9/20.
//  Copyright © 2020 Vogel, Peter. All rights reserved.
//

import Foundation
import UIKit

class EditSequenceViewController: UIViewController {
    
    @IBOutlet weak var tfName: UITextField!
    @IBOutlet weak var tfAMAId: UITextField!
    @IBOutlet weak var tfYear: UITextField!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var maneuversButton: UIBarButtonItem!
    var sequence:Sequence?
    let sequenceManager = SequenceManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let mySequence = sequence else {return}
        tfName.text = mySequence.name
        tfAMAId.text = mySequence.amaId
        tfYear.text = mySequence.year
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let mySequence = sequence else {return}
        tfName.text = mySequence.name
        tfAMAId.text = mySequence.amaId
        tfYear.text = mySequence.year
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "segSequenceManeuverList") {
            guard let destVC = segue.destination as? ManeuverListViewController else {return}
            destVC.sequence = sequence
        }
    }
    
    @IBAction func onGenerateUnknown(_ sender: UIButton) {
        spinner.startAnimating()
        sender.isEnabled = false
        saveButton.isEnabled = false
        navigationItem.hidesBackButton = true
        maneuversButton.isEnabled = false
        sequenceManager.getUnknownSequence(){ (unknown:Sequence) in
            if (self.sequence == nil) {
                self.sequence = unknown
            } else {
                guard let sequence = self.sequence else {return}
                sequence.maneuvers = unknown.maneuvers
                sequence.name = self.tfName.text ?? "\(self.sequence?.name) \(unknown.name)"
                sequence.amaId = self.tfAMAId.text ?? unknown.amaId
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy"
                sequence.year = self.tfYear.text ?? formatter.string(from: Date())
            }
            DispatchQueue.main.async {
                self.tfName.text = self.sequence?.name
                self.tfAMAId.text = self.sequence?.amaId
                self.tfYear.text = self.sequence?.year
                self.spinner.stopAnimating()
                sender.isEnabled = true
                self.saveButton.isEnabled = true
                self.navigationItem.hidesBackButton=false
                self.maneuversButton.isEnabled = true
            }
        }
    }
    
    func performSegueToGoBack() {
        if let nav = self.navigationController {
            nav.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func onSave(_ sender: Any) {
        guard let sequence = self.sequence else {
            performSegueToGoBack()
            return
        }
        sequence.name = tfName?.text ?? "No Name"
        sequence.amaId = tfAMAId?.text ?? "No AMAID"
        sequence.year = tfYear.text ?? ""
        do {
            try sequenceManager.saveSequence(sequence: sequence)
        } catch {
            print("error saving sequence: \(error)")
            //TODO
        }
        performSegueToGoBack()
    }
    
    
}
