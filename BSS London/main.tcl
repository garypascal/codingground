#!/usr/bin/tcl
#===========================================
# File: 	    base.tcl
# Description: 	TCL script for BSS London BLU devices
# Version: 	    1.2
# 
# Author: 	    Gary Pascal
#		        Cinema Nova Productions, LLC
#
# History:	    2015-02-11 Code Creation
#		        2015-02-20 Add proc loadParameters
#               2015-02-25 Add proc queueData 
#
# Notes:	
#
#===========================================
source [file dirname [info script]]/systemSDK.tcl
source [file dirname [info script]]/BSS_utils.tcl

#===========================================
# CONSTANTS
#===========================================
#-------------------------------------------
# General
#-------------------------------------------
set TIME_PER_SEND 200
set TIME_RETRY_CONNECTION 5000
set TIME_NO_CONNECTION 5000
set TIME_RECEIVE_TIMEOUT 500

#-------------------------------------------
# Limits
#-------------------------------------------
set NUMBER_OF_ZONES 0
set NUMBER_OF_SOURCES 0

#===========================================
# VARIABLES
#===========================================
#-------------------------------------------
# Connection Variables
#-------------------------------------------
set device_socket 0
set device_connected 0
set retryConnectionFlag 0; #if set to 1 the connection will be reconnected when the retry timer hits
set timer_retryConnection [setTimer $TIME_RETRY_CONNECTION]; # Check the connection every 5 seconds

set device_using_rs232 0
set device_using_ip 0

set send_timer [setTimer $TIME_PER_SEND]; # Send messages at this interval
set receive_timeout [setTimer $TIME_RECEIVE_TIMEOUT]; # Timer that executes every second
set receive_nocommunication_timeout [setTimer $TIME_NO_CONNECTION]; # If no response is received after timer its Offline.

#-------------------------------------------
# Transmission Variables
#-------------------------------------------
set rx_queue [list]
set rx_buffer ""

set timer_second [setTimer 1000]; # Timer that executes every second
set device_sent_data_this_second 0; # Track if a command has been sent this second


#-------------------------------------------
# BSS London Control Variables
#-------------------------------------------
dict set MESSAGE_TYPE SETSV                 88
dict set MESSAGE_TYPE SUBSCRIBESV           89
dict set MESSAGE_TYPE UNSUBSCRIBESV         8A
dict set MESSAGE_TYPE VENUE_PRESET_RECALL   8B
dict set MESSAGE_TYPE PARAM_PRESET_RECALL   8C
dict set MESSAGE_TYPE SETSVPERCENT          8D
dict set MESSAGE_TYPE SUBSCRIBESVPERCENT    8E
dict set MESSAGE_TYPE UNSUBSCRIBESVPERCENT  8F
dict set MESSAGE_TYPE BUMPSVPERCENT         90

set NODE "00, 00"
set VIRTUAL_DEVICE_ID 03

set ZONES [dict create]
set SOURCES [dict create]

dict set STATE_VARIABLE Volume      "00, 00"
dict set STATE_VARIABLE Mute        "00, 01"
dict set STATE_VARIABLE InputNumber "00, 00"

dict set DATA VolumeUp          "00, 01, 00, 00"
dict set DATA VolumeDown        "FF, FF, 00, 00"
dict set DATA GetVolume         "00, 00, 00, 00"
dict set DATA MuteOn            "00, 00, 00, 01"
dict set DATA MuteOff           "00, 00, 00, 00"
dict set DATA GetMuteStatus     "00, 00, 00, 00"
dict set DATA DisableInputs     "00, 00, 00, 00"
dict set DATA GetInput          "00, 00, 00, 00"

#===========================================
# PROCEDURE: INIT
#===========================================
#-------------------------------------------
# Main initiation of the module
#-------------------------------------------
proc init {} {
	devLog "Procedure: init"
	if {$::varIfChanType == 5} {
		devLog "Using serial connection mode\n"
		set ::device_using_rs232 1
		set ::device_using_ip 0
	} else {
		devLog "Using IP connection mode\n"
		set ::device_using_rs232 0
		set ::device_suing_ip 1
	}

	loadParameters
	initializeVariables
	#writePersistentVars
	#openConnection
	devLog "Procedure Complete: init"
}

