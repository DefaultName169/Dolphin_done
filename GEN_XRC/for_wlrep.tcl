#!/usr/bin/tclsh

set re_ckt ".subckt ${name_ckt}(.*?)\nx"
set re_bbox "wlrep$" 


proc bbox_cut {} {
  global bbox_x
  global bbox_y
  global allbbox
  global L
  global topcc


  set wlrep [lindex $allbbox [lsearch -index 0 -regexp  $allbbox {wlrep$}]]
  puts $wlrep
  if {[lindex [lindex $wlrep 1] 6] > 0} {
    set rad [lindex [lindex $wlrep 1] 4]
    set mirror [lindex [lindex $wlrep 1] 3]
    if {$rad == 0 || $rad == 180} {
      set x1 [lindex [lindex $wlrep 3] 0]
      set y1 [lindex [lindex $wlrep 3] 1]
      set x2 [expr [lindex [lindex $wlrep 3] 2] - [lindex [lindex $wlrep 1] 8] * ([lindex [lindex $wlrep 1] 6] - 1)]
      set y2 [expr [lindex [lindex $wlrep 3] 3] - [lindex [lindex $wlrep 1] 9] * ([lindex [lindex $wlrep 1] 7] - 1)]
    } else {
      set x1 [lindex [lindex $wlrep 3] 0]
      set y1 [lindex [lindex $wlrep 3] 1]
      set x2 [expr [lindex [lindex $wlrep 3] 2] - [lindex [lindex $wlrep 1] 9] * ([lindex [lindex $wlrep 1] 7] - 1)]
      set y2 [expr [lindex [lindex $wlrep 3] 3] - [lindex [lindex $wlrep 1] 8] * ([lindex [lindex $wlrep 1] 6] - 1)]
    }

    if {($rad == 0 && $mirror == 0) || ($rad == 180 && $mirror == 1)} {
      set x [lindex [lindex $wlrep 1] 1]
      set y [lindex [lindex $wlrep 1] 2]
    } elseif {($rad == 90 && $mirror == 0) || ($rad == 270 && $mirror == 1)} {
      set x [expr [lindex [lindex $wlrep 1] 1] - [lindex [lindex $wlrep 1] 9] * ([lindex [lindex $wlrep 1] 7] - 1)]
      set y [lindex [lindex $wlrep 1] 2]
    } elseif {($rad == 180 && $mirror == 0) || ($rad == 0 && $mirror == 1)} {
      set x [expr [lindex [lindex $wlrep 1] 1] - [lindex [lindex $wlrep 1] 8] * ([lindex [lindex $wlrep 1] 6] - 1)]
      set y [expr [lindex [lindex $wlrep 1] 2] - [lindex [lindex $wlrep 1] 9] * ([lindex [lindex $wlrep 1] 7] - 1)]
    } elseif {($rad == 270 && $mirror == 0) || ($rad == 90 && $mirror == 1)} {
      set x [lindex [lindex $wlrep 1] 1] 
      set y [expr [lindex [lindex $wlrep 1] 2] - [lindex [lindex $wlrep 1] 8] * ([lindex [lindex $wlrep 1] 6] - 1)]
    }

    puts "[lindex $wlrep 0] $x $y [lindex [lindex $wlrep 1] 3] [lindex [lindex $wlrep 1] 4] [lindex [lindex $wlrep 1] 5]"
    $L create ref $topc [lindex $wlrep 0] $x $y [lindex [lindex $wlrep 1] 3] [lindex [lindex $wlrep 1] 4] [lindex [lindex $wlrep 1] 5]
    puts "$x1 $y1\n$x2 $y1\n$x2 $y2\n$x1 $y2"
  } else {
    set x1 [lindex [lindex $wlrep 3] 0]
    set y1 [lindex [lindex $wlrep 3] 1]
    set x2 [lindex [lindex $wlrep 3] 2]
    set y2 [lindex [lindex $wlrep 3] 3]
  }
  # puts $wlrep
  return [list $x1 $y1 $x2 $y2]
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
            if {$x1 > $x2 || $y1 > $y2} {
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
        if {[lsearch $all_port $txt_str] >= 0 && [regexp $re_cell_inside $path] && [point_inside_box $txt_x $txt_y $bbox_cut]} {
          lappend textkeep [list $layer_text $txt_x $txt_y $txt_str ]
        }
      }
    }
  }
  foreach text $textkeep {
    puts $text
  }
  return $textkeep
}

proc keep_more_poly {} {
  global L
  global layername
  global layers
  global topc
  set list_change [list [list 108.206 206.28]]
  set new_poly []
  foreach duo $list_change {
    if {[expr [lsearch $layers [lindex $duo 0]] + [lsearch $layers [lindex $duo 1]] ] < 2} {
      # $L create layer [lindex $duo 0]
      $L create layer [lindex $duo 1] 
      $L create layer 1000
      $L create layer 1001
      set pcomp [$L iterator poly $topc 6 range 0 end -depth 0 20]
      set poly [$L iterator poly $topc 17 range 0 end -depth 0 20]
      set is_vertical -1
      foreach p $pcomp {
        $L create polygon $topc 1000 {*}[lindex $p 0]
      }
      foreach p $poly {
        $L create polygon $topc 1001 {*}[lindex $p 0]
      }
      $L AND 1000 1001 206.28
      $L delete layer 1000
      $L delete layer 1001
      set pgate [$L iterator poly $topc 206.28 range 0 end] 
      set text [$L iterator text $topc [dict get $layername "text_layer"] range 0 end -depth 0 20]
      puts [dict get $layername "text_layer"]
      foreach p $pgate {
        set x [lsort -integer [list [lindex $p 0] [lindex $p 4]]]
        set y [lsort -integer [list [lindex $p 1] [lindex $p 5]]]

        set box [list [lindex $x 0] [lindex $y 0] [lindex $x 1] [lindex $y 1]]
        set finded 0

        foreach t $text {
          set txt_x [lindex [lindex $t 0] 1]
          set txt_y [lindex [lindex $t 0] 2]
          set txt_str [lindex [lindex $t 0] 0]
          if {[point_inside_box $txt_x $txt_y $box] && [regexp {PODE} $txt_str]} {
            lappend new_poly [list 206.28 {*}$p]
            set finded 1
            break
          } 
        }
        if {$finded == 1} {
          continue
        }
        $L delete polygon $topc 206.28 {*}$p
      }
      continue
    }
    set polys [$L iterator poly $topc [lindex $duo 0] range 0 end -depth 0 20]
    set name_changed []

    foreach poly $polys {
      set path [lindex $poly 1]
      set name [lindex [split $path "/"] end]
      if { $name in $name_changed } {
        continue
      }

      lappend name_changed $name
      set polymatch [$L iterator poly $name [lindex $duo 0] range 0 end]
      foreach p $polymatch {
        $L create polygon $name [lindex $duo 1] {*}$p
      }
      $L delete polygons $name [lindex $duo 0]
    }
  }
  return $new_poly
}
