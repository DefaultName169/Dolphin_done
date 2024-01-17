#!/usr/bin/tclsh

set re_ckt ".subckt ${name_ckt}(.*?)\nx"

set re_bbox "^sp_(hd|hc)_((?!bpo).)*_rep$" 
set get_zone_cut 0



proc bbox_cut {} {
  global bbox_x
  global bbox_y
  return [list [lindex $bbox_x 0]   [lindex $bbox_y [expr [llength $bbox_y] / 2    ] ] \
               [lindex $bbox_x end] [lindex $bbox_y [expr [llength $bbox_y] / 2 + 1] ] ] 
}

proc zone_cut {} {
  global zone_x
  global zone_y
  return [list [lindex $zone_x 0] [lindex $zone_y 0] [lindex $zone_x end [lindex $zone_y end]]]
}

proc keeptext {} {
  global L
  global bbox_cut
  global all_port
  global new_text
  global re_cell_inside
  global layername
  global topc
  global vddport
  global re_vddport

  for {set lvl 4} {$lvl >= 0} {set lvl [expr $lvl - 1]} {
    set layer_text [dict get $layername [format "m%s_pintxt" $lvl]]
    set texts [$L iterator text $topc $layer_text range 0 end -depth 0 1]
    if {$lvl == 4} {
      set layer_poly [dictregexp $layername [format "met%s($|2$|b$)" $lvl]]
      foreach lay $layer_poly {
        set m4poly [lsort -command sort_poly_even [$L iterator poly $topc $lay range 0 end -depth 0 0]]
        set texts [lsort -command sort_text_even $texts]
        # puts $texts
        foreach poly $m4poly {
          set x1 [lindex [lindex $poly 0] 0]
          set y1 [lindex [lindex $poly 0] 1]
          set x2 [lindex [lindex $poly 0] 4]
          set y2 [lindex [lindex $poly 0] 5]

          if {[meta_cut_meta $bbox_cut [list $x1 $y1 $x2 $y2]]} {
            set i 0
            set all_find []
            set start 0
            while {$i < [llength $texts]} {
              set depth [expr [llength [split [lindex [lindex $texts $i] 1] "/"]] - 2]
              set t [lindex [lindex $texts $i] 0]          
              set txt_x [lindex $t 1]
              set txt_y [lindex $t 2]     
              set txt_str [lindex $t 0]

              regsub {:} $txt_str {} txt_str
              
              if {!$start} {
                if {$txt_y > [lindex $bbox_cut 1]} {
                  set texts [lreplace $texts 0 [expr $i - 1]]
                  set start 1
                  set i 0
                } else {
                  incr i
                  continue
                } 
              } elseif {$txt_y > $y2} {
                break
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
              set all_find [lsearch -inline -all -regexp -index 3 $all_find $re_vddport]
              set all_find [lsort -integer -index 1 $all_find]
              set txt_x [lindex [lindex $all_find 0] 1]
              set txt_y [lindex [lindex $all_find 0] 2]
              set txt_str [format "%s:" [lindex [lindex $all_find 0] 3]]
            }

            lappend finded $txt_str
            if {$x1 < [lindex $bbox_cut 0]} {
              set x1 [lindex $bbox_cut 0]
            }
            if {$x2 > [lindex $bbox_cut 2]} {
              set x2 [lindex $bbox_cut 2]
            }
            if {$y1 < [lindex $bbox_cut 1]} {
              set y1 [lindex $bbox_cut 1]
            }
            if {$y2 > [lindex $bbox_cut 3]} {
              set y2 [lindex $bbox_cut 3]
            }
            if {$x1 >= $x2 || $y1 >= $y2} {
              continue
            }
            if {$txt_x < $x1 || $txt_x > $x2} {
              set txt_x $x1
            }
            lappend textkeep [list $layer_text $txt_x $txt_y $txt_str]
          }
        }
      }
      
    } else {
      foreach txt $texts {
        set path [lindex $txt 1]
        set txt_x [lindex [lindex $txt 0] 1]
        set txt_y [lindex [lindex $txt 0] 2]
        set txt_str [string toupper [lindex [lindex $txt 0] 0]]
        
        if {[lsearch $all_port $txt_str] >= 0 && [regexp $re_cell_inside $path] && [point_inside_box $txt_x $txt_y $bbox_cut] && [lsearch -exact -index 3 $textkeep $txt_str] < 0} {
          lappend textkeep [list $layer_text $txt_x $txt_y $txt_str ]
        }
      }
    }
  }
  foreach txt $textkeep {
    puts $txt
  }

  return $textkeep
}
 
 
 
 
 
 
 
 
 
 
 
 
 
