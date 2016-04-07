//
//  GeneralPrefsViewController.swift
//  NTX
//
//  Created by Simon Bell on 24/03/2015.
//
//

import Foundation
import Cocoa


class GeneralPrefsViewController : NSViewController {


	// Serial
	let kSerialPortPref = "SerialPort"
	let kSerialBaudPref = "BaudRate"

	// Software Update
	let kAutoUpdatePref = "SUPerformScheduledCheck"
	let kUpdateFreqPref = "SUScheduledCheckInterval"

	// Debug
	let kLogToFilePref = "LogToFile"


//	serial prefs
	var ports: Array<(String,String)>?	// name, path
	var serialPort: String?
	var serialSpeed: Int = 38400

	@IBOutlet weak var serialPortPopup: NSPopUpButton?

	@IBAction func updateSerialPort(sender: NSPopUpButton?) {
		let i = sender!.indexOfSelectedItem
		if i >= 0 {
			let port = (ports![i]).1
			NSUserDefaults.standardUserDefaults().setObject(port, forKey: kSerialPortPref)
		}
	}


	class func preferredSerialPort() -> (path:String,bitrate:Int) /*devpath,bitrate*/ {
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		ports = nil

		if MNPSerialEndpoint.isAvailable
		&& ports = MNPSerialEndpoint.getSerialPorts()
		&& count(ports!) > 0 {
			let preferredPort = .preferredSerialPort()
			let serialPort = preferredPort.path;

			// load it up with available serial port names
			let numOfPorts = count(ports!)
			let serialPortIndex = 999
			serialPortPopup.removeAllItems()
			for i in 0..numOfPorts {
				serialPortPopup.addItemWithTitle(ports![i].name)
				if ports![i].path == serialPort {
					serialPortIndex = i
				}
			}
			if serialPortIndex == 999
			{
				// serialPort isn’t known by IOKit -- maybe user has set their own default
				// add name, path tuple to ports
				ports += (serialPort,serialPort)
				serialPortPopup.addItemWithTitle(serialPort)
				serialPortIndex = numOfPorts;
			}
			serialPortPopup.selectItemAtIndex(serialPortIndex)
		}
	}


}
