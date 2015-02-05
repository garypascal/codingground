set message_send "90, 00, 00, 03, 00, 01, 10, 00, 00, 00, 01, 00, 00"

#===========================================
# PROCEDURE: FINALIZE CONTROL STRINGS
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
proc finalizeControlStrings {message} {
    return "02, " [escapeControlCodes $message] ", " [getChecksum $message] ", 03"
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
    set new_message ""
    set i 0
    while {$i < [string length $message]} {
        set byte [string index $message $i][string index $message [expr {$i + 1}]]
        if {$byte == 02} {
            append new_message "1B, 82, "
        } elseif {$byte == 03} {
            append new_message "1B, 83, "
        } elseif {$byte == 06} {
            append new_message "1B, 86, "
        } elseif {$byte == 15} {
            append new_message "1B, 95, "
        } elseif {$byte == "1B"} {
            append new_message "1B, 9B, "
        } else {
            append new_message $byte
        }
        set i [expr {$i + 4}]
    }
    return $new_message
}

puts [finalizeControlStrings $message_send] 
