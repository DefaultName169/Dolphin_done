######################################### FUNCTION ###################################
proc variancebbox {name layername} {
  global L
  set layer_bbox [dict get $layername bbox]
  set bboxs [$L MASK_LAYER_INFO $name $layer_bbox]
  set all [$L bbox $name]
  set x1_bbox [lindex $bboxs 1]
  set y1_bbox [lindex $bboxs 2]
  set x2_bbox [expr [lindex $bboxs 1] + [lindex $bboxs 3]]
  set y2_bbox [expr [lindex $bboxs 2] + [lindex $bboxs 4]]

  if { [lindex $bboxs 0] == 0} {
    return [list $name 0 0 0 0 "not_bbox"]
  }
  return [list $name [expr $x1_bbox - [lindex $all 0]] [expr $y1_bbox - [lindex $all 1]] [expr [lindex $all 2] - $x2_bbox] [expr [lindex $all 3] - $y2_bbox]]
}

proc point_inside_box {x y box} {
  set x1_box [lindex $box 0]
  set y1_box [lindex $box 1]
  set x2_box [lindex $box 2]
  set y2_box [lindex $box 3]

  if { $x >= $x1_box && $x <= $x2_box && $y >= $y1_box && $y <= $y2_box } {
    return 1
  }
  return 0
}

proc get_bbox_of_ref {topc layername} {
  global L
  set refs [$L iterator ref $topc range 0 end -depth 0 0]
  set listvariance []
  foreach scell $refs {
    set name [lindex [lindex $scell 0] 0]
    set rad [lindex [lindex $scell 0] 4]
    set mirror [lindex [lindex $scell 0] 3]
    set count [expr $rad / 90]
    set int [lsearch -index 0 $listvariance $name]
    if {$int >= 0 } {
      set variance [lindex $listvariance $int]
    } else {
      set variance [variancebbox $name $layername]
      lappend listvariance $variance
    }

    set x1 [lindex [lindex $scell 2] 0]
    set y1 [lindex [lindex $scell 2] 1]
    set x2 [expr [lindex [lindex $scell 2] 0] + [lindex [lindex $scell 2] 2]]
    set y2 [expr [lindex [lindex $scell 2] 1] + [lindex [lindex $scell 2] 3]]

    # if {$name == "spmblldr_hd_cntrl"} {
    #   puts $scell
    #   puts "$x1 $y1 $x2 $y2"
    # }

    if { [lindex $variance 5] == "not_bbox" } {
      lappend all [list $name [lindex $scell 0] [lindex $scell 2] [list $x1 $y1 $x2 $y2 "not_bbox"]]
    } else {
      for {set i 0} {$i < 4 - $count } {incr i} {
        lappend variance [lindex $variance 1]
        set variance [lreplace $variance 1 1]
      }

      if { $mirror == 1 } {
        if {$count == 1 || $count == 3 } {
          set tmp [lindex $variance 1]
          set variance [lreplace $variance 1 1 [lindex $variance 3]]
          set variance [lreplace $variance 3 3 $tmp]
        } else {
          set tmp [lindex $variance 2]
          set variance [lreplace $variance 2 2 [lindex $variance 4]]
          set variance [lreplace $variance 4 4 $tmp]
        }
      }
      set x1 [expr $x1 + [lindex $variance 1] ]
      set y1 [expr $y1 + [lindex $variance 2] ]
      set x2 [expr $x2 - [lindex $variance 3] ]
      set y2 [expr $y2 - [lindex $variance 4] ]
      lappend all [list $name [lindex $scell 0] [lindex $scell 2] [list $x1 $y1 $x2 $y2]]
    }
  }
  return $all
}

proc via_inside_meta {v m} {
  set x1_via [lindex $v 1]
  set y1_via [lindex $v 2]
  set x2_via [lindex $v 5]
  set y2_via [lindex $v 6]
  set m_bbox [list [lindex $m 1] [lindex $m 2] [lindex $m 5] [lindex $m 6]]
  if { [point_inside_box $x1_via $y1_via $m_bbox] && [point_inside_box $x1_via $y2_via $m_bbox] && [point_inside_box $x2_via $y1_via $m_bbox] && [point_inside_box $x2_via $y2_via $m_bbox] } {
    return 1
  }
  return 0
}