#===========================================
# PROCEDURE: LOAD PARAMETERS
#===========================================
#-------------------------------------------
# Parse and load the parameters of the device
#-------------------------------------------
proc loadParameters {} {
	devLog "Procedure: loadParameters"
    set ::NUMBER_OF_ZONES [getSubstringWithinStrings "<zone_count>" "</zone_count>" $::varIfParam]
	set zones_str [getSubstringWithinStrings "<zones>" "</zones>" $::varIfParam]
	set loc_start 0
	set loc_end 0
	for {set i 0} {$i < $::NUMBER_OF_ZONES} {incr i} {
        set loc_start [string first "<zone>" $zones_str $loc_start]
        set loc_end [string first "</zone>" $zones_str $loc_start]
		set zone_number [expr {$i + 1}]
		if {($loc_start >= 0 && $loc_end >= 0)} {
			set zone [string range $zones_str $loc_start $loc_end]
			dict set ::ZONES $zone_number "Name" [getSubstringWithinStrings "<name>" "</name>" $zone]
			dict set ::ZONES $zone_number "Gain Object ID" [getSubstringWithinStrings "<object_id_gain>" "</object_id_gain>" $zone]
			dict set ::ZONES $zone_number "Source Object ID" [getSubstringWithinStrings "<object_id_source>" "</object_id_source>" $zone]
		}
		set loc_start $loc_end
	}
    
	set ::NUMBER_OF_SOURCES [getSubstringWithinStrings "<source_count>" "</source_count>" $::varIfParam]
	set sources_str [getSubstringWithinStrings "<sources>" "</sources>" $::varIfParam]
	set loc_start 0
	set loc_end 0
	for {set i 0} {$i < $::NUMBER_OF_SOURCES} {incr i} {
		set loc_start [string first "<source>" $sources_str $loc_start]
		set loc_end [string first "</source>" $sources_str $loc_start]
		set source_number [expr {$i + 1}]
		if {($loc_start >= 0 && $loc_end >= 0)} {
			set source [string range $sources_str $loc_start $loc_end]
			dict set ::SOURCES $source_number "Name" [getSubstringWithinStrings "<name>" "</name>" $source]
			dict set ::SOURCES $source_number "Data" [getSubstringWithinStrings "<data>" "</data>" $source]
		}
		set loc_start $loc_end
	}
	devLog "Procedure Complete: loadParameters"
}

#===========================================
# PROCEDURE: INITIALIZE VARIABLES
#===========================================
#-------------------------------------------
# Initialize volume, mute, and input variables
#-------------------------------------------
proc initializeVariables {} {
    devLog "Procedure: initializeVariables"
    for {set i 0} {$i < $::NUMBER_OF_ZONES} {incr i} {
        set zone_number [expr {$i + 1}]
        dict set ::ZONES $zone_number "Volume Level" 0
        dict set ::ZONES $zone_number "Mute Status" 0
        dict set ::ZONES $zone_number "Input Selected" 0
    }
    devLog "Procedure Complete: initializeVariables"
}

#===========================================
# PROCEDURE: OPEN CONNECTION
#===========================================
#-------------------------------------------
# Open connection to the BSS London device
#-------------------------------------------
proc openConnection {} {
	devLog "Procedure: openConnection Channel: $::varIfChanType Host: $::varIfAddress Port:$::varIfPort"
	
	# This module only works with RS232 (type:5) or UDP (type:2)
	set chan_type $::varIfChanType
	if {$chan_type < 5} {
		set chan_type 2
	}

	devLog "Connecting... Chan:$chan_type Host:$::varIfAddress Port:$::varIfPort"
	set ::device_socket [connect $chan_type $::varIfAddress $::varIfPort $::varIfBaudrate $::varIfDatabits $::varIfParity $::varIfStopbits]

	if {$::device_socket == 0} {
		set ::retryConnectionFlag 1
	} else {
		devLog "Socket connected."
		set ::retryConnectionFlag 0
	}
}

#===========================================
# PROCEDURE: QUEUE DATA
#===========================================
#-------------------------------------------
# Receives a message string and adds it to the 
# queue of strings to be sent to the BSS London 
# device.
#-------------------------------------------
proc queueData {data} {
    lappend ::rx_queue $data
}

#===========================================
# PROCEDURE: SEND QUEUED DATA
#===========================================
#-------------------------------------------
# Sends all the strings in the rx_queue list 
# to the BSS London Device
#-------------------------------------------
proc sendQueuedData {} {
	if {[llength $::rx_queue] > 0} {
		devLog "Sending from queue (queue [llength $::rx_queue] items)"
		sendData [lindex $::rx_queue 0]
		set ::rx_queue [lreplace $::rx_queue 0 0]
	}
}

#===========================================
# PROCEDURE: SEND DATA
#===========================================
#-------------------------------------------
# Sends data to the BSS London device
#-------------------------------------------
proc sendData {data} {
    devLog "Procedure: sendData"
	if {[string length $data] > 0} {
		devLog "Sending: $data"
		if {[catch {send $::device_socket $data}]} {
			devLog "Cannot write to channel"
			return -code error 0
		} else {
			# Set the flag that data has been sent this second
			set ::device_sent_data_this_second 1
		}
		clearTimer $::send_timer
		set ::send_timer [setTimer $::TIME_PER_SEND];
	} else {
		devLog "Not sending the empty string"
	}
	devLog "Procedure Complete: sendData"
}

