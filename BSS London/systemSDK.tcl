# =========================================================
# DO NOT CHANGE. the followings will be defined by C
# =========================================================
# varIfChanType  - 1:tcp 2:udp 3:multicast 4:broadcast 5:serial
# varIfAddress   - if varIfChanType 1~4, IP address that looks like "192.168.0.1".
#                  if varIfChanType 5, a file path that looks like "/dev/ttyS1".
# =========================================================
puts "systemSDK.tcl"

# include path to TCL packages
lappend auto_path /remote/Store/Prg/tclpkg/

# =========================================================
# External Procedure
# =========================================================
# procCtrlChannel - open/write/read/close channel
#  "open" protocol ip port [mode] [type]
#     protocol: "tcp"
#     ip      : server ip.
#     mode    : optional.
#     type    : optional.
#     return  : channel. "ch"+"pmtn" - p=t/u/m/b, m=c/s, t=s/b, n=socket number
#  "write" channel data [length]
#  "read"  channel [length]
#  "close" channel
#


# =========================================================
# Initialize source variables
# =========================================================
# 
# FIXME - Set the initial value
#
# =========================================================

set varIfRet		0;
set varIfMute		0;
set varIfPower		0;	# power status
set varIfSource		"";	# input
set varIfSRMode		"";	# surround mode
set varIfNewVal     "";	

set varIfDevice     "";
set varIfModule     "";
set varIfTitle      "";
set varIfArtist     "";
set varIfAlbum      "";
set varIfTrackLen   0;
set varIfTrackPos   0;
set varIfTrackNum   0;
set varIfTrackIdx   0;
set varIfPlayStatus -1;
set varIfRepeat     0;
set varIfShuffle    0;

set systemSDKSaveTheResultManual 1
set systemSDKSaveTheResultFlag 0
set systemSDKSaveTheResultBuf ""

set LOGENABLE 0
set localDirectory [file dirname [info script]]



#LOG functions
proc enableLOG { status } {
	global LOGENABLE
	set LOGENABLE $status
}

proc initializeLOG { } {
	global localDirectory
	

	if { [catch {set systemLOGfile [open "$localDirectory/systemLOG.txt" "w+"]} errID] } {
		puts "couldn't open systemLOG.txt\n$errID"
		set systemLOGfile 0
		#break
	} else {
		puts "Starting system LOG"
		puts $systemLOGfile "Starting system LOG"
		close $systemLOGfile
		set systemLOGfile 0
	}
	
	if { [catch {set clientLOGfile [open "$localDirectory/clientLOG.txt" "w+"]} errID] } {
		puts "couldn't open clientLOG.txt\n$errID"
		set clientLOGfile 0
		#break
	} else {
		puts "Starting client LOG"
		puts $clientLOGfile "Starting client LOG"
		close $clientLOGfile
		set clientLOGfile 0
	}
}
initializeLOG

proc LOG { data } {
	global LOGENABLE
	global localDirectory

	if { $LOGENABLE != 0 } {		
		if { [catch {set systemLOGfile [open "$localDirectory/systemLOG.txt" "a"]} errID] } {
			puts "couldn't open systemLOG.txt\n$errID"
			set systemLOGfile 0
			#break
		} else {
			puts "$data"
			puts $systemLOGfile "$data"
			close $systemLOGfile
			set systemLOGfile 0
		}		
	}
}


# copy an array
proc ProcCopyArray {dst src} {
	upvar $src from $dst to;
	foreach {index value} [array get from *] {
		set to($index) $value;
	}
}