proc get_lvl_lay {lay layer_connect} {
  global layername
  
  dict for {kc vc} $layer_connect {
    if {$vc ==  $lay} {
      dict for {k v} $layername {
        if {$v == $kc} {
          regexp {met([0-9])} $k match lvl
          return $lvl
        }
      }
    }
  }
}

proc search_port {text polys layer_connect} {
  global layername
  global zone_cut
  global bbox_cut

  set stop 0
  set txt_lvl [lindex $text 0]
  set txt_x [lindex $text 1]
  set txt_y [lindex $text 2]

  set txt_poly [format "%s %s %s %s" {*}[lreplace [lindex $text 4] end end]]
  # set txt_str [lindex $text 3]

  set way []
  set search_via 0
  set int_via -1
  set int_meta -1

  foreach poly $polys {
    set x [lsort -integer [list [lindex $poly 1] [lindex $poly 5]]]
    set y [lsort -integer [list [lindex $poly 2] [lindex $poly 6]]]

    set x1 [lindex $x 0]
    set y1 [lindex $y 0]
    set x2 [lindex $x 1]
    set y2 [lindex $y 1]
    set lay [lindex [split [lindex [lindex $poly 0] 0]] 1]

    if {[lsearch [dictregexp $layername {via}] $lay] >= 0} {
      set int_via [expr $int_via + 1]
      lappend list_via [list $int_via $poly]
    } else {
      set int_meta [expr $int_meta + 1]
      lappend list_meta [list $int_meta $poly]
      set match_end [expr [point_inside_box $x1 $y1 $bbox_cut] + [point_inside_box $x1 $y2 $bbox_cut] + [point_inside_box $x2 $y1 $bbox_cut] + [point_inside_box $x2 $y2 $bbox_cut]]
      if {$match_end >= 2 && $match_end < 4 } {
        lappend end $int_meta
      }

      if { [format "%s %s %s %s" $x1 $y1 $x2 $y2] == $txt_poly } {
        set start $int_meta
        puts $poly
      }
    }
  }
  puts "start : $start"
  puts "end : $end"
  puts "list_via : [llength $list_via]"
  puts "list_meta : [llength $list_meta]"

  set via []
  foreach v $list_via {
    set count 0
    set this_via []
    foreach m $list_meta {
      if { [ via_inside_meta [lindex $v 1] [lindex $m 1] ] } {
        set count [expr $count + 1]
        set v_index [lindex $v 0]
        if { [llength $this_via] > 0 } {
          lappend this_via [lindex $m 0]
        } else {
          lappend this_via $v_index [lindex $m 0]
        }
      }
    }
    if {$count >= 2 || [ lsearch -start 1 $this_via $start] > 0 } {
      lappend via $this_via
    }
  }

  # puts "via :  $via"
  set way []
  set save []
  set more []
  set list_via_match []
  set list_way_match []
  set save_via []

  
  if {[lsearch $end $start] >= 0} {
    set list_way_match [list $start]
    set end [lreplace $end [lsearch $end $start] [lsearch $end $start]]
    foreach vi $via {
      if { [lindex $vi [lsearch -start 1 $vi $start]] > 0} {
        set this_via [lindex [lindex $list_via [lindex $vi 0]] 1]
        set this_via_x [lsort -integer [list [lindex $this_via 1] [lindex $this_via 5]]]
        set this_via_y [lsort -integer [list [lindex $this_via 2] [lindex $this_via 6]]]
        set this_via_bbox [list [lindex $this_via_x 0] [lindex $this_via_y 0] [lindex $this_via_x 1] [lindex $this_via_y 1]]
        if {[meta_cut_meta $this_via_bbox $bbox_cut]} {
          lappend list_via_match [lindex $vi 0]
        }
      }
    }
  } else {
    set out 0
    while { 1 } {
      if { $out == 1 } {
        break
      }
      set empty 0
      for {set v 0} {$v < [llength $via]} {incr v} {
        set vi [lindex $via $v]

        if {[lindex $vi end] == "done"} {
          continue
        }

        if { [llength $way] == 0} {
          set last_way $start
          lappend way $start
        }

        set last_way [lindex $way end]

        if { [lsearch -start 1 $vi $last_way] > 0} {
          set empty 1

          set new_via $vi
          lappend new_via "done"
          set via [lreplace $via $v $v $new_via]

          for {set i 1} {$i < [llength $vi]} {incr i} {
            if { [lindex $vi $i] != $last_way } {
              if {[lsearch $way [lindex $vi $i]] >= 0} {
                set new_via $vi
                lappend new_via "done"
                set via [lreplace $via $v $v $new_via]
                set way [lreplace $way end end]
                set save_via [lreplace $save_via end end]
              } else {
                lappend way [lindex $vi $i]
                lappend save_via [lindex $vi 0]
              }
            }
            if { [lsearch $end [lindex $vi $i] ] >= 0} {
              #set count [expr $count + 1]
              set tmp [lindex $vi $i]
              set end [lreplace $end [lsearch $end [lindex $vi $i]] [lsearch $end [lindex $vi $i]]]
              lappend list_way_match {*}$way
              puts "way : $way"
              set last [lindex $way end]
              set way [lreplace $way end end]

            }
          }
          break
        }
      }

      if {$empty == 0} {
        if {[llength $way] == 1} {
          set out 1
        }
        set way [lreplace $way end end]
        set save_via [lreplace $save_via end end]
      }

      if { [llength $end] == 0 } {
        set out 1
      }
    }

    puts "save_via: $save_via"
    set list_way_match [lsort -unique $list_way_match]

    # set list_via_match []
    foreach v $via {
      set count 0
      for {set i 1} {$i < [llength $v]} {incr i} {
        if {[lsearch $list_way_match [lindex $v $i]] >= 0} {
          set count [expr $count + 1]
          # puts [lindex $list_via [lindex $v 0]]
          if {[point_inside_box [lindex [lindex [lindex $list_via [lindex $v 0]] 1] 1] [lindex [lindex [lindex $list_via [lindex $v 0]] 1] 2] $bbox_cut ] && \
              [point_inside_box [lindex [lindex [lindex $list_via [lindex $v 0]] 1] 5] [lindex [lindex [lindex $list_via [lindex $v 0]] 1] 6] $bbox_cut ] } {
            set count [expr $count + 1]
          }
        }
        if {$count >= 2} {
          lappend list_via_match [lindex $v 0]
        }
      }
    }
    set list_via_match [lsort -unique $list_via_match]
  }

  set list_return []

  puts "list_way_match :  $list_way_match"
  puts "list_via_match : $list_via_match"
  foreach v $list_via_match {
    lappend list_return [lindex [lindex $list_via $v] 1]
  }

  foreach w $list_way_match {
    lappend list_return [lindex [lindex $list_meta $w] 1]
  }
  return $list_return
}

