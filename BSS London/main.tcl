set varIfChanType 5
set varIfParam "<configuration>

  <counts>
    <zone_count>10</zone_count>
    <source_count>14</source_count>
  </counts>

  <zones>
    <zone>
      <name>Zone 01</name>
      <object_id_gain>00, 01, 31</object_id_gain>
      <object_id_source>00, 01, 3D</object_id_source>
    </zone>
    <zone>
      <name>Zone 02</name>
      <object_id_gain>00, 01, 44</object_id_gain>
      <object_id_source>00, 01, 3E</object_id_source>
    </zone>
    <zone>
      <name>Zone 03</name>
      <object_id_gain>00, 01, 4D</object_id_gain>
      <object_id_source>00, 01, 52</object_id_source>
    </zone>
    <zone>
      <name>Zone 04</name>
      <object_id_gain>00, 01, 56</object_id_gain>
      <object_id_source>00, 01, 7A</object_id_source>
    </zone>
    <zone>
      <name>Zone 05</name>
      <object_id_gain>00, 01, 5F</object_id_gain>
      <object_id_source>00, 01, 7B</object_id_source>
    </zone>
    <zone>
      <name>Zone 06</name>
      <object_id_gain>00, 01, 81</object_id_gain>
      <object_id_source>00, 01, 7C</object_id_source>
    </zone>
    <zone>
      <name>Zone 07</name>
      <object_id_gain>00, 01, 8A</object_id_gain>
      <object_id_source>00, 01, 7D</object_id_source>
    </zone>
    <zone>
      <name>Zone 08</name>
      <object_id_gain>00, 01, 93</object_id_gain>
      <object_id_source>00, 01, 7E</object_id_source>
    </zone>
    <zone>
      <name>Zone 09</name>
      <object_id_gain>00, 01, 9C</object_id_gain>
      <object_id_source>00, 01, 7F</object_id_source>
    </zone>
    <zone>
      <name>Zone 10</name>
      <object_id_gain>00, 01, A5</object_id_gain>
      <object_id_source>00, 01, 80</object_id_source>
    </zone>
  </zones>

  <sources>
    <source>
      <name>Source 01</name>
      <data>00, 00, 00, 01</data>
    </source>
    <source>
      <name>Source 02</name>
      <data>00, 00, 00, 02</data>
    </source>
    <source>
      <name>Source 03</name>
      <data>00, 00, 00, 03</data>
    </source>
    <source>
      <name>Source 04</name>
      <data>00, 00, 00, 04</data>
    </source>
    <source>
      <name>Source 05</name>
      <data>00, 00, 00, 05</data>
    </source>
    <source>
      <name>Source 06</name>
      <data>00, 00, 00, 06</data>
    </source>
    <source>
      <name>Source 07</name>
      <data>00, 00, 00, 07</data>
    </source>
    <source>
      <name>Source 08</name>
      <data>00, 00, 00, 08</data>
    </source>
    <source>
      <name>Source 09</name>
      <data>00, 00, 00, 09</data>
    </source>
    <source>
      <name>Source 10</name>
      <data>00, 00, 00, 0A</data>
    </source>
    <source>
      <name>Source 11</name>
      <data>00, 00, 00, 0B</data>
    </source>
    <source>
      <name>Source 12</name>
      <data>00, 00, 00, 0C</data>
    </source>
    <source>
      <name>Source 13</name>
      <data>00, 00, 00, 0D</data>
    </source>
    <source>
      <name>Source 14</name>
      <data>00, 00, 00, 0E</data>
    </source>
  </sources>
</configuration>"

set message_send "90, 00, 00, 03, 00, 01, 31, 00, 00, 00, 01, 00, 00"

#!/usr/bin/tcl
#===========================================
# File: 	base.tcl
# Description: 	TCL script for BSS London BLU devices
# Version: 	1.0
# 
# Author: 	Gary Pascal
#		Cinema Nova Productions, LLC
#
# History:	2015-02-11 Code Creation
#		2015-02-20 Add proc loadParameters
#
# Notes:	
#
#===========================================
#source [file dirname [info script]]/systemSDK.tcl

#===========================================
# CONSTANTS
#===========================================
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

set device_using_rs232 0
set device_using_ip 0


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
# LOGGING
#===========================================
#-------------------------------------------
# Set to 1 to start logging (to file)
# Log "data" will write to file
#-------------------------------------------
#enableLOG 0

#===========================================
# RG DEV LOGGING
#===========================================
#-------------------------------------------
# Set to 1 to start tracing (using puts)
# devLog "data" will write to output
#-------------------------------------------
#enableDevLog 1

#===========================================
# PROCEDURE: INIT
#===========================================
#-------------------------------------------
# Main initiation of the module
#-------------------------------------------
proc init {} {
	if {$::varIfChanType == 5} {
		#devLog "Using serial connection mode\n"
		set ::device_using_rs232 1
		set ::device_using_ip 0
	} else {
		#devLog "Using IP connection mode\n"
		set ::device_using_rs232 0
		set ::device_suing_ip 1
	}

	loadParameters
	#readPersistentVars
	#writePersistentVars
	#openConnection
}

#===========================================
# PROCEDURE: LOAD PARAMETERS
#===========================================
#-------------------------------------------
# Parse and load the parameters of the device
#-------------------------------------------
proc loadParameters {} {
	#devLog "Loading parameters"
	#devLog "Parameters: $::varIfParam"
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
}

#===========================================
# PROCEDURE: SEND VOLUME UP
#===========================================
proc send_VolumeUp {zone} {
	set message ""
	append message [dict get $::MESSAGE_TYPE BUMPSVPERCENT] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Volume] ", " [dict get $::DATA VolumeUp]
	set new_message [finalizeControlString $message]
	return $new_message
}

