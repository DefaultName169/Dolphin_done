set re_ckt ".subckt ${name_ckt}(.*?)\nx"
set re_bbox "_mem_" 

proc bbox_cut {} {
  global bbox_x 
  global bbox_y
  return [list [lindex $bbox_x 0] [lindex $bbox_y 0] [lindex $bbox_x end] [lindex $bbox_y end]]
}

proc zone_cut {} {
  global zone_x
  global zone_y
  return [list [lindex $zone_x 0] [lindex $zone_y 0] [lindex $zone_x end] [lindex $zone_y end]]
}

proc keeptext {} {
  global L
  global topc
  global layername
  global all_port
  global vddport
  global re_cell_inside
  global new_poly
  global bbox_cut
  global zone_cut
  global name_gds_out
  global layernameprops

  set ports $all_port
  lappend port "VSS"

  set layer_connect [connect_lvl 0 3 {(?!_mem_)}]

  for {set lvl 4} {$lvl >= 0} {set lvl [expr $lvl - 1]} {
    if {[dict exist $layername [format "m%s_pintxt" $lvl]]} {
      set layer_text [dict get $layername [format "m%s_pintxt" $lvl]]
    } else {
      continue
    }
    
    set layer_poly [dictregexp $layername [format "met%s($|2$|b$)" $lvl]]
    
    set texts [$L iterator text $topc $layer_text range 0 end -depth 0 1]
    if {[expr $lvl % 2] == 0} {
      set texts [lsort -command sort_text_even $texts]
    } else {
      set texts [lsort -command sort_text_odd $texts]
    }

    foreach ori_layer $layer_poly {
      if {[dict exist $layer_connect $ori_layer]} {
        set lay [dict get $layer_connect $ori_layer]
      } else {
        set lay $ori_layer
      }
      puts "---------------------$lay-----------------------------"
      set polygons [$L iterator poly $topc $lay range 0 end] 
      foreach poly $polygons {
        set i 0
        set x1 [lindex $poly 0]
        set y1 [lindex $poly 1]
        set x2 [lindex $poly 4]
        set y2 [lindex $poly 5]
        set all_find []
        while {$i < [llength $texts]} {
          set depth [expr [llength [split [lindex [lindex $texts $i] 1] "/"]] - 2]
          set t [lindex [lindex $texts $i] 0]          
          set txt_x [lindex $t 1]
          set txt_y [lindex $t 2]     
          set ori_str [lindex $t 0]
          set txt_str [string toupper $ori_str]
          
          regsub {:} $txt_str {} txt_str
        
          if {[lsearch -exact $ports $txt_str] < 0 && !([regexp {^(VDD|VSS)(?!_DR)} $txt_str])} {
              set list_del [lsearch -all -exact -index {0 0} $texts $ori_str]
              set j 0
              foreach l $list_del {
                set l [expr $l - $j]
                set texts [lreplace $texts $l $l]
                incr j
              }
              continue
            }
          

          if {[point_inside_box $txt_x $txt_y [list $x1 $y1 $x2 $y2]]} {
            lappend all_find [list $lvl $txt_x $txt_y $txt_str] 
            set texts [lreplace $texts $i $i]
            continue
          } elseif {[regexp {mem_(hc|hd)_top} [lindex [lindex $texts $i] 1]] && [point_inside_box [expr $txt_x + 1000] $txt_y [list $x1 $y1 $x2 $y2]] && [regexp {VDD|VSS} $txt_str]} {
            lappend all_find [list $lvl $txt_x $txt_y $txt_str] 
            set texts [lreplace $texts $i $i]
            continue
          }
          incr i
        }

        if {[llength $all_find] == 0} {
          continue
        } else {
          set all_find [lsort -integer -index 1 $all_find]
          set txt_x [lindex [lindex $all_find 0] 1]
          set txt_y [lindex [lindex $all_find 0] 2]
          set txt_str [lindex [lindex $all_find 0] 3]
        }

        lappend finded $txt_str
        if {[regexp {VDD|VSS} $txt_str] && $lvl == 4} {
          if {$x1 < [lindex $zone_cut 0]} {
            set x1 [lindex $zone_cut 0]
          }
          if {$x2 > [lindex $zone_cut 2]} {
            set x2 [lindex $zone_cut 2]
          }
          if {$y1 < [lindex $zone_cut 1]} {
            set y1 [lindex $zone_cut 1]
          }
          if {$y2 > [lindex $zone_cut 3]} {
            set y2 [lindex $zone_cut 3]
          }
          if {$x1 > $x2 || $y1 > $y2} {
            continue
          }
          if {$txt_x < $x1 || $txt_x > $x2} {
            set txt_x $x1
          }
        }
        if {[point_inside_box $txt_x $txt_y $bbox_cut]} {
          lappend textkeep [list $lvl $txt_x $txt_y $txt_str [list $x1 $y1 $x2 $y2 $ori_layer]]
        } else {
          lappend textkeep [list $lvl $txt_x $txt_y $txt_str [list $x1 $y1 $x2 $y2 $lay]]
        }
      }
    }
    set finded [lsort -unique $finded]
    foreach f $finded {
      puts $f
      set find [lsearch -exact $ports $f]
      if {$find >= 0} {
        set ports [lreplace $ports $find $find]
      }
    }
  }
  for {set t 0} {$t < [llength $textkeep]} {incr t} {
    puts [lindex $textkeep $t]
    set txt [lindex $textkeep $t]
    set lvl [lindex $txt 0]
    set txt_x [lindex $txt 1]
    set txt_y [lindex $txt 2]
    set txt_str [lindex $txt 3]
    set poly [lindex $txt 4]

    if {$lvl != 4 && ![point_inside_box $txt_x $txt_y $bbox_cut]} {
      set a [$L extractNet $topc -geom [lindex $poly 4] [lindex $poly 0] [lindex $poly 1]]
      set new_layer [lindex $a 0]
      set new_polygons [$L iterator poly $topc $new_layer range 0 end]
      set new_polygons [search_port $txt $new_polygons $layer_connect]
      $L delete layer $new_layer
      set last_poly [lindex $new_polygons end]
      set last_via [lindex $new_polygons 0]
      set layer_via [dictregexp $layername {via[0-3]}]
      # puts $layer_via

      foreach p $new_polygons {
        set this_lay [lindex [split [lindex [lindex $p 0] 0]] 1]
        if {[lsearch $layer_via $this_lay] >= 0} {
          if {[lindex $p 1] < [lindex $last_via 1] } {
            set last_via $p
          }
        } else {
          if {[lindex $p 1] < [lindex $last_poly 1] } {
            set last_poly $p
          }
        }
      }
      set last_lay_poly [lindex [split [lindex [lindex $last_poly 0] 0]] 1]

      dict for {kc vc} $layer_connect {
        if {$vc == $last_lay_poly} {
          dict for {k v} $layername {
            if {$v == $kc} {
              regexp {met([0-9])} $k match last_lvl
              break
            }
          }
          break
        }
      }
      lappend new_poly [list $kc {*}[lreplace [lreplace [lreplace $last_poly 0 0] 2 2 [lindex $bbox_cut 2]] 4 4 [lindex $bbox_cut 2]]]
      
      set last_lay_via [lindex [split [lindex [lindex $last_via 0] 0]] 1]
      if {[lsearch $layer_via $last_lay_via] >= 0} {
        set last_via_x [lsort -integer [list [lindex $last_via 1] [lindex $last_via 5]]]
        set last_via_y [lsort -integer [list [lindex $last_via 2] [lindex $last_via 6]]]
        set last_via_bbox [list [lindex $last_via_x 0] [lindex $last_via_y 0] [lindex $last_via_x 1] [lindex $last_via_y 1]]
        if {[meta_cut_meta $last_via_bbox $bbox_cut]} {
          lappend new_poly [list $last_lay_via {*}[lreplace $last_via 0 0]]
        }   
      } 
      
      set textkeep [lreplace $textkeep $t $t [list $last_lvl [lindex $bbox_cut 2] [expr ([lindex $last_poly 2] + [lindex $last_poly 6])/2] $txt_str [list [lindex $last_poly 1] [lindex $last_poly 2] [lindex $bbox_cut 2] [lindex $last_poly 6]]]]
    }
  }
  set outfile [open "PIN_DRC.drc" w]
  set string "$name_gds_out 2000"
  set done []
  foreach txt $textkeep {
    puts $txt
    set lvl [lindex $txt 0]
    set txt_x [lindex $txt 1]
    set txt_y [lindex $txt 2]
    set txt_str [lindex $txt 3]
    if {[lsearch $done $txt_str] >= 0} {
      continue
    }
    # puts $txt_str
    set all [lsearch -all -inline -exact -index 3 $textkeep $txt_str] 
    set string "$string\n$txt_str\n[llength $all] [llength $all] 0 [clock format [clock seconds] -format "%b %d %H:%M:%S %Y"]"
    foreach a $all {    
      set poly [lindex $a 4]
      set x1 [lindex $poly 0]
      set y1 [lindex $poly 1]
      set x2 [lindex $poly 2]
      set y2 [lindex $poly 3]
      set string "$string\np 1 4\n$x1 $y1\n$x1 $y2\n$x2 $y2\n$x2 $y1"
    }
    lappend done $txt_str
  }
  # puts $string
  puts $outfile $string
  close $outfile

  
  foreach txt $textkeep {
    set lvl [lindex $txt 0]
    set txt_x [lindex $txt 1]
    set txt_y [lindex $txt 2]
    set txt_str [lindex $txt 3]
    set y1 [lindex [lindex $txt 4] 1]
    set y2 [lindex [lindex $txt 4] 3]
    if {![dict exist $layername [format "m%s_pintxt" $lvl]]} {
      $L create layer [dict get $layernameprops [format "m%s_pintxt" $lvl]]
      set lay [dict get $layernameprops [format "m%s_pintxt" $lvl]]
    } else {
      set lay [dict get $layername [format "m%s_pintxt" $lvl]]
    }
    

    if {[regexp {(VDD|VSS)} $txt_str str option] && [lsearch $vddport $txt_str] < 0 } {
      set txt_str $option
    }
    if {[regexp {(VDD|VSS|WLR)} $txt_str str option] } {
      set txt_str "$txt_str:"
      if { $lvl != 4} {
        set txt_y $y1
      }
    }
    lappend new_text [list $lay $txt_x $txt_y $txt_str]
  }
  puts "done text"

  dict for {k v} $layer_connect {
    $L delete layer $v
  }
  return $new_text
}

# proc keep_more_poly {} {
#   global L
#   global layername 
#   global topc 
#   global bbox_cut 
#   global re_cell_inside
#   global new_poly

#   set layer_keep [dict get $layername via0]

#   set polygons [$L iterator poly $topc $layer_keep range 0 end -depth 0 20]
#   foreach poly $polygons {
#     set path [lindex $poly 1]
    
#     set x [lsort -integer [list [lindex [lindex $poly 0] 0] [lindex [lindex $poly 0] 4]]]
#     set y [lsort -integer [list [lindex [lindex $poly 0] 1] [lindex [lindex $poly 0] 5]]]
#     set x1 [lindex $x 0]
#     set x2 [lindex $x 1]
#     set y1 [lindex $y 0]
#     set y2 [lindex $y 1]

#     if {![regexp $re_cell_inside $path] && [meta_cut_meta $bbox_cut [list $x1 $y1 $x2 $y2]]} {
#       lappend new_poly [list $layer_keep {*}[lindex $poly 0]]
#     } 
#   }
#   return $new_poly
#   # puts $new_poly
# }


