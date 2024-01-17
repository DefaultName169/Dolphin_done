#!/usr/bin/tclsh*

set ingds  [lindex $argv 0]
set outgds [lindex $argv 1]
set inckt  [lindex $argv 2]
#set fkeepinstance "/data/projects/memory_compiler2/mem_qa/user_quyet/test/keepinstance.tcl"
set setlayernameperl "/data/projects/memory_compiler2/scripts/GEN_XRC/printlayerprops.pl"
set procglobal "/data/projects/memory_compiler2/scripts/GEN_XRC/proc_global.tcl"
#set setlayername "/data/projects/stdcells/layout/kientc0/cutoption/notremove/layerprop.tcl"

regsub {memarrayll} $outgds {memarrayllpg} outgds

exec perl $setlayernameperl layerprop.tcl
source layerprop.tcl
source $procglobal
#puts $layerprops

if { $ingds eq "" || $outgds eq "" || $inckt eq "" } {
  puts stderr "Usage: calibredrv $argv0 <input gds> <output gds> <input ckt>"
  exit 1
}

set name_gds_in [file tail [file rootname $ingds]]
set name_ckt [file tail [file rootname $inckt]]
set name_gds_out [file tail [file rootname $outgds]]

set type ""
if {![regexp {tm([0-9]+)} $name_gds_in match num]} {
  set num [lindex $argv 3]
}

if {[regexp "(center|trk|rep|wlrep)" $name_gds_out match option_cut] } {
  set option_cut $option_cut
} elseif {[regexp {^memarray} $name_gds_out]} {
  set option_cut "mem"
} else {
  puts "Name output absurd !!!!!!!!!\n Not file option to cut"
  exit
}

if {[dict exists $layerprops "tsmc${num}" ]} {
  set layername [dict get $layerprops "tsmc${num}"]
  set type "tsmc${num}"
} else {
  set layername [dict get $layerprops "default"]
  set type "default"
}

source "/data/projects/memory_compiler2/scripts/GEN_XRC/for_${option_cut}.tcl"

if {![info exists re_ckt]} {
  puts "MISSING variable \$re_ckt in file for_${option_cut}\n\$re_ckt is regexp to read pin\n\$re_ckt is mandatory"
  exit
}

if {![info exists re_bbox]} {
  puts "MISSING variable \$re_bbox in file for_${option_cut}\n\$re_bbox is regexp to define the clipping area of bbox \n\$re_bbox is mandatory"
  exit
}

if {[info procs bbox_cut] == ""} {
  puts "MISSING function bbox_cut\n function bbox_cut to define the clipping area of bbox \nbbox_cut is mandatory"
  exit
}

if {[info procs keeptext] == ""} {
  puts "MISSING function keeptext\n function keeptext to keep the desired texts\nkeeptext is mandatory"
  exit

}

########################################## MAIN ############################################
set L [layout create $ingds -dt_expand]
set topc [$L topcell]
set layers [$L layers]

set i 0
set layernameprops $layername
while {$i < [llength $layername]} {
  if {[lsearch $layers [lindex $layername [expr $i + 1]]] < 0} {
    set layername [lreplace $layername $i [expr $i + 1]]
    continue
  }
  set i [expr $i + 2]
}

#puts [dictregexp $layername {via}]
#exit
####################################################################################

set name_gds_out [lindex [split $name_gds_out "."] 0]
set refs [$L iterator ref $topc range 0 end -depth 0 0]

set fp [open $inckt r]
set ckt_file [read $fp]

#save all port in ckt file
set re_vddport ""

if {[regexp $re_ckt $ckt_file match sub] } {
  set clean [string map {"\n+" ""} $sub]
  set ports [split $clean ]
  foreach port $ports  {
    set port [string toupper $port]
    if {!($port == "" || [regexp {^(VDD|VSS)} $port]) } {
      lappend all_port [string toupper $port]
    }
    if {[regexp {^(VDD|VSS)} $port]} {
      lappend vddport $port
      if {$re_vddport == ""} {
        set re_vddport [format "^%s$" $port]
      }
      set re_vddport [format "%s|^%s$" $re_vddport $port]
    }
  }
}

puts "vddport : $vddport"

puts "KEEP PORT :  $all_port"
set last_path ""
set bbox []
set layers [$L layers]
set new_poly []

# puts $layers

##################################### get all bbox cell of level 1 ##############################################
set allbbox [get_bbox_of_ref $topc $layername]

##################################### get zone of cut ##########################################
foreach bbox $allbbox {
  set name [lindex $bbox 0]
  set x1 [lindex [lindex $bbox 3] 0]
  set y1 [lindex [lindex $bbox 3] 1]
  set x2 [lindex [lindex $bbox 3] 2]
  set y2 [lindex [lindex $bbox 3] 3]
  if { [regexp $re_bbox $name ] } {
    lappend bbox_x $x1 $x2
    lappend bbox_y $y1 $y2
  }
  # if {[lindex [lindex $bbox 3] 4] != "not_bbox"} {
  #   puts $bbox
  # }
}

set bbox_x [ lsort -unique -integer $bbox_x]
set bbox_y [ lsort -unique -integer $bbox_y]

puts "bbox_x : $bbox_x"
puts "bbox_y : $bbox_y"

#proc bbox_cut in path ./option/for_...
set bbox_cut [bbox_cut]
set outfile [open "BBOX_CUT.drc" w]
set string "bbox_cut 2000\nBBOx_CUT\n1 1 0 [clock format [clock seconds] -format "%b %d %H:%M:%S %Y"]"
set x1 [lindex $bbox_cut 0]
set y1 [lindex $bbox_cut 1]
set x2 [lindex $bbox_cut 2]
set y2 [lindex $bbox_cut 3]
set string "$string\np 1 4\n$x1 $y1\n$x1 $y2\n$x2 $y2\n$x2 $y1"
puts $outfile $string
close $outfile