proc connect_lvl {a b rekeep}  {
  global L
  global layername
  global topc
  global zone_cut
  global new_poly
  global re_cell_inside

  set lay_count 0
  set lay_met [list 1800 1801 1802 1803 1804 1805 1806 1807]
  set lay_not [list 1900 1901 1902 1903 1904 1905 1906 1907]
  set layer_cm [list 1700 1701 1702 1703 1704 1705 1706 1707]
  set lay_use []
  set last_lay [list 0 0]
  set this_lay [list 0 0]
  for {set i $a} {$i <= $b} {incr i} {
    puts "i : $i"
    set j 0
    set dict_lay [dict create [format "met%s" $i] [format "cm%s" $i] [format "met%sb" $i] [format "cm%s2" $i]]
    dict for {met cm} $dict_lay {
      if {[dict exists $layername $met]} {
        set met_lay [lindex $lay_met $lay_count]
        set not_lay [lindex $lay_met $lay_count]

        $L create layer $met_lay
        puts "$met : [dict get $layername $met] -> $met_lay"

        set m_poly [$L iterator poly $topc [dict get $layername $met] range 0 end -depth 0 20]
        if {[expr $i % 2] == 0} {
          set m_poly [lsort -command sort_poly_even $m_poly]
        } else {
          set m_poly [lsort -command sort_poly_odd $m_poly]
        }
        set lpoly []
        foreach p $m_poly {
          set path [lindex $p 1]
          
          set x [lsort -integer [list [lindex [lindex $p 0] 0] [lindex [lindex $p 0] 4]]]
          set y [lsort -integer [list [lindex [lindex $p 0] 1] [lindex [lindex $p 0] 5]]]
          set x1 [lindex $x 0]
          set x2 [lindex $x 1]
          set y1 [lindex $y 0]
          set y2 [lindex $y 1]
          
          set poly [list $x1 $y1 $x2 $y2 $met]
          # if {[regexp $re_cell_inside $path]} {
          #   continue
          # #   # puts [list [dict get $layername $met] {*}[lindex $p 0]]
          # #   lappend new_poly [list [dict get $layername $met] {*}[lindex $p 0]]
          # }

          if {![regexp $rekeep $path]} {
            # puts $path
            continue
          }
          # $L create polygon $topc $met_lay {*}[lindex $p 0]
          
          if {[llength $lpoly] == 0} {
            set lpoly $poly
            continue
          }

          if {[meta_cut_meta $lpoly $poly] && $met == [lindex $lpoly 4]} {
            set x [lsort -integer [list [lindex $lpoly 0] [lindex $lpoly 2] $x1 $x2]]
            set y [lsort -integer [list [lindex $lpoly 1] [lindex $lpoly 3] $y1 $y2]]
            set lpoly [list [lindex $x 0] [lindex $y 0] [lindex $x end] [lindex $y end] $met]
            if {$p != [expr [llength $m_poly] - 1]} {
              continue
            }
          } 
          set poly $lpoly
          set lpoly [list $x1 $y1 $x2 $y2 $met]
          set x1 [lindex $poly 0]
          set y1 [lindex $poly 1]
          set x2 [lindex $poly 2]
          set y2 [lindex $poly 3]
          $L create polygon $topc $met_lay $x1 $y1 $x1 $y2 $x2 $y2 $x2 $y1
        }


        if {[dict exists $layername $cm]} {
          set cm_lay [lindex $layer_cm $lay_count]
          set cm_poly [$L iterator poly $topc [dict get $layername $cm] range 0 end -depth 0 20]
          $L create layer $cm_lay
          foreach p $cm_poly {
            $L create polygon $topc $cm_lay {*}[lindex $p 0]
          }
          set not_lay [lindex $lay_not $lay_count]
          $L NOT $met_lay $cm_lay $not_lay
          $L delete polygons $topc $cm_lay
          $L delete polygons $topc $met_lay
        }

        # if {$i == $a} {
          dict set list_layer_connect [dict get $layername $met] $not_lay
        # }
       
        # if {[lindex $last_lay $j] > 0} {
        #   puts "connect $not_lay [lindex $last_lay $j] by [dict get $layername [format "via%s" [expr $i - 1]]]"
        #   $L connect $not_lay [lindex $last_lay $j] by [dict get $layername [format "via%s" [expr $i - 1]]]
        #   dict set list_layer_connect [dict get $layername $met] $not_lay
        # } elseif {$j > 0} {
        #   puts "connect $not_lay [lindex $last_lay 0] by [dict get $layername [format "via%s" [expr $i - 1]]]"
        #   $L connect $not_lay [lindex $last_lay 0] by [dict get $layername [format "via%s" [expr $i - 1]]]
        #   dict set list_layer_connect [dict get $layername $met] $not_lay
        # }

        set this_lay [lreplace $this_lay $j $j $not_lay]
        set lay_count [expr $lay_count + 1]
      } else {
        set this_lay [lreplace $this_lay $j $j 0]
      }
      # puts $last_lay
      set j [expr $j + 1]
    }

    foreach this $this_lay {
      if {$this == 0} {
        continue
      }
      foreach last $last_lay {
        if {$last == 0} {
          continue 
        }
        puts "connect $this $last by [dict get $layername [format "via%s" [expr $i - 1]]]"
        $L connect $this $last by [dict get $layername [format "via%s" [expr $i - 1]]]
          # dict set list_layer_connect [dict get $layername $met] $not_lay
      }
    }
    set last_lay $this_lay
    
  }
  puts "connect done"
  return $list_layer_connect
}


