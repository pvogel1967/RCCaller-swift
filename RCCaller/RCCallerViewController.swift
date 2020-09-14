//
//  ViewController.swift
//  RCCaller
//
//  Created by Vogel, Peter on 6/17/20.
//  Copyright © 2020 Vogel, Peter. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion
import MediaPlayer



class SwitchCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var switchControl: UISwitch!
    
}

class PickerCell: UITableViewCell {
    @IBOutlet weak var picker: UIPickerView?
    
}

class SensitivityCell: UITableViewCell {
    @IBOutlet weak var tfTrigger: UITextField!
    @IBOutlet weak var tfReset: UITextField!
    
}

class BasicCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    
}


class RCCallerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
                              UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate,
                              SequencesObserver {
    
    
    //iOS component init
    
    let audioSession = AVAudioSession.sharedInstance()
    let synth = AVSpeechSynthesizer()
    let motionManager = CMMotionManager()

    
     //UIComponent references
    @IBOutlet weak var tableView: UITableView!
    weak var axisPicker: UIPickerView?
    weak var sequencePicker: UIPickerView?
    weak var sequenceLabel: UILabel?
    weak var axisLabel: UILabel?
    weak var repeatSwitch: UISwitch?
    weak var tiltSwitch: UISwitch?
    weak var callEnableSwitch: UISwitch?
    weak var triggerAngleText: UITextField?
    weak var resetAngleText: UITextField?
    weak var maneuverText: UILabel?
   
    
    
    //TableView setup
    let sectionTitles = ["Control", "Sequence", "Current Maneuver"]
    let controlTitles = ["Repeat Only", "Tilt", "click to select control axis", "axisPicker", "tiltSensitivity","Left/Right and Up/Down arrow keys always work"]
    let controlCellIds = ["switchCell", "switchCell", "basicCell","pickerCell", "sensitivityCell","basicCell"]
    let sequenceCellIds = ["basicCell", "pickerCell","switchCell"]
    let sequenceCellTitles = ["sequenceTitle", "sequencePicker", "Calling Enabled"]
    let maneuverCellIds = ["basicCell"]
    let maneuverCellTitles = ["maneuverDescription"]
    var cellIds:Array<Array<String>> = []
    var cellTitles:Array<Array<String>> = []

    
    let sequenceManager = SequenceManager.shared
    
    
 
    @objc func startCalling() -> MPRemoteCommandHandlerStatus {
        initMotionHandler()
        currentManeuver = 0
        calling=true
        tableView.beginUpdates()
        callEnableSwitch?.setOn(true, animated: true)
        tableView.endUpdates()
        updateManeuver()
        return .success
    }
    
    @objc func stopCalling() -> MPRemoteCommandHandlerStatus {
        deinitMotionHandler()
        calling = false
        tableView.beginUpdates()
        callEnableSwitch?.setOn(false, animated: true)
        tableView.endUpdates()
        return .success
    }
    
    @objc func updateCalling() -> MPRemoteCommandHandlerStatus {
        tableView.beginUpdates()
        (calling) ? stopCalling() : startCalling()
        tableView.endUpdates()
        return .success
    }
    
    @objc func nextManeuver() -> MPRemoteCommandHandlerStatus {
        guard let sequence=currentSequence else {return .noSuchContent}
        currentManeuver+=1
        if (currentManeuver > sequence.maneuvers.count-1) {
            currentManeuver = 0
        }
        updateManeuver()
        return .success
    }
    
    @objc func prevManeuver() -> MPRemoteCommandHandlerStatus {
        guard let sequence=currentSequence else {return .noSuchContent}
        guard !repeatOnly else {
            updateManeuver()
            return .success
        }
        currentManeuver-=1
        if (currentManeuver < 0) {
            currentManeuver = sequence.maneuvers.count-1
        }
        updateManeuver()
        return .success
    }
    
    func speak(_ toSpeak:String, withVoice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: "en-US")!) {
        let utterance = AVSpeechUtterance(string: toSpeak)
        utterance.voice = withVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utterance)
    }
    
    func updateManeuver() {
        guard let sequence = currentSequence else {return}
        let maneuver = sequence.maneuvers[currentManeuver]
        tableView.beginUpdates()
        maneuverText?.text = maneuver.description
        tableView.endUpdates()
        speak(maneuver.description)
    }
    
    // Basic main view state management below
    
    
    func processPickerCell(pickerCell:PickerCell, cellTitle: String) {
        switch cellTitle {
        case "axisPicker":
            axisPicker = pickerCell.picker
        case "sequencePicker":
            sequencePicker = pickerCell.picker
        default:
            print("unknown picker")
            return;
        }
        pickerCell.picker?.dataSource = self
        pickerCell.picker?.delegate = self
    }
    
    
    
    //tilt axis options
    let tiltAxes = ["Choose Axis", "Roll", "Pitch", "Yaw"]
    
    // user choice state management
    let preferencesManager = PreferencesManager.shared
    var useTilt: Bool {
        get {
            preferencesManager.useTilt
        }
        set {
            preferencesManager.useTilt = newValue
        }
    }
    var editAxis = false;
    var selectSequence = false;
    var repeatOnly: Bool {
        get {
            preferencesManager.repeatOnly
        }
        set {
            preferencesManager.repeatOnly = newValue
        }
    }
    var tiltAxis:String {
        get {
            preferencesManager.tiltAxis
        }
        set {
            preferencesManager.tiltAxis = newValue
        }
    }

    var triggerAngle:Int {
        get {
            preferencesManager.triggerAngle
        }
        set {
            preferencesManager.triggerAngle = newValue
        }
    }
    var resetAngle: Int {
        get {
            preferencesManager.resetAngle
        }
        set {
            preferencesManager.resetAngle = newValue
        }
    }
    var canCall:Bool {
        get {
            if (currentSequence == nil) { return false}
            if (useTilt) {
                if (tiltAxis == "Choose Axis") { return false}
                if (triggerAngle < 5) { return false}
                if (resetAngle < 2) { return false}
            }
            return true
        }
    }
    
    var calling = false;
    var selectedSequenceName: String {
        get {
            preferencesManager.preferredSequence
        }
        set {
            preferencesManager.preferredSequence = newValue
        }
    }
    
    var currentSequence:Sequence? = nil
    var currentManeuver = 0
    
    @IBAction func refreshServerSchedules(_ sender: Any) {
        sequenceManager.loadSequences(forceUpdate: true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        cellIds.append(controlCellIds)
        cellIds.append(sequenceCellIds)
        cellIds.append(maneuverCellIds)
        cellTitles.append(controlTitles)
        cellTitles.append(sequenceCellTitles)
        cellTitles.append(maneuverCellTitles)
        sequenceManager.addObserver(o: self)
        
        self.addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(prevManeuver)))
        self.addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(nextManeuver)))
        self.addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(prevManeuver)))
        self.addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(nextManeuver)))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupRemoteCommandCenter(enable: self.canCall)
    }
    override func viewDidDisappear(_ animated: Bool) {
        setupRemoteCommandCenter(enable: false)
    }

    //switch handlers
    @objc func handleRepeatOnlyToggle(sender: UISwitch) {
        repeatOnly = sender.isOn
    }
    
    func getIndexOfAxis(_ selectedAxis:String) ->Int {
        for idx in 0..<tiltAxes.count {
            if (selectedAxis == tiltAxes[idx]) {
                return idx
            }
        }
        return 0
    }
    
    func updateCallEnable() {
        DispatchQueue.main.async {
            self.tableView.beginUpdates()
            if (self.canCall) {
                self.callEnableSwitch?.isEnabled = true
            } else {
                self.callEnableSwitch?.isEnabled = false
            }
            self.setupRemoteCommandCenter(enable: self.canCall)
            self.tableView.endUpdates()
        }
    }
    
    @objc func handleTiltToggle(sender: UISwitch) {
        useTilt = sender.isOn
        if (!useTilt) {
            editAxis = false
        }
        tableView.beginUpdates()
        if let picker = axisPicker {
            picker.selectRow(getIndexOfAxis(tiltAxis), inComponent: 0, animated: true)
        }
        updateCallEnable()
        tableView.endUpdates()
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    
    // TableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = sectionTitles[indexPath.section]
        let row = indexPath.row
        let rowTitle = cellTitles[indexPath.section][indexPath.row]
        if (section == "Control" && rowTitle == "click to select control axis") {
            return (useTilt) ? UITableView.automaticDimension : 0
        } else if (section == "Control" && rowTitle == "axisPicker") {
            return (useTilt) ? ((editAxis) ? 128 : 0) : 0
        } else if (section == "Control" && rowTitle == "tiltSensitivity") {
            return (useTilt) ? UITableView.automaticDimension : 0
        } else if (section == "Sequence" && rowTitle == "sequencePicker") {
            return (selectSequence) ? 128 : 0
        } else if (section == "Current Maneuver" && rowTitle == "maneuverDescription") {
            return 125
        }
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellIds[section].count
    }
    

    @objc func processSwitch(sender: UISwitch) {
        if (sender === repeatSwitch) {
            repeatOnly = sender.isOn
        } else if (sender === tiltSwitch ) {
            handleTiltToggle(sender: sender)
        } else if (sender === callEnableSwitch) {
            if (sender.isOn) {
                startCalling()
            } else {
                stopCalling()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sectionTitles[indexPath.section]
        let row = indexPath.row
        let cellId = cellIds[indexPath.section][row]
        var cellTitle = cellTitles[indexPath.section][row]

        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)

        cell.clipsToBounds = true
        if let basicCell = cell as? BasicCell {
            if (section == "Control" && cellTitle.starts(with: "Left/Right")) {
                basicCell.title.adjustsFontSizeToFitWidth = true;
                basicCell.title.isUserInteractionEnabled = false;
            } else if (section == "Current Maneuver" && row == 0) {
                basicCell.title.font = UIFont.init(name: "Helvetica", size:12)
                basicCell.title.numberOfLines = 6;
                basicCell.title.minimumScaleFactor = 0.5
                basicCell.title.lineBreakMode = .byWordWrapping
                cellTitle = "Maneuver description will appear here when calling"
                maneuverText = basicCell.title
            } else if (cellTitle == "sequenceTitle") {
                cellTitle = selectedSequenceName
                sequenceLabel = basicCell.title
            } else if (cellTitle == "click to select control axis") {
                axisLabel = basicCell.title
                cellTitle = tiltAxis
            }
            basicCell.title.text = cellTitle
        }
        if let switchCell = cell as? SwitchCell {
            switchCell.title.text = cellTitle
            if let switchCtrl = switchCell.switchControl {
                if (cellTitle == "Repeat Only") {
                    repeatSwitch = switchCtrl
                    switchCtrl.setOn(repeatOnly, animated: false)
                } else if (cellTitle == "Tilt") {
                    tiltSwitch = switchCtrl
                    if (!motionManager.isDeviceMotionAvailable) {
                        switchCtrl.isEnabled = false
                        switchCtrl.setOn(false, animated: false)
                    } else {
                        switchCtrl.setOn(useTilt, animated: false)
                    }
                } else if (cellTitle == "Calling Enabled") {
                    callEnableSwitch = switchCtrl
                    switchCtrl.setOn(calling, animated: false)
                    switchCtrl.isEnabled = canCall;

                }
                switchCtrl.addTarget(self, action: #selector(processSwitch), for: UIControl.Event.valueChanged)
            }
        }
        if let sensitivityCell = cell as? SensitivityCell {
            triggerAngleText = sensitivityCell.tfTrigger
            resetAngleText = sensitivityCell.tfReset
            triggerAngleText?.text = "\(triggerAngle)"
            resetAngleText?.text = "\(resetAngle)"
            triggerAngleText?.delegate = self
            resetAngleText?.delegate = self
        }
        if let pickerCell = cell as? PickerCell {
            processPickerCell(pickerCell: pickerCell, cellTitle: cellTitle)
        }
        
        
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.beginUpdates()
        let sectionTitle = sectionTitles[indexPath.section]
        let rowTitle = cellTitles[indexPath.section][indexPath.row]
        if (rowTitle == "click to select control axis") {
            editAxis.toggle()
            if (editAxis) {
                axisPicker?.selectRow(getIndexOfAxis(tiltAxis), inComponent: 0, animated: true)
            }
        } else if (sectionTitle == "Sequence" && indexPath.row == 0) {
            selectSequence.toggle()
            if (selectSequence) {
                if let idx = sequenceManager.sequences.firstIndex(where: {$0.name == selectedSequenceName}) {
                    sequencePicker?.selectRow(idx, inComponent: 0, animated: true)
                }
            }
        }
        tableView.endUpdates()
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if (pickerView === sequencePicker) {
            return sequenceManager.sequences.count
        } else if (pickerView === axisPicker) {
            return 4
        }
        return 0
    }

    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if (pickerView == sequencePicker) {
            let sequence = sequenceManager.sequences[row]
            return sequence.name
        } else if (pickerView == axisPicker) {
           return tiltAxes[row]
        }
        return ""
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if (pickerView == sequencePicker) {
            let sequence = sequenceManager.sequences[row]
            selectedSequenceName = sequence.name
            currentSequence = sequence
            if let label=sequenceLabel {
                label.text = selectedSequenceName
            }
            updateCallEnable()
        } else if (pickerView == axisPicker) {
            if let label = axisLabel {
                label.text = tiltAxes[row]
                tiltAxis = tiltAxes[row]
            }
            updateCallEnable()
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        guard reason == .committed else {return}
        guard let strValue = textField.text else {return}
        guard let value = Int(strValue) else {return}
        if (textField == triggerAngleText) {
            triggerAngle = value
        } else if (textField == resetAngleText) {
            resetAngle = value
        }
        updateCallEnable()
    }
    
    //Motion handling
    var triggerRadians:Double {
        get {
            Double(preferencesManager.triggerAngle) * (.pi/180.0)
        }
    }
    var resetRadians:Double {
        get {
            Double(preferencesManager.resetAngle) * (.pi/180.0)
        }
    }
    var baselineDeviceMotion:CMDeviceMotion? = nil
    var referenceAttitude:CMAttitude? = nil
    var lastTriggerTime:TimeInterval = Date.timeIntervalSinceReferenceDate - 10000.0
    var currentTiltTrigger = false
    var triggerVal:Double = 0.0

    func deinitMotionHandler() {
        guard useTilt else { return}
        guard motionManager.isDeviceMotionAvailable else { return}
        baselineDeviceMotion = nil
        referenceAttitude = nil
        motionManager.stopDeviceMotionUpdates()
    }
    
     func initMotionHandler() {
         guard useTilt else { return }
         guard motionManager.isDeviceMotionAvailable else {
             speak("Device motion not available, cannot use tilt control ")
             return
         }
         baselineDeviceMotion = nil
         referenceAttitude = motionManager.deviceMotion?.attitude
         motionManager.deviceMotionUpdateInterval = 1.0/10.0
         motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: OperationQueue.main) {(motion, error) in
             guard self.useTilt else { return }
             guard self.tiltAxis != "Choose Axis" else { return}
             guard !self.synth.isSpeaking else { return}
             guard error == nil else {
                 self.speak("got error in motion handler.  Please restart and notify developer of issue")
                 print("\(error)")
                 return
             }
             guard motion != nil else {
                 self.speak("Got nil motion in motion handler.  Please restart and notify developer of issue")
                 return
             }
             guard self.baselineDeviceMotion != nil else {
                 self.baselineDeviceMotion = motion
                 self.referenceAttitude = motion?.attitude
                 return
             }
             let timeSinceLastTrigger = Date.timeIntervalSinceReferenceDate - self.lastTriggerTime
             let currentAttitude = motion?.attitude
             currentAttitude?.multiply(byInverseOf: self.referenceAttitude!)
             //currentAttitude?.multiply(byInverseOf: self.referenceAttitude!)
             var axisLogName:String = "None"
             var axisAttitudeData:Double = 0.0
             switch (self.tiltAxis) {
                 case "Roll":
                     axisAttitudeData = currentAttitude?.roll ?? 0.0
                     axisLogName = "curRoll"
                 case "Pitch":
                     axisAttitudeData = currentAttitude?.pitch ?? 0.0
                     axisLogName = "curPitch"
                 case "Yaw":
                     axisAttitudeData = currentAttitude?.yaw ?? 0.0
                     axisLogName = "curYaw"
                 default:
                     return
             }
             if (fabs(axisAttitudeData) > self.triggerRadians && !self.currentTiltTrigger) {
                 self.lastTriggerTime = Date.timeIntervalSinceReferenceDate
                 self.currentTiltTrigger = true
                 self.triggerVal = fabs(axisAttitudeData)
                 print("\(axisLogName)=\(Double(axisAttitudeData)*180.0/Double.pi), triggerVal=\(self.triggerVal*180.0/Double.pi), triggerTime=\(self.lastTriggerTime)")
                 if (axisAttitudeData < 0.0) {
                     self.prevManeuver()
                 } else {
                     self.nextManeuver()
                 }
             } else if ((fabs(axisAttitudeData) < self.triggerVal-self.resetRadians) && self.currentTiltTrigger && timeSinceLastTrigger > 2.0) {
                 print("\(axisLogName) = \(axisAttitudeData * 180.0/Double.pi), trigger released")
                 self.currentTiltTrigger = false
             }

         }
     }
    
    
    // remote control handling
    func setupRemoteCommandCenter(enable:Bool=true) {
        let remoteCommandCenter = MPRemoteCommandCenter.shared()
        remoteCommandCenter.playCommand.isEnabled = enable
        remoteCommandCenter.stopCommand.isEnabled = enable
        remoteCommandCenter.nextTrackCommand.isEnabled = enable
        remoteCommandCenter.previousTrackCommand.isEnabled = enable
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = enable
        if (enable) {
            remoteCommandCenter.playCommand.addTarget(self, action: #selector(startCalling))
            remoteCommandCenter.stopCommand.addTarget(self, action: #selector(stopCalling))
            remoteCommandCenter.previousTrackCommand.addTarget(self, action: #selector(prevManeuver))
            remoteCommandCenter.nextTrackCommand.addTarget(self, action: #selector(nextManeuver))
            remoteCommandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(updateCalling))
        } else {
            remoteCommandCenter.playCommand.removeTarget(self, action: #selector(startCalling))
            remoteCommandCenter.stopCommand.removeTarget(self, action: #selector(stopCalling))
            remoteCommandCenter.previousTrackCommand.removeTarget(self, action: #selector(prevManeuver))
            remoteCommandCenter.nextTrackCommand.removeTarget(self, action: #selector(nextManeuver))
            remoteCommandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(updateCalling))
        }

        try? audioSession.setActive(enable, options: [.notifyOthersOnDeactivation])
        if (enable) {
            if let sequenceName = currentSequence?.name {
                speak("ready to call the \(sequenceName) sequence")
            }
        }
    }
    
    
    //SequencesObserver protocol methods
    func sequencesUpdatedNotification() {
        guard let picker = sequencePicker else {return}
        DispatchQueue.main.async {
            picker.reloadAllComponents()
        }
        self.currentSequence = sequenceManager.sequences.first(where: {$0.name == selectedSequenceName})
        updateCallEnable()
    }

}