# connect --
#
#       Creates a connection to the socket based on the parameters given   
#
# Arguments:
#		chtype	The type of connection to be made
#				1: TCP
#				2: UDP
#				3: Multicast
#				4: Broadcast
#				5: Serial
#		host	The ip address of the host server
#		port	The port to which the socket should be connected	
#
# Returns:
#		socketID	The id of the socket that was just connected.
#					If the connection could not be made then a TCL_ERROR will be returned
#
# Example:
#		connect 1 192.168.42.16 6001
#
set registeredSocketID 0
set registeredSerialID 0
proc connect {chtype host port {baudrate 9600} {databits 8} {parity 0} {stopbits 1}} {
	set socketID	0
	global registeredSocketID
	global registeredSerialID
	
	LOG "<Tcl> ProcOpenChannel $host:$port"
	
	# TCP
	if {$chtype == 1} {
		if {[catch {procCtrlChannel "open" "tcp" $host $port} socketID]} {
			LOG "<Tcl> ProcOpenChannel failed $socketID"
			return -code error 0
		} 
	# UDP
	} elseif {$chtype == 2} {
		if {[catch {procCtrlChannel "open" "udp" $host $port} socketID]} {
			LOG "<Tcl> ProcOpenChannel failed $socketID"
			return -code error 0
		}
	# Multicast
	} elseif {$chtype == 3} {
		if {[catch {procCtrlChannel "open" "mcst" $host $port} socketID]} {
			LOG "<Tcl> ProcOpenChannel failed $socketID"
			return -code error 0
		}
	# Broadcast
	} elseif {$chtype == 4} {
		if {[catch {procCtrlChannel "open" "bcast" $host $port} socketID]} {
			LOG "<Tcl> ProcOpenChannel failed $socketID"
			return -code error 0
		}
		# Serial
	} elseif {$chtype == 5} {
		if {[catch {procCtrlChannel "open" "serial" $host $baudrate $databits $parity $stopbits} socketID]} {
			LOG "<Tcl> ProcOpenChannel failed $socketID. SERIAL"
			return -code error 0
		}
	} else {
		LOG "<Tcl> Unknown channel type"
		return -code error 0
	}
	
	LOG "<Tcl> ProcOpenChannel succeeded $socketID"

	# Read response from channel
	if {[catch {procCtrlChannel "read" $socketID 0} varRecvLen]} {
		LOG "read error";
		return -code error 0;
	}

	#enable automatic reads
	if {$chtype == 5} {
		set registeredSerialID $socketID
	} else {
		set registeredSocketID $socketID
	}
	return $socketID
}





# read --
#
#       Checks the socket for data. It is called from with in the graphics tcl file
#		If data is present an attempt will be made to call the proc onData.
#		If the proc does not exist a error message will be displayed
#
# Arguments:
#		socketID	The ID of the socket to check
#		timeout		A timeout for how long to check for data
#
# Returns:
#		Will return an error if the socket can not be read
#
# Example:
#		read $socket1 1000
#
proc readSocket {socketID timeout} {
	global varRecvBuf
	global registeredSocketID
	global registeredSerialID
	
	if { $socketID != 0} {
		if {[catch {procCtrlChannel "read" $socketID $timeout} varRecvBuf]} {
			LOG "<Tcl> read failed"
			#try again
			if {[catch {procCtrlChannel "read" $socketID $timeout} varRecvBuf]} {
				LOG "<Tcl> client disconnected";
				if {[catch {onClose $socketID} errorCode]} {
					LOG "<Tcl> onClose not found"
				}
				if {$registeredSocketID == $socketID} {
					set registeredSocketID 0
				} elseif {$registeredSerialID == $socketID} {
					set registeredSerialID 0
				}
				return -code error 0;
			}
		}
		set varRecvLen [string length $varRecvBuf];
		if {$varRecvLen > 0} {
			LOG "<Tcl> -------------------------------";
			LOG "<Tcl> Received $varRecvLen bytes. $varRecvBuf";
			LOG "<Tcl> -------------------------------";
			
			if {$::systemSDKSaveTheResultManual == 0 && $::systemSDKSaveTheResultFlag == 1} {
				append ::systemSDKSaveTheResultBuf $varRecvBuf
			}
			if {[catch {onData $socketID $varRecvBuf} errorCode]} {
				LOG "<Tcl> onData not found"
			}
		}
	}
}





# send --
#
#		Sends data out the socket given by socketID
#
# Arguments:
#		socketID	The ID of the socket to send too
#		data		The data to be sent out the socket
#
# Returns:
#		Will return an error if the socket can not be read
#
# Example:
#		send $socket1 "Test socket"
#
proc send {socketID data} {

	LOG "<Tcl> ------------------------------"
	LOG "<Tcl> Send socket: $socketID $data"
	LOG "<Tcl> ------------------------------"
	
	
	set dataLen [string length $data]
	if {[catch {procCtrlChannel "write" $socketID $data $dataLen}]} {
		LOG "<Tcl> send failed"
		if {[catch {onClose $socketID} errorCode]} {
			LOG "<Tcl> onClose not found"
		}
		return -code error 0
	}
	#after 20000
}