puts "bbox_cut: $bbox_cut"

################################################# get ref to delete after ##############################################

foreach bbox $allbbox {
  set name [lindex $bbox 0]
  set x1 [lindex [lindex $bbox 3] 0]
  set y1 [lindex [lindex $bbox 3] 1]
  set x2 [lindex [lindex $bbox 3] 2]
  set y2 [lindex [lindex $bbox 3] 3]
 
  if {[info exists re_ref_del_more]} {
    if {[regexp $re_ref_del_more $name]} {
      lappend ref_cut [lindex $bbox 1]
      continue
    }
  }

  if { ([lindex $bbox_cut 0] <= $x1 && [lindex $bbox_cut 2] >= $x2  &&  [lindex $bbox_cut 1] <= $y1 && [lindex $bbox_cut 3] >= $y2) || \
    ([point_inside_box [expr ($x1 + $x2) /2] [expr ($y1 + $y2) /2] $bbox_cut] && [lindex [lindex $bbox 3] 4] == "not_bbox") } {
    #puts $name
    lappend cell_inside $name
    # set re_check [format "(^|\|)%s(\\\||$)" $name]
    lappend zone_x [lindex [lindex $bbox 2] 0] [expr [lindex [lindex $bbox 2] 0] + [lindex [lindex $bbox 2] 2]]
    lappend zone_y [lindex [lindex $bbox 2] 1] [expr [lindex [lindex $bbox 2] 1] + [lindex [lindex $bbox 2] 3]]
    # if { $re_cell_inside == "" } {
    #   set re_cell_inside $name
    # } else
    # if {![regexp $re_check $re_cell_inside ]} {
    #   set re_cell_inside [format "%s|%s(\\\/|$)" $re_cell_inside $name]
    # }
  } else {
    lappend ref_cut [lindex $bbox 1]
  }
}

set re_cell_inside "$topc$"
set cell_inside [lsort -unique $cell_inside]

foreach cell $cell_inside {
  set re_cell_inside [format "%s|%s(\\\/|$)" $re_cell_inside $cell]
}


set zone_x [ lsort -unique -integer $zone_x]
set zone_y [ lsort -unique -integer $zone_y]
# puts $re_cell_inside
if {[info procs zone_cut] != ""} {
  set zone_cut [zone_cut]
  puts "zone_cut : $zone_cut"
}


####################################################### keep text ######################################################################
set layers [$L layers]
set new_text []

set layer_text [dictregexp $layername {_pintxt}]
set hasbk []
set skipbk "COREPWS_N_BUF|LKRB_N_BUF|LOLEAK_N_BUF"
if {[regexp {sp{1,3}mb} $name_gds_in]} {
  for {set i 0} {$i < [llength $all_port]} {incr i} {
    if {[regexp {(.*)_BK[0-9]$} [lindex $all_port $i] match pin] && ![regexp $skipbk [lindex $all_port $i]]} {
      # lappend all_port $pin
      set all_port [lreplace $all_port $i $i $pin]
      lappend hasbk $pin
    }
  }
  set all_port [lsort -unique $all_port]
  set hasbk [lsort -unique $hasbk]
  puts "HAVE BK: $hasbk"
}

set textkeep [keeptext]
#######################################################################################################################################################



############################################# keep more polygon ###############################################
if {[info procs keep_more_poly] != "" } {
  set new_poly [keep_more_poly]
}


########################################### delete ref saved before #############################
puts "start delete ref"
foreach ref $ref_cut {
  # try {
    $L delete ref $topc {*}$ref
  # } on error err {
  #   continue
  # }
  
}

puts "done"
############################################### get more polygon (if want, set in ./option/for_...) ######################################################################

puts "start delete text"
###################################################### delete all text ##################################################################
foreach lay $layers {
  set texts [$L iterator text $topc $lay range 0 end -depth 0 20]

  foreach txt $texts {
    set path [lindex $txt 1]
    set name_lay [lindex [split $path "/"] end]
    set this_text [$L iterator text $name_lay $lay range 0 end]

    foreach this $this_text {
      #puts [format "DELETE TEXT %s" [lindex $this 0]]
      $L delete text $name_lay $lay [lindex $this 1] [lindex $this 2] [lindex $this 0]
    }
  }
}
puts "done"

set toplay [$L layers -cell $topc]
if {$option_cut == "trk"} {
  set L1 [layout copy $L newlayout $topc 0 0 {*}$zone_cut 2]
} else {
  set L1 [layout copy $L newlayout $topc 0 0 {*}$bbox_cut 2]
}


foreach lay $toplay {
  $L delete polygons $topc $lay
}
$L import layout $L1 TRUE append


################################################### add saved polygon before ####################################################
# if { [info exists new_poly] } {
foreach poly $new_poly {
  puts $poly
  try {
    $L create polygon $topc {*}$poly
  } on error err {
    $L create polygon $topc {*}[lreplace $poly end end]
  }
  
}


###################################### add saved text before ###########################################
puts "-----------------------------------------\n\n\n\n--------------------------------------------"
if {[info procs move_pin] != ""} {
  set new_text [move_pin]
}

# set new_text [lsort -integer -index 1 $new_text]
set start []
set end []

foreach txt $textkeep {
  $L create text $topc {*}$txt
} 
############################################# rename and save topc ###################################################
$L cellname $topc $name_gds_out

foreach top [$L topcell all] {
  if {$top != $name_gds_out} {
    $L delete cell $top -deleteChildCells
  }
}

$L gdsout $outgds