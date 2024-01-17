#!/usr/bin/tclsh

set re_ckt ".subckt ${name_ckt}(.*?)\nx"
set re_bbox "_trk_" 

proc zone_cut {} {
  global name_gds_in
  global allbbox
  global zone_x
  global zone_y
  global bbox_x
  global bbox_y
  # global L
  # global topc 
  # global layername
  set trk_edge [lsearch -inline -regexp -index 0 $allbbox {_trk_edge_t}]
  # set int_y_zone [lsearch -regexp -index 0 $allbbox {_mem_(hc|hd)_trk_edge_t$}]
  # if {[regexp {memarrayllpg} $name_gds_in]} {
  return [list [lindex $zone_x 0] [lindex $bbox_y 0] [lindex $bbox_x end] [expr [lindex $bbox_y end] + 2* ([lindex [lindex $trk_edge 3] 3] - [lindex [lindex $trk_edge 3] 1])]]
  # }
  # return [list [lindex $zone_x 0] [lindex $bbox_y 0] [lindex $bbox_x end] [expr [lindex $bbox_y end] + [lindex [lindex $trk_edge 3] 3] - [lindex [lindex $trk_edge 3] 1]]]
}

proc bbox_cut {} {
  global bbox_x 
  global bbox_y
  global name_gds_in
  global allbbox

  set xdec_r [lsearch -inline -regexp -index 0 $allbbox {xdec_r}]
  set line_hor [expr ([lindex [lindex $xdec_r 3] 1] + [lindex [lindex $xdec_r 3] 3])/2]
  for {set i 0} {$i < [llength $bbox_y]} {incr i} {
    if {[lindex $bbox_y $i] > $line_hor} {
      set bbox_y [lreplace $bbox_y 0 [expr $i - 1]]
      break
    }
  }

  if {[regexp {sp{1,3}mb} $name_gds_in]} {
    set cntrl_prog [lsearch -inline -all -regexp -index 0 $allbbox {cntrl_prog}]
    set cntrl_prog [lsort -index {3 2} -integer $cntrl_prog]
    set line_ver [lindex [lindex [lindex $cntrl_prog 0] 3] 2]
    for {set i 0} {$i < [llength $bbox_x]} {incr i} {
      if {[lindex $bbox_x $i] > $line_ver} {
        set bbox_x [lreplace $bbox_x $i end]
        break
      }
    }
    
  }

  return [list [lindex $bbox_x 0] [lindex $bbox_y 0] [lindex $bbox_x end] [lindex $bbox_y end]]
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

  set ports $all_port
  lappend port "VSS"

  set layer_connect [connect_lvl 0 3 {(x|y)pred|cntrl|boost|_trk_}]
  # $L gdsout "test.gds"
  puts $layer_connect
  set textkeep []

  for {set lvl 4} {$lvl >= 0} {set lvl [expr $lvl - 1]} {
    set layer_text [dict get $layername [format "m%s_pintxt" $lvl]]
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

          if {[regexp {OUTR} $txt_str]} {
            if {$txt_x < [lindex $bbox_cut 0] || $txt_x > [lindex $bbox_cut 2]} {
              set texts [lreplace $texts $i $i]
              continue
            }
            set txt_y [lindex $bbox_cut 1]
          }
          
          if {[regexp {(VDD|VSS)MEM} $txt_str match type]} {
            set txt_str [format "%s_MEM_R" $type]
          }
          
          if {[lsearch -exact $ports $txt_str] < 0 && !([regexp {^(VDD|VSS|OUTR)(?!_DR)} $txt_str])} {
            set list_del [lsearch -all -exact -index {0 0} $texts $ori_str]
            set j 0
            foreach l $list_del {
              set l [expr $l - $j]
              set texts [lreplace $texts $l $l]
              incr j
            }
            continue
          }

          # puts $txt_str

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
          if {$x1 >= $x2 || $y1 >= $y2} {
            continue
          }
          if {$txt_x < $x1 || $txt_x > $x2} {
            set txt_x $x1
          }
        }

        if {$lvl != 4 && ![regexp {OUTR} $txt_str] && [lsearch -index 3 $textkeep $txt_str] >= 0} {
          set int [lsearch -index 3 $textkeep $txt_str]
          set textkeep [lreplace $textkeep $int $int [list $lvl $txt_x $txt_y $txt_str [list $x1 $y1 $x2 $y2 $lay]]]
        } else {
          lappend textkeep [list $lvl $txt_x $txt_y $txt_str [list $x1 $y1 $x2 $y2 $lay]]
        }
      }
    }
  }

  # set trk [lsearch -inline -all -index 3 -regexp $textkeep {TRK}]
  # puts $trk

  set skip []
  for {set t 0} {$t < [llength $textkeep]} {incr t} {
    if {[lsearch $skip $t] >= 0} {
      continue
    }
    set txt [lindex $textkeep $t]
    set lvl [lindex $txt 0]
    set txt_x [lindex $txt 1]
    set txt_y [lindex $txt 2]
    set txt_str [lindex $txt 3]
    set poly [lindex $txt 4]

    if {[regexp {OUTR[0-9](_[A-Z])?} $txt_str match alpha]} {  
      set all [lsearch -all -index 3 -regexp $textkeep "OUTR\[0-9\]$alpha"]
      lappend skip {*}$all
      for {set a 1} {$a < [expr [llength $all] - 1]} {incr a} {
        set textkeep [lreplace $textkeep [lindex $all $a] [lindex $all $a] [lreplace [lindex $textkeep [lindex $all $a]] 3 3 "VSS"]]
      }
      set textkeep [lreplace $textkeep [lindex $all 0] [lindex $all 0] [lreplace [lindex $textkeep [lindex $all 0]] 3 3 [format "WLR%s_NEAR" $alpha]]]
      set textkeep [lreplace $textkeep [lindex $all end] [lindex $all end] [lreplace [lindex $textkeep [lindex $all end]] 3 3 [format "WLR%s_FAR" $alpha]]]
    } elseif {$lvl != 4} {
      set a [$L extractNet $topc -geom [lindex $poly 4] [lindex $poly 0] [lindex $poly 1]]
      set new_layer [lindex $a 0]
      set new_polygons [$L iterator poly $topc $new_layer range 0 end]
      set new_polygons [search_port $txt $new_polygons $layer_connect]

      puts $new_polygons
      $L delete layer $new_layer
      foreach p $new_polygons {
        set ori_layer [lindex [split [lindex [lindex $p 0] 0]] 1]
        if {[lsearch [dictregexp $layername {via}] $ori_layer] < 0} {
          dict for {k v} $layer_connect {
            if {$ori_layer == $v} {
              set ori_layer $k 
            }
          }
        }
        set p [lreplace $p 0 0]
        lappend new_poly [list $ori_layer {*}$p "$ori_layer $x1 $y1 $x2 $y2"]
      }
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
    set lay [dict get $layername [format "m%s_pintxt" $lvl]]

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



proc keep_more_poly {} {
  global L
  global layername 
  global topc 
  global bbox_cut 
  global zone_cut 
  global new_text 
  global list_layer_connect 
  global re_cell_inside
  global new_poly

  layout copy $L layout1 $topc 0 20 [lindex $bbox_cut 0] [lindex $bbox_cut 3] [lindex $bbox_cut 2] [lindex $zone_cut 3] 1
  set L1 layout1
  set layers [$L1 layers] 
  set layer_keep [dictregexp $layername {(met|cm|via)[0-3]($|b$|2$)|viad}]
  foreach lay $layers {
    if {[lsearch $layer_keep $lay] < 0} {
      $L1 delete layer $lay
    }
  }

  set layers [$L1 layers] 
  foreach lay $layers {
    set polys [$L1 iterator poly $topc $lay range 0 end] 
    foreach p $polys {
      lappend new_poly [list $lay {*}$p]
    }
  }

  # layout1 gdsout "test.gds"

  # # exit

  # for {set lvl 0} {$lvl < 4} {incr lvl} {
  #   if {$lvl == 0} {
  #     set layer_keep [dictregexp $layername [format "(met|cm|via)%s($|b$|2$)|viad$" $lvl]]
  #   } else {
  #     set layer_keep [dictregexp $layername [format "(met|cm|via)%s($|b$|2$)" $lvl]]
  #   }
    
  #   foreach lay $layer_keep {
  #     puts $lay
  #     set polygons [$L iterator poly $topc $lay range 0 end -depth 0 20]
  #     foreach poly $polygons {
  #       set path [lindex $poly 1]
        
  #       set x [lsort -integer [list [lindex [lindex $poly 0] 0] [lindex [lindex $poly 0] 4]]]
  #       set y [lsort -integer [list [lindex [lindex $poly 0] 1] [lindex [lindex $poly 0] 5]]]
  #       set x1 [lindex $x 0]
  #       set x2 [lindex $x 1]
  #       set y1 [lindex $y 0]
  #       set y2 [lindex $y 1]

  #       if {[lsearch -index end $new_poly "$lay $x1 $y1 $x2 $y2"] >= 0 || [regexp $re_cell_inside $path] || $y1 < [lindex $bbox_cut 1] || $x1 >= [lindex $bbox_cut 2]} {
  #         continue
  #       } 
        
  #       if {[meta_cut_meta [list $x1 $y1 $x2 $y2] $zone_cut]} {
  #         lappend new_poly [list $lay {*}[lindex $poly 0] "$lay $x1 $y1 $x2 $y2"]
  #       }
  #     }
  #   }
  # }

  return $new_poly
} 
  # set list_layer_connect []
  # set lvl_max -1
  # foreach text $new_text {
  #   set lay [lindex $text 0]
  #   #puts $lay
  #   if {[lindex $text 4] == "outside" } {
  #     puts $text 
  #     lappend get_more $text
  #     dict for {k v} [dict filter $layername value $lay] {
  #       regexp {m([0-9])_pintxt} $k m lvl
  #     }
  #     if {[lsearch $list_layer_connect [dict get $layername [format "met%s" $lvl]]] < 0} {
  #       lappend list_layer_connect [dict get $layername [format "met%s" $lvl]]
  #       lappend list_layer_connect [dict get $layername [format "met%sb" $lvl]]
  #     }
  #     if {$lvl > $lvl_max} {
  #       set lvl_max $lvl
  #     }
  #   }
  # }
  # if {$lvl_max < 2} {
  #   set lvl_max 2
  # }

  # set lay_connect [connect_lvl 0 $lvl_max]

  # puts $lay_connect  

  # foreach lay [dict keys $lay_connect] {
  #   dict for {k v} [dict filter $layername value $lay] {
  #     regexp {met([0-9])} $k m lvl
  #   }
  #   foreach txt $get_more {
  #     set txt_lay [lindex $txt 0]
  #     set txt_x [lindex $txt 1]
  #     set txt_y [lindex $txt 2]
  #     dict for {k v} [dict filter $layername value $txt_lay] {
  #       regexp {m([0-9])_pintxt} $k m txt_lvl
  #     }
  #     if {$txt_lvl == $lvl} {
  #       set poly [$L iterator poly $topc [dict get $lay_connect $lay] range 0 end] 
  #       foreach p $poly {
  #         set x [lsort -integer [list [lindex $p 0] [lindex $p 4]]]
  #         set y [lsort -integer [list [lindex $p 1] [lindex $p 5]]]
  #         set x1 [lindex $x 0]
  #         set x2 [lindex $x 1]
  #         set y1 [lindex $y 0]
  #         set y2 [lindex $y 1]

  #         if {[point_inside_box $txt_x $txt_y [list $x1 $y1 $x2 $y2]]} {
  #           set a [$L extractNet $topc -geom [dict get $lay_connect $lay] [lindex $p 0] [lindex $p 1]]
  #           set new_layer [lindex $a 0]
  #           set new_polygons [$L iterator poly $topc $new_layer range 0 end]
  #           set new_polygons [search_port $txt $new_polygons]
  #           $L delete layer $new_layer
  #           foreach p $new_polygons {
  #             set ori_layer [lindex [split [lindex [lindex $p 0] 0]] 1]
 
  #             if {[lsearch [dictregexp $layername {via}] $ori_layer] < 0} {
  #               dict for {k v} $lay_connect {
  #                 if {$ori_layer == $v} {
  #                   set ori_layer $k 
  #                 }
  #               }
  #             }
  #             lappend new_poly [list $ori_layer [lindex $p 1] [lindex $p 2] [lindex $p 3] [lindex $p 4] \
  #                                               [lindex $p 5] [lindex $p 6] [lindex $p 7] [lindex $p 8]]
  #           }
  #         }
  #       }
  #     }
  #   }
  # }


  # dict for {k v}  $lay_connect {
  #   puts "delete layer $v"
  #   $L delete layer $v
  #   # $L delete polygons $topc $v
  # }
 
  # puts "list_layer_connect : $list_layer_connect"
  
  # set layers [$L layers]
  # dict for {key val} $layername {
  #   if { [regexp {^(met[0-9]+|via[0-9]+|cm|cpo)} $key] && [lsearch $layers $val] >= 0 } {
  #     lappend lay_get_more $val
  #   }
  # }

  # set lay_get_more [lsort -unique $lay_get_more]
  # puts "lay_get_more : $lay_get_more"
  # puts "zone_cut : $zone_cut"
  # # puts "skip : $re_cell_inside"

  # set lay_count 0

  # foreach lay $lay_get_more  {
  #   set polys [$L iterator poly $topc $lay range 0 end -depth 1 20]
  #   foreach poly $polys {
  #     set path [lindex $poly 1]
  #     set x [lsort -integer [list  [lindex [lindex $poly 0] 0] [lindex [lindex $poly 0] 4] ] ]
  #     set y [lsort -integer [list  [lindex [lindex $poly 0] 1] [lindex [lindex $poly 0] 5] ] ]
      
  #     set x1 [lindex $x 0]
  #     set x2 [lindex $x 1]
  #     set y1 [lindex $y 0]
  #     set y2 [lindex $y 1]

  #     if { ![regexp $re_cell_inside $path]  && [point_inside_box [expr ($x1 + $x2)/2 ] [expr ($y1 + $y2)/2 ] $zone_cut] } {
  #       #if { $y2 > [lindex $zone_cut 3] && ![regexp {via} $path]} {
  #       #  set y2 [lindex $zone_cut 3]
  #       #}
  #       #puts [list $lay $x1 $y1 $x1 $y2 $x2 $y2 $x2 $y1]
  #       lappend new_poly [list $lay $x1 $y1 $x1 $y2 $x2 $y2 $x2 $y1 ]
  #     }
  #   }
  # }
  


# proc keeptext {txt lay} {
#   global bbox_cut
#   global all_port 
#   global new_text
#   global re_cell_inside


#   set txt_x [lindex [lindex $txt 0] 1]
#   set txt_y [lindex [lindex $txt 0] 2]
#   set txt_str [string toupper [lindex [lindex $txt 0] 0]]
#   set path [lindex $txt 1]
#   set split_name [split $path "/"]
#   set depth [expr [llength $split_name] - 1]
#   set name_lay [lindex $split_name $depth]
 
#   if { [lsearch -exact $all_port $txt_str] >= 0 } {
#     set match [lsearch -index 3 $new_text $txt_str]
#     if {$match  >= 0 } {
#       if {[point_inside_box $txt_x $txt_y $bbox_cut] } {
#         if {[check_pin_in_met $lay $txt_x $txt_y]} {
#           set new_text [lreplace $new_text $match $match [list $lay $txt_x $txt_y $txt_str "inside"]]
#         } 
#       } elseif { $txt_x < [lindex [lindex $new_text $match] 1] && [lindex [lindex $new_text $match] 4] != "inside" } {
#         set new_text [lreplace $new_text $match $match [list $lay $txt_x $txt_y $txt_str "outside" $path]]
#       }
#     } else {
#       if { [point_inside_box $txt_x $txt_y $bbox_cut] } { 
#         if {[check_pin_in_met $lay $txt_x $txt_y]} {
#           lappend new_text [list $lay $txt_x $txt_y $txt_str "inside"]
#         }
#       } else {
#         lappend new_text [list $lay $txt_x $txt_y $txt_str "outside" $path]
#       }
#     }
#   } elseif { [regexp "OUTR" $txt_str] } {
#     if { [lindex $bbox_cut 1] > $txt_y } {
#       set txt_y [lindex $bbox_cut 1]
#     }
#     set exist 0 
#     foreach text $new_text {
#       if { [lindex $text 0] == $lay && [lindex $text 1] == $txt_x } {
#         set exist 1
#         break
#       }
#     }
#     if {$exist == 0} {
#       lappend new_text [list $lay $txt_x $txt_y "VSS:" $txt_str]
#     }
#   }

#   return $new_text
# }



#############################################################   

      #if {[lsearch $list_layer_connect $lay] >= 0 } {
      #  
      #  foreach more $get_more {
      #    set new_polygons [] 
      #    set lay_txt [lindex $text 0]
      #    dict for {k v} [dict filter $layername value $lay_txt] {
      #      regexp {m([0-9])_pintxt} $k m lvl
      #    }

      #    if {[regexp [lindex $more 5] $path]} {
      #      set x_text [lindex $more 1]
      #      set y_text [lindex $more 2]
      #      
      #      if {[point_inside_box $x_text $y_text [list $x1 $y1 $x2 $y2]]} {      

      #        puts "lay_connect : $lay_connect"
      #        puts "MORE ::::::::::::::::::::::: $more"

      #        set poly_new [$L iterator poly $topc [dict get $lay_connect $lay] range 0 end]
      #        foreach pnew $poly_new {
      #          set x [lsort -integer [list [lindex $pnew 0] [lindex $poly 4] ] ]
      #          set y [lsort -integer [list [lindex $pnew 1] [lindex $pnew 5] ] ]
      #    
      #          set x1_new [lindex $x 0]
      #          set x2_new [lindex $x 1]
      #          set y1_new [lindex $y 0]
      #          set y2_new [lindex $y 1]
 
      #          if {[point_inside_box $x_text $y_text [list $x1_new $y1_new $x2_new $y2_new]]} {
      #            set a [$L extractNet $topc -geom [dict get $lay_connect $lay] [lindex $pnew 0] [lindex $pnew 1]]
      #            set new_layer [lindex $a 0]
      #            set new_polygons [$L iterator poly $topc $new_layer range 0 end]
      #          }
      #        }              

      #        #$L NOT $new_layer 
      #        #global name_gds_out 
      #        #global outgds
      #        #$L cellname $topc $name_gds_out
      #        #$L gdsout $outgds
      #        #exit
      #        #puts $new_polygons
      #        #puts $new_layer
      #        set keep 0
      #        foreach p $new_polygons {
      #          set x1 [lindex $p 1]
      #          set y1 [lindex $p 2]
      #          set x2 [lindex $p 5]
      #          set y2 [lindex $p 6]

      #          #puts "[point_inside_box $x1 $y1 $bbox_cut] || [point_inside_box $x1 $y2 $bbox_cut] || [point_inside_box $x2 $y1 $bbox_cut] || [point_inside_box $x2 $y2 $bbox_cut]"
      #          if { [point_inside_box $x1 $y1 $bbox_cut] || [point_inside_box $x1 $y2 $bbox_cut] || [point_inside_box $x2 $y1 $bbox_cut] || [point_inside_box $x2 $y2 $bbox_cut] } {
      #            set keep 1
      #            break
      #          }
      #        }

      #        if {$keep == 1} {
      #          puts " TEXT : [lindex $more 3] ____________________________________"
      #          set new_polygons [search_port $more $new_polygons $bbox_cut $lvl $new_layer]
      #          foreach p $new_polygons {
      #            #puts $p
      #            set ori_layer [lindex [split [lindex [lindex $p 0] 0]] 1]
      #            #puts "------------------------------------------------------"
      #            #puts [list $ori_layer [lindex $p 1] [lindex $p 2] [lindex $p 3] [lindex $p 4] \
      #                                              [lindex $p 5] [lindex $p 6] [lindex $p 7] [lindex $p 8]]

      #            lappend new_poly [list $ori_layer [lindex $p 1] [lindex $p 2] [lindex $p 3] [lindex $p 4] \
      #                                              [lindex $p 5] [lindex $p 6] [lindex $p 7] [lindex $p 8]]
      #          }
      #          $L delete polygons $topc $new_layer
      #        }
      #      }
      #    }
      #  }
      #}