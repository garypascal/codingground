source [file dirname [info script]]/BSS_London_Util.tcl

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

loadParameters
puts $NUMBER_OF_ZONES
puts [dict get $ZONES 1]
puts [dict get $ZONES 2]
puts [dict get $ZONES 3]
puts [dict get $ZONES 4]
puts [dict get $SOURCES 1]