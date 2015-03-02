#!/usr/bin/tcl
#===========================================
# File: 	    BSS_utils.tcl
# Description: 	Utilities processes TCL script 
#               for BSS London BLU devices
# Version: 	    1.2
# 
# Author: 	    Gary Pascal
#		        Cinema Nova Productions, LLC
#
# History:	    2015-02-25 Code Creation
#
# Notes:	
#
#===========================================

#===========================================
# VARIABLES
#===========================================
set enableDevLog 0

#===========================================
# PROCEDURE: Enable Dev Log
#===========================================
proc enableDevLog {flag} {
    set ::enableDevLog $flag
}

#===========================================
# PROCEDURE: Dev Log
#===========================================
proc devLog {msg} {
    if {$::enableDevLog == 1} {
        puts "DEV: $msg"
    }
}

#===========================================
# PROCEDURE: GET SUBSTRING WITHIN STRINGS
#===========================================
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
# Certain hex values are reserved for control 
# codes. If any of these values end up in the 
# final string, they need to be replaced 
# according to this table:
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

#===========================================
# PROCEDURE: REVERSE ESCAPE CONTROL CODES
#===========================================
#-------------------------------------------
# Reverse procedure "Escape Control Codes"
#
# Control Code    Replaced With
#   0x1B 0x82       0x02
#   0x1B 0x83       0x03
#   0x1B 0x86       0x06
#   0x1B 0x95       0x15
#   0x1B 0x9B       0x1B
#-------------------------------------------
proc reverseEscapeControlCodes {message} {
    set new_message [string map {"1B, 82" 02 "1B, 83" 03 "1B, 86" 06 "1B, 95" 15 "1B, 9B" 1B} $message]
    return $new_message
}

#===========================================
# PROCEDURE: REVERSE FINALIZE CONTROL STRING
#===========================================
#-------------------------------------------
# Reverse procedure "Finalize Control String"
#-------------------------------------------
proc reverseFinalizeControlString {message} {
    set new_message [string trim [string trim $message "02, "] ", 03"]
    return $new_message
}