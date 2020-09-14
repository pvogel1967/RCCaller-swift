//
//  ManeuverListViewController.swift
//  RCCaller
//
//  Created by Vogel, Peter on 7/9/20.
//  Copyright © 2020 Vogel, Peter. All rights reserved.
//

import Foundation
import UIKit

class ManeuverListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var sequence:Sequence?
    @IBOutlet weak var tableView: UITableView!
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let s = sequence else { return 0}
        return s.maneuvers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "maneuverCell", for: indexPath)
        guard let s = sequence else {return cell}
        cell.textLabel?.text = s.maneuvers[indexPath.row].description
        cell.detailTextLabel?.text = "\(s.maneuvers[indexPath.row].kFactor)"
        return cell
    }
    
    
    
}