# close --
#
#		Closes the socket
#
# Arguments:
#		socketID	The ID of the socket to close
#
# Returns:
#		
#
# Example:
#		closeSocket $socket1
#
proc closeSocket {socketID} {
	global registeredSocketID
	global registeredSerialID
	if {$socketID == $registeredSocketID} {
		set registeredSocketID 0
	} elseif {$socketID == $registeredSerialID } {
		set registeredSerialID 0
	}
	procCtrlChannel "close" $socketID
}


#puts "Starting online_closetest.tcl ..." 

proc OnCloseModule { } {
	if { [ catch { onModuleClose } ] } {
	}
}

#device_close OnCloseModule



#timer implementation
#proc onTimer { id } {
#	puts "--------------"
#	puts "--------------"
#	puts "onTimer id=$id"
#	puts "--------------"
#	puts "--------------"
#}
#set timer1 [setTimer 2000]
#set timer2 [setTimer 3000]
#clearTimer $timer1
#clearTimer $timer2

set tick_var 0 
set tick_time 200
set high_timer_id 0
dict set timers 0 active 0

proc clearTimer { idvalue_or_idname } {
	#**Supports both the old method of passing in the ID value and the new safer method of passing in the ID name
	#so that both the timer AND timer ID can be cleared together.**
	
	global timers
	global high_timer_id
	
	if { [ catch {expr {$idvalue_or_idname - $idvalue_or_idname}} ] == 0} {
		#puts "clearTimer: id VALUE was passed in"; #(i.e. "4")
		set id $idvalue_or_idname
	} else {
		#puts "clearTimer: id NAME was passed in"; #(i.e. "myTimerID")
		set id [set ::$idvalue_or_idname]
		set ::$idvalue_or_idname -1; #Clear the timer ID in the server script.
	}
	if {$id >= 0 && $id <= $high_timer_id} {
		dict set timers $id active 0
	}
}

proc setTimer { interval } {
	global tick_var
	global tick_time
	global high_timer_id
	global timers
	set done 0
	
	if { $interval <= 3600000 && $interval >= 100 } {
		#find next available id
		set counter 0
		dict for { id datavar } $timers {
			dict with datavar {
				if { $active == 0 } {
					set done 1
				}
			}
			if {$done == 0} {
				incr counter
			}
		}
		#puts [ expr { [ expr { $interval / $tick_time } ] + $tick_var } ]
		dict set timers $counter active 1
		dict set timers $counter timeout [ expr { $interval / $tick_time } ]
		dict set timers $counter endtime [ expr { [ expr { $interval / $tick_time } ] + $tick_var } ]
		
		if {$counter >= $high_timer_id} {
			incr high_timer_id		
			dict set timers $high_timer_id active 0
		}
		
		return $counter
	}
	return TCL_ERR
}

set timerhalfspeed 0

proc onTick {  } {
	global tick_var
	global high_timer_id
	global timers
	global registeredSocketID
	global registeredSerialID
	global timerhalfspeed
	#puts "onTick function $tick_var"
	
	dict for { id datavar } $timers {
		dict with datavar {
			if {$active == 1} {
				if {$tick_var >= $endtime} {
					dict set timers $id endtime [ expr { $tick_var + $timeout } ] 
					if { [ catch { onTimer $id } ] } {
						#puts "dne"
					}
				}
			}
		}
	}
	if { $registeredSocketID > 0 && $timerhalfspeed != 0} {
		readSocket $registeredSocketID 100
		set timerhalfspeed 0
	} elseif { $registeredSerialID > 0 && $timerhalfspeed != 0} {
		readSocket $registeredSerialID 100
		set timerhalfspeed 0
	} else {
		set timerhalfspeed 1
	}
	incr tick_var
}

#device_tick $tick_time onTick


proc saveTheResult {data} {
	if {$::systemSDKSaveTheResultFlag} {
		append ::systemSDKSaveTheResultBuf $data
	}
}