#===========================================
# PROCEDURE: SEND  VOLUME DOWN
#===========================================
proc send_VolumeDown {zone} {
	set message ""
	append message [dict get $::MESSAGE_TYPE BUMPSVPERCENT] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Volume] ", " [dict get $::DATA VolumeDown]
	set new_message [finalizeControlString $message]
	return $new_message
}

#===========================================
# PROCEDURE: SEND MUTE ON
#===========================================
proc send_MuteOn {zone} {
	set message ""
	append message [dict get $::MESSAGE_TYPE SETSV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Mute] ", " [dict get $::DATA MuteOn]
	set new_message [finalizeControlString $message]
	return $new_message
}

#===========================================
# PROCEDURE: SEND MUTE OFF
#===========================================
proc send_MuteOff {zone} {
	set message ""
	append message [dict get $::MESSAGE_TYPE SETSV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Mute] ", " [dict get $::DATA MuteOff]
	set new_message [finalizeControlString $message]
	return $new_message
}

#===========================================
# PROCEDURE: SEND INPUT SELECT
#===========================================
proc send_InputSelect {zone input} {
	set message ""
	append message [dict get $::MESSAGE_TYPE SETSV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Source Object ID"] ", " [dict get $::STATE_VARIABLE InputNumber] ", " [dict get $::SOURCES $input Data]
	set new_message [finalizeControlString $message]
	return $new_message
}

#===========================================
# PROCEDURE: RECEIVE VOLUME LEVEL
#===========================================
proc receive_VolumeLevel {zone} {
	set message ""
	append message [dict get $::MESSAGE_TYPE SUBSCRIBESVPERCENT] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Volume] ", " [dict get $::DATA GetVolume]
	set new_message [finalizeControlString $message]
	return $new_message
}

#===========================================
# PROCEDURE: RECEIVE MUTE STATUS
#===========================================
proc receive_MuteStatus {zone} {
	set message ""
	append message [dict get $::MESSAGE_TYPE SUBSCRIBESV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Gain Object ID"] ", " [dict get $::STATE_VARIABLE Mute] ", " [dict get $::DATA GetMuteStatus]
	set new_message [finalizeControlString $message]
	return $new_message
}

#===========================================
# PROCEDURE: RECEIVE INPUT SELECTED
#===========================================
proc receive_InputSelected {zone} {
	set message ""
	append message [dict get $::MESSAGE_TYPE SUBSCRIBESV] ", " $::NODE ", " $::VIRTUAL_DEVICE_ID ", " [dict get $::ZONES $zone "Source Object ID"] ", " [dict get $::STATE_VARIABLE InputNumber] ", " [dict get $::DATA GetInput]
	set new_message [finalizeControlString $message]
	return $new_message
}

#===========================================
# PROCEDURE: FINALIZE CONTROL STRING
#===========================================
#-------------------------------------------
# Pass ID and Payload information and return a final string usable by the 
# BSS London Module.
#
# The control string has five parts:
#   Start Indicator:    0x02
#   ID:                 Message type
#   Payload:            The Node, Virtual Device, Object, State Variable, and Data
#   Checksum:           A checksum of the ID and Payload
#   End Indicator:      0x03
#-------------------------------------------
proc finalizeControlString {message} {
	set new_message ""
	append new_message "02, " [escapeControlCodes $message] ", " [getChecksum $message] ", 03"
	return $new_message
}

#===========================================
# PROCEDURE: GET CHECKSUM
#===========================================
#-------------------------------------------
# Pass the ID and Payload string and return a checksum value.
#-------------------------------------------
proc getChecksum {message} {
	scan [string index $message 0][string index $message 1] %x checksum
    	set i 4
    	while {$i < [string length $message]} {
        	set byte [string index $message $i][string index $message [expr {$i + 1}]]
        	scan $byte %x byte_dec
        	set checksum [expr {$checksum^$byte_dec}]
        	set i [expr {$i + 4}]
    	}
    	return [format %X $checksum]
}

#===========================================
# PROCEDURE: ESCAPE CONTROL CODES
#===========================================
#-------------------------------------------
# Certain hex values are reserved for control codes. If any of these values
# end up in the final string, they need to be replaced according to this table:
# 
# Control Code    Replaced With
#   0x02            0x1B 0x82
#   0x03            0x1B 0x83
#   0x06            0x1B 0x86
#   0x15            0x1B 0x95
#   0x1B            0x1B 0x9B
#-------------------------------------------
proc escapeControlCodes {message} {
    	set new_message [string map {02 "1B, 82" 03 "1B, 83" 06 "1B, 86" 15 "1B, 95" 1B "1B, 9B"} $message]
	return $new_message    
}

#==========================================================
# PROCEDURE: GET SUBSTRING WITHIN STRINGS
#==========================================================
proc getSubstringWithinStrings {str1 str2 source_string {start_index 0}} {
	set loc_start [string first $str1 $source_string $start_index]
	set loc_end [string first $str2 $source_string $loc_start]

	if {($loc_start >= 0 && $loc_end >= 0)} {
		set loc_start [expr {$loc_start+[string length $str1]}]
		set loc_end [expr {$loc_end - 1}]
		set return_str [string range $source_string $loc_start $loc_end]
		return $return_str;
	}

	return ""; # Empty string on any failure
}

#==========================================================
# PROCEDURE: LOAD PARAMETERS
#==========================================================
proc loadParameters {} {
    #devLog "Loading parameters"
	#devLog "Parameters: $::varIfParam"

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
}

#===========================================
# MAIN START
#===========================================
init

puts [finalizeControlString $message_send] 
puts [send_VolumeUp 1]
puts [send_VolumeDown 1]
puts [send_MuteOn 1]
puts [send_MuteOff 1]
puts [send_InputSelect 1 1]
