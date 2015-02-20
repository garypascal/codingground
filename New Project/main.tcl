set NUMBER_OF_ZONES 0
set NUMBER_OF_SOURCES 0

set ZONES [dict create]
set SOURCES [dict create]

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

loadParameters
puts $NUMBER_OF_ZONES
puts [dict get $ZONES 1]
puts [dict get $ZONES 2]
puts [dict get $ZONES 3]
puts [dict get $ZONES 4]
puts [dict get $SOURCES 1]