proc sort_poly_even {a b} {
  set x11 [lindex [lsort -integer [list [lindex [lindex $a 0] 0] [lindex [lindex $a 0] 4]]] 0]
  set x12 [lindex [lsort -integer [list [lindex [lindex $b 0] 0] [lindex [lindex $b 0] 4]]] 0]
  set y11 [lindex [lsort -integer [list [lindex [lindex $a 0] 1] [lindex [lindex $a 0] 5]]] 0]
  set y12 [lindex [lsort -integer [list [lindex [lindex $b 0] 1] [lindex [lindex $b 0] 5]]] 0]
  if {$y11 < $y12} {
    return 0
  } elseif {$y11 > $y12} {
    return 1
  } elseif {$x11 > $x12} {
    return 0
  } else {
    return 1
  }
}

proc sort_text_even {a b} {
  set x_a [lindex [lindex $a 0] 1]
  set x_b [lindex [lindex $b 0] 1]
  set y_a [lindex [lindex $a 0] 2]
  set y_b [lindex [lindex $b 0] 2]
  if {$y_a < $y_b} {
    return 0
  } elseif {$y_a > $y_b} {
    return 1
  } elseif {$x_a > $x_b} {
    return 0
  } else {
    return 1
  }
}

proc sort_poly_odd {a b} {
  set x11 [lindex [lsort -integer [list [lindex [lindex $a 0] 0] [lindex [lindex $a 0] 4]]] 0]
  set x12 [lindex [lsort -integer [list [lindex [lindex $b 0] 0] [lindex [lindex $b 0] 4]]] 0]
  set y11 [lindex [lsort -integer [list [lindex [lindex $a 0] 1] [lindex [lindex $a 0] 5]]] 0]
  set y12 [lindex [lsort -integer [list [lindex [lindex $b 0] 1] [lindex [lindex $b 0] 5]]] 0]

  if {$x11 > $x12} {
    return 0
  } elseif {$x11 < $x12} {
    return 1
  } elseif {$y11 < $y12} {
    return 0
  } else {
    return 1
  }
}

