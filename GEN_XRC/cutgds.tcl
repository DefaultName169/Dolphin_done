#!/usr/bin/tclsh*

set ingds  [lindex $argv 0]
set outgds [lindex $argv 1]
set inckt  [lindex $argv 2]
#set fkeepinstance "/data/projects/memory_compiler2/mem_qa/user_quyet/test/keepinstance.tcl"
set setlayernameperl "/data/projects/memory_compiler2/scripts/GEN_XRC/printlayerprops.pl"
set procglobal "/data/projects/memory_compiler2/scripts/GEN_XRC/proc_global.tcl"
#set setlayername "/data/projects/stdcells/layout/kientc0/cutoption/notremove/layerprop.tcl"


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
regexp {tm([0-9]+)} $name_gds_in match num

if {![regexp "(center|trk|rep|wlrep)" $name_gds_out match option_cut] } {
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
if {[regexp $re_ckt $ckt_file match sub] } {
  set clean [string map {"\n+" ""} $sub]
  set ports [split $clean ]
  foreach port $ports  {
    if {!($port == "" || [regexp {^(VDD|VSS)} $port]) } {
      lappend all_port [string toupper $port]
    }
    if {[regexp {^(VDD|VSS)} $port]} {
      lappend vddport $port
    }
  }
}

puts "vddport : $vddport"

puts "KEEP PORT :  $all_port"
set last_path ""
set bbox []
set layers [$L layers]

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
set bbox_cut [bbox_cut $bbox_x $bbox_y]


puts "bbox_cut: $bbox_cut"

################################################# get ref to delete after ##############################################
set re_cell_inside "$topc$"
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
    set re_check [format "(^|\|)%s(\||$)" $name]
    lappend zone_x [lindex [lindex $bbox 2] 0] [expr [lindex [lindex $bbox 2] 0] + [lindex [lindex $bbox 2] 2]]
    lappend zone_y [lindex [lindex $bbox 2] 1] [expr [lindex [lindex $bbox 2] 1] + [lindex [lindex $bbox 2] 3]]
    # if { $re_cell_inside == "" } {
    #   set re_cell_inside $name
    # } else
    if {![regexp $re_check $re_cell_inside ]} {
      set re_cell_inside [format "%s|%s" $re_cell_inside $name]
    }
  } else {
    lappend ref_cut [lindex $bbox 1]
  }
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