# =========================================================
# OnDevCmd
#   - Supports sending parameter to server for TCP Macro
#   - this procedure called by C.
#
#   - returned format: 1 on success or 0 on failure
# =========================================================
# 
# FIXME - 
#
# =========================================================
proc OnDevCmd { param_len param {cmd 0} {zone 0} {type 0} {address 0} {port_or_baud 0} {databits 0} {parity 0} {stopbits 0} {receive_option 0} {wait_time 0} } {
	global registeredSocketID
	global registeredSerialID
	puts "OnDevCmd...";
	puts "this procedure is used for TCP Macro";

	puts "param_len = $param_len, param=<$param>";
	puts "cmd = $cmd"
	
	puts "======================================";
	puts "zone = $zone";
	puts "type = $type";
	puts "address = <$address>";
	puts "port/baud = $port_or_baud";
	puts "databits = $databits";
	puts "parity = $parity";
	puts "stopbits = $stopbits";
	puts "receive_opt = $receive_option";
	puts "wait_time = $wait_time";
	puts "======================================";

	set zone [expr { $zone + 1 } ]
	#
	# TODO
	#
	
	if {$cmd == 0} {
		if {$type == 3} {
			# try to call send override
			if {[catch {sendOverride $registeredSerialID $param $receive_option $wait_time }]} {
				if {[catch {sendOverride $registeredSerialID $param }]} {
					set ::systemSDKSaveTheResultManual 0
					# Send the given param to AVR. Write request to channel
					if {$registeredSerialID == 0} {
						# connect to serial
						set registeredSerialID [connect 5 $address 0 $port_or_baud $databits $parity $stopbits]
					}
					if {[catch {send $registeredSerialID $param }]} {
						LOG "Cannot write to channel";
						return 0;
					}
				}
			}
		} else {
			# try to call send override
			if {[catch {sendOverride $registeredSocketID $param $receive_option $wait_time }]} {
				if {[catch {sendOverride $registeredSocketID $param }]} {
					set ::systemSDKSaveTheResultManual 0
					if {$registeredSocketID == 0} {
						# connect to TCP socket
						set registeredSocketID [connect $type $address $port_or_baud]
					}
					# Send the given param to AVR. Write request to channel
					if {[catch {send $registeredSocketID $param }]} {
						LOG "Cannot write to channel";
						return 0;
					}
				}
			}
		}
		if { $receive_option == 1 } {
			puts "Start receive...";
			# To do...
			# clear receive buffer...
			set ::systemSDKSaveTheResultBuf ""
			set ::systemSDKSaveTheResultFlag 1
		}
	} elseif {$cmd == 2} {
		puts "this procedure is used for Save_the_result...";
		# To do...
		# send received buffer
		set ::systemSDKSaveTheResultFlag 0
		set length [string bytelength $::systemSDKSaveTheResultBuf]
		return "$length\t$::systemSDKSaveTheResultBuf"
	} elseif {$cmd == 3} {
		puts "this procedure is used for TRF-ZW1 1-way command"
		if {[catch {TRFZWCommand $param }]} {
			puts "\"TRFZWCommand param\" expected but not found"
		}
	} elseif {$cmd == 4} {
		if { [catch {set returndata [ExecuteMacroQuery $param] } ] } {
			return "0\t"
		}
		set returnlength [string bytelength $returndata]
		return "$returnlength\t$returndata"
	} else {
		puts "this procedure is used for Volume feedback command";
		if { $param eq "SETVOL"} {
			catch { VolumePopupSetVolume $zone [expr {$param_len / 10.0} ] }
		}
		set localVarIfMin [expr int($::varIfMin * 10)]
		set localVarIfMax [expr int($::varIfMax * 10)]
		set localVarIfVol [expr int($::g_arrStatus($zone.dwVolume) * 10)]
		
		set retbuf [format "%d\t%d\t%d\t%d\t%s" $localVarIfVol $localVarIfMin $localVarIfMax $::g_arrStatus($zone.dwMute) $::g_arrStatus($zone.dwInput)];
		return $retbuf;
	}
		
	return 0;
}

# =========================================================
# Register procedure for TCP Macro
# =========================================================
#device_cmd OnDevCmd



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