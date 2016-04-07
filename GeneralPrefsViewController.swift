//
//  UpdatePrefsViewController.swift
//  NTX
//
//  Created by Simon Bell on 24/03/2015.
//
//

import Cocoa


class UpdatePrefsViewController : NSViewController {

//	software update prefs
	@IBOutlet weak var frequencyPopUp: NSPopUpButton?
	@IBOutlet weak var autoCheck: NSButton?

	enum CheckFrequencyMark: Int { case kCheckNever = 0, kCheckDaily, kCheckWeekly, kCheckMonthly }

	override func viewDidLoad() {
		super.viewDidLoad()

		var itemIndexToSelect: Int;
		// SUScheduledCheckInterval is measured in seconds -- convert to days
		let kDays: Double = (24 * 60 * 60)
		let checkFrequencyInDays: Int = Int(Double(SUUpdater.sharedUpdater().updateCheckInterval()) / kDays)

		if checkFrequencyInDays > 27 {
			itemIndexToSelect = frequencyPopUp!.indexOfItemWithTag(CheckFrequencyMark.kCheckMonthly.rawValue)
		} else if checkFrequencyInDays > 6 {
			itemIndexToSelect = frequencyPopUp!.indexOfItemWithTag(CheckFrequencyMark.kCheckWeekly.rawValue)
		} else {
			itemIndexToSelect = frequencyPopUp!.indexOfItemWithTag(CheckFrequencyMark.kCheckDaily.rawValue)
		}

		frequencyPopUp!.selectItemAtIndex(itemIndexToSelect)
		autoCheck!.state = SUUpdater.sharedUpdater().automaticallyChecksForUpdates() ? NSOnState : NSOffState
	}



//	software update prefs
	@IBAction func updateFrequency(sender: NSControl?) {

		if sender == autoCheck {
			// this is the “Check for updates” checkbox
			SUUpdater.sharedUpdater().setAutomaticallyChecksForUpdates((sender as NSButton).state == NSOnState)
		}

		else {
			// this is the frequency popup menu
			let kDays: Double = (24 * 60 * 60)
			var checkInterval: NSTimeInterval;	// seconds
			switch (sender as NSPopUpButton).selectedItem!.tag
			{
			case CheckFrequencyMark.kCheckDaily.rawValue:
				checkInterval = kDays;
			case CheckFrequencyMark.kCheckWeekly.rawValue:
				checkInterval = 7 * kDays
			case CheckFrequencyMark.kCheckMonthly.rawValue:
				checkInterval = 28 * kDays	// lunar month!
			default:
				checkInterval = kDays
			}
			SUUpdater.sharedUpdater().setUpdateCheckInterval(checkInterval)
		}
	}

}