proc sort_text_odd {a b} {
  set x_a [lindex [lindex $a 0] 1]
  set x_b [lindex [lindex $b 0] 1]
  set y_a [lindex [lindex $a 0] 2]
  set y_b [lindex [lindex $b 0] 2]
  if {$x_a > $x_b} {
    return 0
  } elseif {$x_a < $x_b} {
    return 1
  } elseif {$y_a < $y_b} {
    return 0
  } else {
    return 1
  }
}

proc meta_cut_meta {meta1 meta2} {
  set x1_meta1 [lindex $meta1 0]
  set y1_meta1 [lindex $meta1 1]
  set x2_meta1 [lindex $meta1 2]
  set y2_meta1 [lindex $meta1 3]
  set x1_meta2 [lindex $meta2 0]
  set y1_meta2 [lindex $meta2 1]
  set x2_meta2 [lindex $meta2 2]
  set y2_meta2 [lindex $meta2 3]
  if {[point_inside_box $x1_meta1 $y1_meta1 $meta2] || [point_inside_box $x1_meta1 $y2_meta1 $meta2] || [point_inside_box $x2_meta1 $y1_meta1 $meta2] || [point_inside_box $x2_meta1 $y2_meta1 $meta2]} {
    return 1
  } elseif {[point_inside_box $x1_meta2 $y1_meta2 $meta1] || [point_inside_box $x1_meta2 $y2_meta2 $meta1] || [point_inside_box $x2_meta2 $y1_meta2 $meta1] || [point_inside_box $x2_meta2 $y2_meta2 $meta1]} {
    return 1
  } elseif {$x1_meta1 > $x1_meta2 && $x2_meta1 < $x2_meta2 && $y1_meta1 < $y1_meta2 && $y2_meta1 > $y2_meta2} {
    return 1
  } elseif {$x1_meta1 < $x1_meta2 && $x2_meta1 > $x2_meta2 && $y1_meta1 > $y1_meta2 && $y2_meta1 < $y2_meta2} {
    return 1
  } 
  return 0
}

proc dictregexp {dictval regex} {
  foreach d [dict keys $dictval] {
    if {[regexp $regex $d] } {
      lappend re [dict get $dictval $d]
    }
  }
  set re [lsort -unique $re]
  return $re
}

proc intersect {list1 list2} {
  set re []
  foreach a $list1 {
    if {$a in $list2} {
      lappend re $a
    }
  }
  return $re
}

proc abs {int} {
  if {$int < 0} {
    return [expr 0 - $int]
  }
  return $int
}

proc pow {x y} {
  set i 0
  set result 1
  while {$i < $y} {
    set result [expr $x * $result]
    set i [expr $i + 1]
  }
  return $result
}

proc vector {x1 y1 x2 y2} {
  return [ expr [pow [expr $x1 - $x2] 2] + [pow [expr $y1 - $y2] 2] ]
}