if {[regexp {sp{1,3}mb} $name_gds_in]} {
  for {set i 0} {$i < [llength $all_port]} {incr i} {
    if {[regexp {(.*)_BK[0-9]$} [lindex $all_port $i] match pin]} {
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

# foreach lay $layer_text {
#   set texts [$L iterator text $topc $lay range 0 end -depth 0 20]
#   foreach txt $texts {
#     set txt_x [lindex [lindex $txt 0] 1]
#     set txt_y [lindex [lindex $txt 0] 2]
#     set txt_str [string toupper [lindex [lindex $txt 0] 0]]
#     set path [lindex $txt 1]
#     set split_name [split $path "/"]
#     set depth [expr [llength $split_name] - 1]
#     set name_lay [lindex $split_name $depth]

#     if { [regexp "^(VDD|VSS)(ULL|C|P)?:?$" $txt_str match] && $lay == [dict get $layername "m4_pintxt"] && $txt_y > [lindex $bbox_cut 1] && $txt_y < [lindex $bbox_cut 3] } {
#       set match [regsub {:} $match {}]
#       if {[regexp {(VDD|VSS)(ULL|C|P)} $match all one two]} {
#         if {$two == "ULL"} {
#           set two "_VUL"
#         }
#         # if {$two == "C"} {
#         #   set two ""
#         # }
#         set txt_str [format "%s%s" $one $two]
#       }

#       if { ![point_inside_box $txt_x $txt_y $bbox_cut] } {
#         if {[abs [expr $txt_x - [lindex $bbox_cut 0]]] < [abs [expr $txt_x - [lindex $bbox_cut 2]]] } {
#           set txt_x [lindex $bbox_cut 0]
#         } else {
#           set txt_x [lindex $bbox_cut 2]
#         }
#       }
#       lappend new_text [list $lay $txt_x $txt_y $txt_str]
#     } elseif {[regexp "^(VDD|VSS)_DR:?$" $txt_str ] && $lay == [dict get $layername "m4_pintxt"] && [point_inside_box $txt_x $txt_y $bbox_cut]} {
#       lappend new_text [list $lay $txt_x $txt_y $txt_str]
#     } else {
#       set new_text [keeptext $txt $lay]
#     }
#   }
# }
#######################################################################################################################################################



############################################# keep more polygon ###############################################
if {[info procs keep_more_poly] != "" } {
  set new_poly [keep_more_poly]
}


########################################### delete ref saved before #############################
puts "start delete ref"
foreach ref $ref_cut {
  $L delete ref $topc {*}$ref
}

puts "done"
############################################### get more polygon (if want, set in ./option/for_...) ######################################################################


################################################### cut polygon ###############################################################

# set layer_cut $layers
# foreach lay $layer_cut {
#   set polygon [$L iterator poly $topc $lay range 0 end]
#   foreach poly $polygon {
#     set x [lsort -integer [list [lindex $poly 0] [lindex $poly 4]]]
#     set y [lsort -integer [list [lindex $poly 1] [lindex $poly 5]]]
#     set x1 [lindex $x 0]
#     set x2 [lindex $x 1]
#     set y1 [lindex $y 0]
#     set y2 [lindex $y 1]
#     $L delete polygon $topc $lay {*}$poly 
    
#     if {$x2 > [lindex $bbox_cut 2]} {
#       set x2 [lindex $bbox_cut 2]
#     }
#     if {$x1 < [lindex $bbox_cut 0]} {
#       set x1 [lindex $bbox_cut 0]
#     }
#     if {$y2 > [lindex $bbox_cut 3]} {
#       set y2 [lindex $bbox_cut 3]
#     }
#     if {$y1 < [lindex $bbox_cut 1]} {
#       set y1 [lindex $bbox_cut 1]
#     }
#     if {$x1 > $x2 || $y1 > $y2} {
#       continue
#     }
#     $L create polygon $topc $lay $x1 $y1 $x2 $y1 $x2 $y2 $x1 $y2
#   }
# }


# set i 0
# while {$i < [llength $new_text] || [ regexp {^(VDD|VSS)_DR} [lindex [lindex $new_text $i] 3] ]} {
#   if {[lindex $new_text $i] == "rm"} {
#     set new_text [lreplace $new_text $i $i]
#     continue
#   }
#   set i [expr $i + 1]
# }







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
set L1 [layout copy $L newlayout $topc 0 0 {*}$bbox_cut 2]

foreach lay $toplay {
    $L delete polygons $topc $lay
}
$L import layout $L1 TRUE append


################################################### add saved polygon before ####################################################
if { [info exists new_poly] } {
  foreach poly $new_poly {
    #puts $poly
    $L create polygon $topc [lindex $poly 0]  [lindex $poly 1]  [lindex $poly 2] [lindex $poly 3] \
      [lindex $poly 4]  [lindex $poly 5]  [lindex $poly 6] [lindex $poly 7] \
      [lindex $poly 8]
  }
}

# set layer_text [dictregexp {_pintxt} $layername]

# foreach lay $layer_text {
#   while {1} {
#     set texts [$L iterator $topc $lay $range 0 end -depth 0 20]
#     set path [lindex [split [lindex [lindex $texts 0] 1] "/"] end]
#     if {[length $texts] == 0} {
#       break
#     }
#     set text [$L iterator $path $lay $range 0 end] 
#     foreach t $text {
#       $L delete text $path $lay [lindex $t 1] [lindex $t 2] [lindex $t 0]
#     }
#   } 
# }


###################################### add saved text before ###########################################
puts "-----------------------------------------\n\n\n\n--------------------------------------------"
if {[info procs move_pin] != ""} {
  set new_text [move_pin]
}

# set new_text [lsort -integer -index 1 $new_text]
set start []
set end []

foreach txt $textkeep {
  # set lay [dict get $layername [format "m%s_pintxt" [lindex $txt 0]]]
  # set txt_x [lindex $txt 1]
  # set txt_y [lindex $txt 2]
  # set txt_str [lindex $txt 3]
  
  $L create text $topc {*}$txt
} 

# for {set i 0} {$i < [llength $new_text]} {incr i} {
#   if {[regexp {(VDD|VSS)_VUL} [lindex [lindex $new_text $i] 3]]} {
#     lappend vul [list $i [lindex $new_text $i]]
#   }
# }

# for {set i 0} {$i < [llength $vul]} {incr i} {
#   set v [lindex $vul $i]
#   if {[lindex $v end] == "done"} {
#     continue
#   }
#   set list_v [lsearch -all -index {4 1} $vul [lindex [lindex $v 4] 1]]
#   set list_v [lsort -index {4 0} $list_v]
#   for {set j }
# }

# foreach txt $new_text {
#   set txt_str [lindex $txt 3]
#   if { [regexp {OUTR(_[A-Z])?} [lindex $txt 4] all match ] } {
#     #if {$match != ""} {
#     #  set match [format "%s" $match]
#     #}
#     if { [lsearch -exact $start $match] >= 0 } {
#       set int [lsearch -index 4 $end $all]
#       if { $int >= 0 } {
#         puts [format "CREATE TEXT %s %s %s %s" [lindex [lindex $end $int] 0] [lindex [lindex $end $int] 1] [lindex [lindex $end $int] 2] [lindex [lindex $end $int] 3]]
#         $L create text $topc [lindex [lindex $end $int] 0]  [lindex [lindex $end $int] 1]  [lindex [lindex $end $int] 2]  [lindex [lindex $end $int] 3]
#         set end [lreplace $end  $int $int ]
#       }
#       lappend end [list [lindex $txt 0] [lindex $txt 1]  [lindex $txt 2] [lindex $txt 3] $all  [format "WLR%s_NEAR" $match]]

#     } else {
#       puts [format "CREATE TEXT %s %s %s %s" [lindex $txt 0]  [lindex $txt 1]  [lindex $txt 2]  [format "WLR%s_FAR" $match]]
#       $L create text $topc [lindex $txt 0]  [lindex $txt 1]  [lindex $txt 2]  [format "WLR%s_FAR" $match]
#       lappend start $match
#     }
#   } else {
#     if {[regexp {_dr_} $name_gds_in]} {
#       if {$txt_str == "VDD_INT"} {
#         set txt_str "VDDP" 
#       }
#       if {$txt_str == "VDD"} {
#         set txt_str "VDDC"
#       }
#     }
#     if {[regexp {^(VDD|VSS)} $txt_str match] } {
#       if {[lsearch $vddport $txt_str] < 0} {
#         if {[regexp {_INT} $txt_str]} {
#           continue
#         }
#         set txt_str $match
#       }
#       if {$txt_str == "VDD" } {
#         set txt_str "VDD_INT_BK0"
#       }
#       set txt_str [format "%s:" $txt_str]
#     }
    
#     puts [format "CREATE TEXT %s %s %s %s" [lindex $txt 0]  [lindex $txt 1]  [lindex $txt 2]  $txt_str]
#     $L create text $topc [lindex $txt 0]  [lindex $txt 1]  [lindex $txt 2]  $txt_str
#   }
# }
# foreach e $end {
#   puts [format "CREATE TEXT %s %s %s %s" [lindex $e 0]  [lindex $e 1]  [lindex $e 2]  [lindex $e 5]]
#   $L create text $topc [lindex $e 0]  [lindex $e 1]  [lindex $e 2]  [lindex $e 5]
# }




############################################# rename and save topc ###################################################
#puts $new_layer

$L cellname $topc $name_gds_out

foreach top [$L topcell all] {
  if {$top != $name_gds_out} {
    $L delete cell $top -deleteChildCells
  }
}

$L gdsout $outgds