#===========================================
# PROCEDURE: ON TIMER
#===========================================
#-------------------------------------------
# Called when a timer hits
#-------------------------------------------
proc onTimer {id} {
	# Check the reconnection timer
	if {$id == $::timer_retryConnection} {
		if {$::retryConnectionFlag == 1} {
			openConnection
		}
	} elseif {$id == $::send_timer} {
		sendQueuedData
	} elseif {$id == $::timer_second} {
		if {$::device_sent_data_this_second == 0} {
			deviceSet_Ping
		}
		# Clear the flag for the data sent this second
		set ::device_sent_data_this_second 0
	} elseif {$id == $::receive_timeout} {
		#devLog "Receive timeout."
		set ::rx_buffer ""
		clearTimer $::receive_timeout
	} elseif {$id == $::receive_nocommunication_timeout} {
		devLog "--------- Device appears to be offline!! -----------"
		clearTimer $::receive_nocommunication_timeout
		set ::device_connected 0
	} elseif {$id == $::timer_variables_save} {
		if {$::variables_save_needed == 1} {
			writePersistentVars
			set ::variables_save_needed 0
		}
	} else {
		# Not a handled timer
	}
}

#===========================================
# PROCEDURE: DATA PARSER
#===========================================
#-------------------------------------------
# Receives a data string and parses to return 
# either volume level (0-100), mute status (0-1) 
# or input number (1-xx)
#-------------------------------------------
proc dataParser {data} {
	devLog "Procedure: dataParser Data: $data"
	set mew_message [reverseEscapeControlCodes [reverseFinalizeControlString $msg]]
	set message_id [string range $message 0 1]
    
	set node [string range $message 4 9]
    
	set virtual_device_id [string range $message 12 13]
    
	set object_id [string range $message 16 25]
    
	set state_variable [string range $message 28 33]
    
	set data [string range $message 36 49]
    
	set checksum [string range $message 52 53]
	
	

	#if {[string first "#" $data] >= 0} {
	#	set loc1 [string first "#" $data]
	#	incr loc1
	#	if {[string first "=" $data] >= 0} {
	#		set loc2 [string first "=" $data]
	#		set control_number [string range $data $loc1 [expr {$loc2-1}]]
	#		set control_number [scan $control_number %d]

	#		if {[string first "\x0D" $data] >= 0} {
	#			set loc1 [expr {$loc2 + 1}]
	#			set loc2 [string first "\x0D" $data]
	#			set control_value [string range $data $loc1 [expr {$loc2-1}]]
	#			set control_value [scan $control_value %d]

	#			devLog "control_number='$control_number' control_value='$control_value'"
	#			dataUpdate $control_number $control_value
	#		}
	#	}
	#}
	devLog "Procedure Complete: dataParser Data: $data"
}

#===========================================
# PROCEDURE: ON DATA
#===========================================
#-------------------------------------------
# Called when data is received. Checks for correct
# data packet header. Takes the input buffer and parses
# full data packets to be sent to the parser.
#-------------------------------------------
proc onData {socketID data} {
    devLog "Procedure: onData Socket: $socketID Data: $data"
	if {$::device_connected == 0} {
		devLog "--------- Device online -----------"
		set ::device_connected 1
		deviceSet_EnableNotifications
	}
	# Restart the timer for detecting offline
	clearTimer $::receive_nocommunication_timeout
	set ::receive_nocommunication_timeout [setTimer $::TIME_NO_CONNECTION]
	devLog "Socket onData. Data: $data"
	# Add data to the receive buffer to catch half commands
	set ::rx_buffer "$::rx_buffer$data"
	devLog "Socket buffer. Data: $::rx_buffer"
	# Loop through the buffer and extract full commands
	while {[string first "02" $::rx_buffer] >= 0} {
		set loc [string first "02" $::rx_buffer]
		dataParser [string range $::rx_buffer 0 $loc]
		set ::rx_buffer [string replace $::rx_buffer 0 $loc]
	}

	# Clear the buffer if it starts to overflow.
	if {[string length $::rx_buffer] > 100} {
		set ::rx_buffer ""
		devLog "rx_buffer has too much data without any full commands"
	}
	
	# Restart the timer for clearing the buffer
	clearTimer $::receive_timeout
	set ::receive_timeout [setTimer $::TIME_RECEIVE_TIMEOUT]
	devLog "Procedure Complete: onData Socket ID: $socketID Data: $data"
}

