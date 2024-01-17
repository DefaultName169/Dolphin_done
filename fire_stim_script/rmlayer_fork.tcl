#!/usr/bin/tclsh

set ingds  [lindex $argv 0]
set type  [lindex $argv 1]
set pp1 [lindex $argv 2]

if { $ingds eq "" || $type eq "" } {
  puts stderr "Usage: calibredrv $argv0 <input gds> <input type>"
  exit 1
}

set name_gds_in [lindex [split [lindex [split $ingds "/"] end] "."] 0]
set start [clock clicks -milliseconds]
regexp {tsmc([0-9]+)} $type match num

if {[regexp {40|55|65|28|22} $num]} {
  set rmlayer "/data/projects/memory_compiler2/scripts/SCRIPTS/map_fe_remove"
} elseif {[regexp {12|16} $num]} {
  set rmlayer "/data/projects/memory_compiler2/scripts/SCRIPTS/map_fe_remove_16"
} elseif {[regexp {06|07} $num]} {
  set rmlayer "/data/projects/memory_compiler2/scripts/SCRIPTS/map_fe_remove_06"
} elseif {[regexp {05} $num]} {
  set rmlayer "/data/projects/memory_compiler2/scripts/SCRIPTS/map_fe_remove_05"
} elseif {[regexp {03} $num]} {
  set rmlayer "/data/projects/memory_compiler2/scripts/SCRIPTS/map_fe_remove_03"
} else {
  puts "Not exists Type"
  exit
}

######################################## FUNCTION #######################################

########################################## MAIN ############################################
set L [layout create $ingds -dt_expand]
set topc [$L topcell]
set layers [$L layers]

set fp [open $rmlayer]
puts "read layer from $rmlayer"
set lines [split [read $fp] "\n"]
close $fp

# set L1 [layout copy2 $L $topc {*}[$L bbox $topc]]

set children [$L children $topc]

layout create -type gds -handle layout1

set L1 layout1

proc copy_children {cell} {
  global L 
  global L1    
  puts $cell
  set children [$L children $cell] 
  if {[lsearch [$L1 cells] $cell] < 0} {
    foreach child $children {
      copy_children $child
    }
    $L1 create cell $cell $L $cell
  }
  foreach ref [$L iterator ref $cell range 0 end] {
    $L1 create ref $cell {*}$ref
  }
}


foreach child $children {
  if {[regexp {_pins_|all_pin} $child]} {  
    copy_children $child
  }
}


proc sort_layout {a b} {
  regexp {layout(.*)} $a match numa
  regexp {layout(.*)} $b match numb
  if {$numa < $numb} {
    return 0
  }
  return 1
}

foreach line $lines {
  set lay [split $line " "]
  if {[lindex $lay 1] != 0} {
    set lay [format "%s.%s" [lindex $lay 0] [lindex $lay 1]]
  } else {
    set lay [lindex $lay 0]
  }
  if {[lsearch $layers $lay] >= 0} {
    if {[$L exists layer $lay]} {
      if {![regexp {^3[0-9]} $lay]} {
        $L1 delete layer $lay
      }
      puts "delete layer $lay"
      $L delete layer $lay
    }
    
  }
}

# $L1 gdsout "test.gds"
$L import layout $L1 TRUE overwrite


if {$pp1 == "pp1"} {
  set changed []
  set skip "mem_hc|mem_hd|bpo_rep|^all"
  set not_change_bbox "xdec|wlrep"
  set refs [$L iterator ref $topc range 0 end]
  set cells [$L cells]
  ###### delete cell pp1 available #######
  foreach cell $cells {
    if {[regexp "_$pp1$" $cell]} {
      puts "delete cell $cell"
      $L delete cell $cell
    }
  }
  # $L gdsout [format "%s_clean.gds" $name_gds_in]

  ###### copy old cell to new cell and rename cell to cell_pp1 ##### 
  set L_new [layout copy2 $L $topc {*}[$L bbox $topc]]
  set cells [$L_new cells]

  foreach cell $cells {
    if {![regexp $skip $cell]} {
      $L_new cellname $cell [format "%s_%s" $cell $pp1] 
    }
  }


  ###### change bbox #########
  set children [$L_new children $topc]
  for {set i 0} {$i < [llength $children]} {incr i} {
    set child [lindex $children $i]
    if {[regexp $skip $child]} {
      if {[regexp {^all} $child]} {
        lappend children {*}[$L_new children $child]
      }
      continue
    }
    if {[regexp $not_change_bbox $child]} {
      continue
    }
    set polys [$L_new iterator poly $child 108 range 0 end]
    foreach poly $polys {
      set x [lsort -integer [list [lindex $poly 0] [lindex $poly 4] ] ]
      set y [lsort -integer [list [lindex $poly 1] [lindex $poly 5] ] ]    
      set x1 [lindex $x 0]
      set x2 [lindex $x 1] 
      set y1 [lindex $y 0]
      set y2 [expr ([lindex $y 1] - [lindex $y 0])/51*57]
      $L_new delete polygon $child 108 {*}$poly
      $L_new create polygon $child 108 $x1 $y1 $x1 $y2 $x2 $y2 $x2 $y1
    }
    puts "creat cell $child"
  }
  $L import layout $L_new TRUE append

  ####### delete duplicate text on top cell ###########
  set layers [$L layers]
  set save []
  foreach lay $layers {
    set texts [$L iterator text $topc $lay range 0 end]
    foreach text $texts {
        set form [format "%s %s %s %s" $lay [lindex $text 1] [lindex $text 2] [lindex $text 0]] 
        if {[lsearch $save $form] >= 0} {
          continue
        }
        lappend save $form
        $L delete text $topc $lay [lindex $text 1] [lindex $text 2] [lindex $text 0] 
    }
  }
} 

set name_gds_out [format "%s_vt" $name_gds_in]

############################################# rename and save topc ###################################################
# $L cellname $topc $name_gds_in
$L gdsout [format "%s.gds" $name_gds_out]
set run_time [expr [clock clicks -milliseconds] - $start]
puts [format "TOTAL TIME RUN : %s min %s.%s seconds" [expr $run_time / 60000] [expr  $run_time /1000 % 60] [expr $run_time %1000]]