#===========================================
# PROCEDURE: SEND VOLUME UP
#===========================================
proc send_VolumeUp {zone} {
	devLog "Procedure: send_VolumeUp Zone: $zone"
	set message ""
	append message [dict get $::MESSAGE_TYPE BUMPSVPERCENT] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Volume] ", " [dict get $::DATA VolumeUp]
	set new_message [finalizeControlString $message]
	devLog "Message String: $new_message"
	queueData $new_message
	return $new_message
	devLog "Procedure Complete: send_VolumeUp Zone: $zone"
}

#===========================================
# PROCEDURE: SEND  VOLUME DOWN
#===========================================
proc send_VolumeDown {zone} {
	devLog "Procedure: send_VolumeDown Zone: $zone"
	set message ""
	append message [dict get $::MESSAGE_TYPE BUMPSVPERCENT] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Volume] ", " [dict get $::DATA VolumeDown]
	set new_message [finalizeControlString $message]
	devLog "Message String: $new_message"
	queueData $new_message
	return $new_message
	devLog "Procedure Complete: send_VolumeDown Zone: $zone"
}

#===========================================
# PROCEDURE: SEND MUTE ON
#===========================================
proc send_MuteOn {zone} {
	devLog "Procedure: send_MuteOn Zone: $zone"
	set message ""
	append message [dict get $::MESSAGE_TYPE SETSV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Mute] ", " [dict get $::DATA MuteOn]
	set new_message [finalizeControlString $message]
	devLog "Message String: $new_message"
	queueData $new_message
	return $new_message
	devLog "Procedure Complete: send_MuteOn Zone: $zone"
}

#===========================================
# PROCEDURE: SEND MUTE OFF
#===========================================
proc send_MuteOff {zone} {
	devLog "Procedure: send_MuteOff Zone: $zone"
	set message ""
	append message [dict get $::MESSAGE_TYPE SETSV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Mute] ", " [dict get $::DATA MuteOff]
	set new_message [finalizeControlString $message]
	devLog "Message String: $new_message"
	queueData $new_message
	return $new_message
	devLog "Procedure Complete: send_MuteOff Zone: $zone"
}

#===========================================
# PROCEDURE: SEND INPUT SELECT
#===========================================
proc send_InputSelect {zone input} {
	devLog "Procedure: send_InputSelect Zone: $zone Input: $input"
	set message ""
	append message [dict get $::MESSAGE_TYPE SETSV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Source Object ID"] ", " [dict get $::STATE_VARIABLE InputNumber] ", " [dict get $::SOURCES $input Data]
	set new_message [finalizeControlString $message]
	devLog "Message String: $new_message"
	queueData $new_message
	return $new_message
	devLog "Procedure Complete: send_InputSelect Zone: $zone Input: $input"
}

#===========================================
# PROCEDURE: RECEIVE VOLUME LEVEL
#===========================================
proc receive_VolumeLevel {zone} {
	devLog "Procedure: receive_VolumeLevel Zone: $zone"
	set message ""
	append message [dict get $::MESSAGE_TYPE SUBSCRIBESVPERCENT] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Volume] ", " [dict get $::DATA GetVolume]
	set new_message [finalizeControlString $message]
	devLog "Message String: $new_message"
	queueData $new_message
	return $new_message
	devLog "Procedure Complete: receive_VolumeLevel Zone: $zone"
}

#===========================================
# PROCEDURE: RECEIVE MUTE STATUS
#===========================================
proc receive_MuteStatus {zone} {
	devLog "Procedure: receive_MuteStatus Zone: $zone"
	set message ""
	append message [dict get $::MESSAGE_TYPE SUBSCRIBESV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Mute] ", " [dict get $::DATA GetMuteStatus]
	set new_message [finalizeControlString $message]
	devLog "Message String: $new_message"
	queueData $new_message
	return $new_message
	devLog "Procedure Complete: receive_MuteStatus Zone: $zone"
}

#===========================================
# PROCEDURE: RECEIVE INPUT SELECTED
#===========================================
proc receive_InputSelected {zone} {
	devLog "Procedure: receive_InputSelected Zone: $zone"
	set message ""
	append message [dict get $::MESSAGE_TYPE SUBSCRIBESV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Source Object ID"] ", " [dict get $::STATE_VARIABLE InputNumber] ", " [dict get $::DATA GetInput]
	set new_message [finalizeControlString $message]
	devLog "Message String: $new_message"
	queueData $new_message
	return $new_message
	devLog "ProcedureComplete: receive_InputSelected Zone: $zone"
}

#===========================================
# RG DEV LOGGING
#===========================================
#-------------------------------------------
# Set to 1 to start tracing (using puts)
# devLog "data" will write to output
#-------------------------------------------
enableDevLog 1

#===========================================
# MAIN START
#===========================================
init

send_VolumeUp 1
send_VolumeDown 1
send_MuteOn 1
send_MuteOff 1
send_InputSelect 1 1 
