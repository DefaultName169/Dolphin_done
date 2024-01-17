 #!/usr/bin/tclsh

set re_ckt ".subckt ${name_ckt}(.*?)\n\n"
puts "type ------------------------>    $type"

if {$type == "tsmc03" } {
  if {[regexp {llpg} $name_gds_in]} {
    set re_bbox {_pins_cntrl$|pch_boost|_xpred_r}
  } else {
    set re_bbox {_(hd|hc)_xpred_(r[0-9]+|cm[0-9]+_r[0-9]+$)|_pins_cm[0-9]+$}
  }
} elseif {[regexp {_rom_} $name_gds_in]} {
  set re_bbox {ypred_t$|rom_xpred_r}
} else {
  set re_bbox {_pins_io_t|_mem_(hd|hc)_edge_b_x2|_xpred_}
}

set re_ref_del_more {(hd|hc)_xdec_(r|f|prog|cm)|_mem_|_rw_(?!.*boost)|hd_sbcnt|fsh|fshscntrl_center$|sbcnt$}

proc bbox_cut {} {
  global bbox_x 
  global bbox_y
  global type
  global name_gds_in
  if {$type == "tsmc03"} {
    if {[regexp {llpg} $name_gds_in]} {
      set bbox_cut [list  [lindex $bbox_x 0]   [lindex $bbox_y 0] \
                    [lindex $bbox_x end] [lindex $bbox_y end]]
    } else {
      set bbox_cut [list [lindex $bbox_x 0]   [lindex $bbox_y [expr [llength $bbox_y] / 2 - 1]] \
              [lindex $bbox_x end] [lindex $bbox_y [expr [llength $bbox_y] / 2 ]]]
    }
  } elseif {[regexp {_rom_} $name_gds_in]} {
    set bbox_cut [list [lindex $bbox_x 0] [lindex $bbox_y 0] [lindex $bbox_x end] [lindex $bbox_y end]]
  } else {
    set bbox_cut [list [lindex $bbox_x 0] [lindex $bbox_y [expr [llength $bbox_y] / 2 - 1]] \
              [lindex $bbox_x end] [lindex $bbox_y [expr [llength $bbox_y] / 2 ]]]
  }

  return $bbox_cut
}

proc zone_cut {} {
  global zone_x
  global zone_y
  return [list [lindex $zone_x 0] [lindex $zone_y 0] [lindex $zone_x end] [lindex $zone_y end]]
}


# proc keep_more_poly {} {
#   global L 
#   global topc
#   global layername
#   global ref_cut
#   global type
#   set layers [$L layers]
#   set refs [$L iterator ref $topc range 0 end -depth 0 0]
#   set new_ref "new"
#   foreach ref $refs {
#     set name [lindex [lindex $ref 0] 0]
#     if {[regexp {fshscntrl_center$|sbcnt$} $name]} {
#       # puts $ref
#       # puts "layers :  $layers"
#       foreach lay $layers {
#         # puts $lay
#         set skip 0
#         dict for {k v} $layername {
#           if {[regexp {^(met[0-9]+|via[0-9]+|cm|cpo|_pintxt|bbox|nimp|nwell|pimp)} $k] && $v == $lay} {
#             set skip 1
#             break
#           }
#         }

#         if {$skip == 1} {
#           continue    
#         }

#         while {1} {
#           set polys [$L iterator poly $name $lay range 0 end -depth 0 20]
#           set path [lindex [split [lindex [lindex $polys 0] 1] "/"] end]
#           if {[llength $polys] == 0} {    
#             break
#           }

#           set re {^(cmd|vg|vd|pg|cpo|nmos|pmos|pd|cellgrid|mos|dmos)}
#           if {[regexp $re $path]} {
#             set i 0
#             while {1} {
#               set far [lindex [split [lindex [lindex $polys 0] 1] "/"] end-$i ]
#               if {![regexp $re $far match]} {
#                 puts "$far delete ref $chil"
#                 set ref_del [$L iterator ref $far range 0 end]
#                 foreach r $ref_del {
#                   if {[lindex $r 0] == $chil} {
#                     $L delete ref $far {*}$r
#                   }
#                 }
#                 break
#               }
#               set i [expr $i + 1]
#               set chil $far
#             }
#           } else {
#             puts "$path delete lay $lay"
#             $L delete polygons $path $lay
#           }
#         }
#       }
#     }
#   }
#   return []
# }


proc keeptext {} {
  global bbox_x
  global topc
  global bbox_cut 
  global zone_cut
  global all_port
  global vddport
  global new_text
  global layername
  global re_cell_inside
  global name_gds_in
  global hasbk
  global L
  global name_gds_out
  global skipbk
  global allbbox


##################### Loc text ##########################
  set L1 [layout copy2 $L $topc {*}$zone_cut]
  set ports $all_port
  set textkeep []
  puts $ports


  # global new_poly
  # set vd [$L1 iterator poly $topc [dict get $layername viad] range 0 end -depth 0 20]
  # foreach v $vd {
  #   set path [lindex $v 1]
  #   if {[regexp $re_cell_inside $path]} {
  #     continue
  #   }
  #   set po [lindex $v 0]
  #   set x [lsort -integer [list [lindex $po 0] [lindex $po 4]]]
  #   set y [lsort -integer [list [lindex $po 1] [lindex $po 5]]]
  #   set x1 [lindex $x 0]
  #   set x2 [lindex $x 1]
  #   set y1 [lindex $y 0]
  #   set y2 [lindex $y 1]
  #   set poly [list $x1 $y1 $x2 $y2]
  #   if {[meta_cut_meta $poly $bbox_cut]} {
  #     # puts $po
  #     lappend new_poly [list [dict get $layername viad] {*}$po]
  #   }
  # }


  for {set lvl 4} {$lvl >= 0} {set lvl [expr $lvl - 1]} {
    if {[llength $ports] == 0} {
      break
    }
    set layer_text [dict get $layername [format "m%s_pintxt" $lvl]]
    set layer_poly [dictregexp $layername [format "met%s($|2$|b$)" $lvl]]
    
    set texts [$L iterator text $topc $layer_text range 0 end -depth 0 1]
    if {[expr $lvl % 2] == 0} {
      set texts [lsort -command sort_text_even $texts]
    } else {
      set texts [lsort -command sort_text_odd $texts]
    }
    set finded []
    foreach lay $layer_poly {
      set polygons [$L1 iterator poly $topc $lay range 0 end -depth 0 20] 
      if {[expr $lvl % 2] == 0} {
        set polygons [lsort -command sort_poly_even $polygons]
      } else {
        set polygons [lsort -command sort_poly_odd $polygons]
      }
      set lpoly []
      puts "---------------------$lay-----------------------------"
      for {set p 0} {$p < [llength $polygons]} {incr p} {
        set po [lindex $polygons $p]
        set path [lindex $po 1]
        if {![regexp $re_cell_inside $path] || ([regexp "$topc$" $path] && $lvl != 4)} {
          set all [lsearch -all -index 1 $polygons $path] 
          set j 0
          foreach a $all {
            set a [expr $a - $j] 
            set polygons [lreplace $polygons $a $a] 
            incr j
          }
          set p [expr $p - 1]
          continue
        }        
        
        set po [lindex $po 0]
        set x [lsort -integer [list [lindex $po 0] [lindex $po 4]]]
        set y [lsort -integer [list [lindex $po 1] [lindex $po 5]]]
        set x1 [lindex $x 0]
        set x2 [lindex $x 1]
        set y1 [lindex $y 0]
        set y2 [lindex $y 1]
        set poly [list $x1 $y1 $x2 $y2 $lay]
        set txt_find []

        if {$p == 0} {
          set lpoly $poly
          continue
        }

        if {[meta_cut_meta $lpoly $poly] && $lay == [lindex $lpoly 4]} {
          set x [lsort -integer [list [lindex $lpoly 0] [lindex $lpoly 2] $x1 $x2]]
          set y [lsort -integer [list [lindex $lpoly 1] [lindex $lpoly 3] $y1 $y2]]
          set lpoly [list [lindex $x 0] [lindex $y 0] [lindex $x end] [lindex $y end] $lay]
          if {$p != [expr [llength $polygons] - 1]} {
            continue
          }
        } 

        set poly $lpoly        
        set lpoly [list $x1 $y1 $x2 $y2 $lay]
        set x1 [lindex $poly 0]
        set y1 [lindex $poly 1]
        set x2 [lindex $poly 2]
        set y2 [lindex $poly 3]


        set i 0
        set all_find []
        set start 0
        while {$i < [llength $texts]} {
          set depth [expr [llength [split [lindex [lindex $texts $i] 1] "/"]] - 2]
          set t [lindex [lindex $texts $i] 0]          
          set txt_x [lindex $t 1]
          set txt_y [lindex $t 2]     
          set ori_str [lindex $t 0]
          set txt_str [string toupper $ori_str]

          if {$ori_str == "CLK1"} {
            set txt_str "ECLKBUF"
          }
          if {[regexp {(.*)_BK[0-9]$} $ori_str match one] && ![regexp $skipbk $txt_str]} {
            set txt_str $one
          }

          if {[expr $lvl % 2] == 0} {
            if {!$start} {
              if {$txt_y > [lindex $zone_cut 1]} {
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
          } else {
            if {!$start} {
              if {$txt_x < [lindex $zone_cut 2]} {
                set texts [lreplace $texts 0 [expr $i - 1]]
                set start 1
                set i 0
              } else {
                incr i
                continue
              }
            } elseif {$txt_x < $x1} {
              break
            }
          }

          # puts $txt_str

          if {[lsearch -exact $ports $txt_str] < 0 && !([regexp {^(VDD|VSS)(?!_DR)} $txt_str] && $lvl == 4)} {
            # puts $txt_str
            set list_del [lsearch -all -exact -index {0 0} $texts $ori_str]
            set j 0
            foreach l $list_del {
              set l [expr $l - $j]
              set texts [lreplace $texts $l $l]
              incr j
            }
            continue
          } 

          if {[regexp {^VDD$} $txt_str] && $depth != 0 && $lvl == 4} {
            set txt_str "VDD_INT"
          }

          if {[regexp {(VDD|VSS)ULL} $txt_str match one]} {
            set txt_str [format "%s_VUL" $one]
          } 


          if {[point_inside_box $txt_x $txt_y $poly]} {
            lappend all_find [list $lvl $txt_x $txt_y $txt_str] 
            set texts [lreplace $texts $i $i]
            continue
          } elseif {[regexp {(xdec_r[0-9]+|trk|mem_r|mem_l)_top} [lindex [lindex $texts $i] 1]] && [point_inside_box [expr $txt_x + 1000] $txt_y $poly] && [regexp {VDD|VSS} $txt_str]} {
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
        if {[regexp {VDD|VSS} $txt_str]} {
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
          if {$txt_x < $x1} {
            set txt_x $x1
          }
        }
        lappend textkeep [list $lvl $txt_x $txt_y $txt_str [list $x1 $y1 $x2 $y2 $lay]]
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
  puts "-------------------------------------------"
##########################################################################################################################
  
  # foreach txt $textkeep {
  #   puts $txt
  # }

  ############# Xu ly text vua loc ################
  if {[regexp {sp{1,3}mb} $name_gds_in] } {
    set middle_cell [lsearch -inline -all -regexp -index 0 $allbbox {cntrl_prog}]
    set middle_cell [lsort -index {3 2} -integer -decreasing $middle_cell]

    for {set i 0} {$i < [llength $middle_cell]} {incr i} {
      set middle_cell [lreplace $middle_cell $i $i [lindex [lindex [lindex $middle_cell $i] 3] 2]]
    }
    puts $middle_cell
  
    for {set i 0} {$i < [llength $middle_cell]} {incr i} {
      set line [lindex $middle_cell $i]
      if {$i == 0} {
        set zone_x2 [lindex $zone_cut 2]
      } else {
        set zone_x2 [expr ([lindex $middle_cell $i] + [lindex $middle_cell [expr $i - 1]]) /2 ]
      }

      if {$i == [expr [llength $middle_cell] - 1]} {
        set zone_x1 [lindex $zone_cut 0] 
      } else {
        set zone_x1 [expr ([lindex $middle_cell $i] + [lindex $middle_cell [expr $i + 1]]) /2 ]
      }

      set zone [list $zone_x1 [lindex $bbox_cut 1] $zone_x2 [lindex $bbox_cut 3]]
      puts $zone

      set textzone []
      for {set t 0} {$t < [llength $textkeep]} {incr t} {
        set txt [lindex $textkeep $t]
        set lvl [lindex $txt 0]
        set txt_x [lindex $txt 1]
        set txt_y [lindex $txt 2]
        set txt_str [lindex $txt 3]
        set poly [lindex $txt 4]
        if {![point_inside_box $txt_x $txt_y $zone]} {
          continue
        }
        lappend textzone $txt
        set textkeep [lreplace $textkeep $t $t]
        set t [expr $t - 1]
      }

      for {set t 0} {$t < [llength $textzone]} {incr t} {
        set txt [lindex $textzone $t]
        set lvl [lindex $txt 0]
        set txt_x [lindex $txt 1]
        set txt_y [lindex $txt 2]
        set txt_str [lindex $txt 3]
        if {[regexp {_BK[0-9]} $txt_str]} {
          continue
        
        } elseif {[regexp {PD?([A-Z])_(TOP|BOT)([0-9])} $txt_str str alpha type digit]} {
          set all [lsearch -all -regexp -index 3 $textzone [format "PD?%s_(TOP|BOT)%s" $alpha $digit]]
          set top [format "PD%s_TOP%s_BK%s" $alpha $digit [expr 2*$i]]
          set bot [format "PD%s_BOT%s_BK%s" $alpha $digit [expr 2*$i]]
          set textzone [lreplace $textzone [lindex $all 0] [lindex $all 0] [lreplace [lindex $textzone [lindex $all 0]] 3 3 $bot]]
          set textzone [lreplace $textzone [lindex $all 1] [lindex $all 1] [lreplace [lindex $textzone [lindex $all 1]] 3 3 $top]]
        
        } elseif {[regexp {PCH_(TOP|BOT)} $txt_str]} { 
          set all [lsearch -all -regexp -index 3 $textzone {PCH_(TOP|BOT)}]
          set top [format "PCH_TOP_BK%s:" [expr 2*$i]]
          set bot [format "PCH_BOT_BK%s:" [expr 2*$i]]
          set textzone [lreplace $textzone [lindex $all 0] [lindex $all 0] [lreplace [lindex $textzone [lindex $all 0]] 3 3 $bot]]
          set textzone [lreplace $textzone [lindex $all 1] [lindex $all 1] [lreplace [lindex $textzone [lindex $all 1]] 3 3 $top]]
        
        } elseif {[regexp {TRK} $txt_str]} {
          set all [lsearch -all -index 3 $textzone $txt_str]
          set new_str [format "%s_BK%s" $txt_str [expr 2*$i + 1]]
          set la -1
          set j 0
          foreach a $all {
            set a [expr $a - $j]
            if {$la == -1} {
              set trk [lindex $textzone $a]
              set vectormin [vector [lindex $bbox_cut 0] [lindex $bbox_cut 3] [lindex [lindex $textzone $a] 1] [lindex [lindex $textzone $a] 2]]
            } elseif {[vector [lindex $bbox_cut 0] [lindex $bbox_cut 3] [lindex [lindex $textzone $a] 1] [lindex [lindex $textzone $a] 2]] < $vectormin} {
              set trk [lindex $textzone $a]
              set vectormin [vector [lindex $bbox_cut 0] [lindex $bbox_cut 3] [lindex [lindex $textzone $a] 1] [lindex [lindex $textzone $a] 2]]
            }
            set textzone [lreplace $textzone $a $a]
            incr j
          } 
          set t [expr $t - 1]
          lappend textzone [lreplace $trk 3 3 $new_str]
        
        } elseif {[lsearch $hasbk $txt_str] >= 0} {
          set all [lsearch -all -index 3 $textzone $txt_str]
          if {[llength $all] > 1} {
            foreach a $all {
              if {[lindex [lindex $textzone $a] 1] < $line} {
                set new_str [format "%s_BK%s" $txt_str [expr 2*$i + 1]]
              } else {
                set new_str [format "%s_BK%s" $txt_str [expr 2*$i]]
              }
              set textzone [lreplace $textzone $a $a [lreplace [lindex $textzone $a] 3 3 $new_str]]
            }
          } else {
            set textzone [lreplace $textzone $t $t [lreplace $txt 3 3 [format "%s_BK%s" $txt_str [expr 2*$i]]]]
          }

        } elseif {[regexp {(VDD|VSS)_VUL} $txt_str]} {
          if {$txt_x < $line} {
            set new_str [format "%s_BK%s" $txt_str [expr 2*$i + 1]]
          } else {
            set new_str [format "%s_BK%s" $txt_str [expr 2*$i]]
          }
          set textzone [lreplace $textzone $t $t [lreplace [lindex $textzone $t] 3 3 $new_str]]
        
        } elseif {[regexp {VDD_INT} $txt_str]} {
          if {$txt_x < $line} {
            set new_str [format "%s_BK%s" $txt_str [expr 2*$i]]
          } elseif {$i != 0} {
            set new_str [format "%s_BK%s" $txt_str [expr 2*$i - 1]]
          } else {
            set new_str $txt_str
          }
          set textzone [lreplace $textzone $t $t [lreplace [lindex $textzone $t] 3 3 $new_str]]
        
        } elseif {[regexp {VDD|VSS} $txt_str]} {
          set new_str $txt_str
          set textzone [lreplace $textzone $t $t [lreplace [lindex $textzone $t] 3 3 $new_str]]
        }
      }
      lappend textdone {*}$textzone
    }
    set textkeep $textdone
  } else {
    for {set t 0} {$t < [llength $textkeep]} {incr t} {
      set txt [lindex $textkeep $t]
      set lvl [lindex $txt 0]
      set txt_x [lindex $txt 1]
      set txt_y [lindex $txt 2]
      set txt_str [lindex $txt 3]
      set poly [lindex $txt 4]

      if {[regexp {TRK} $txt_str]} {
        set all [lsearch -all -index 3 $textkeep $txt_str]
        set la -1
        set j 0
        foreach a $all {
          set a [expr $a - $j]
          if {$la == -1} {
            set lvector [vector [lindex $bbox_cut 0] [lindex $bbox_cut 3] [lindex [lindex $textkeep $a] 1] [lindex [lindex $textkeep $a] 2]]
            set la $a
          } else {
            if {[vector [lindex $bbox_cut 0] [lindex $bbox_cut 3] [lindex [lindex $textkeep $a] 1] [lindex [lindex $textkeep $a] 2]] < $lvector} {
              set textkeep [lreplace $textkeep $la $la]
              set la [expr $a - 1]
            } else {
              set textkeep [lreplace $textkeep $a $a]
            }
            incr j
          }
        } 
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
    set re "SACLKB|^PCH$|^PCH_W$|^PCH_R$|^PCH_A$|^PCH_B$|PCHSA|WSEL|RSEL|BOOST|SCSEL|^BEB$|^BE$|CSEL_BOT|CSEL_TOP|SAPSG|PCH_BOT|PCH_TOP|OE$|OE_W$|OE_R$|OE_A$|OE_B$|^SEL|^CLKM$|^CLKS$|WCLAMPB$"
    if {![regexp {rom} $name_gds_in]} {
      set re "$re|ECLK"
    }
    if {[regexp $re $txt_str] && $lvl == 3} {
      lappend new_text [list $lay $txt_x $y1 "$txt_str:"]
      lappend new_text [list $lay $txt_x $y2 "$txt_str:"]
      continue
    } elseif {[regexp {(VDD|VSS)} $txt_str str option] } {
      if { [lsearch $vddport $txt_str] < 0} {
        set txt_str $option
      }
      set txt_str "$txt_str:"
    }
    lappend new_text [list $lay $txt_x $txt_y $txt_str]
  }
  puts "done text"
  return $new_text
}


# proc move_pin {} {
#   global L
#   global layername
#   global new_text
#   global topc

#   set poly [$L iterator poly $topc [dictregexp $layername {met3($|b$)}] range 0 end -depth 0 20]
#   for {set i 0} {$i < [llength $new_text]} {incr i} {
#     set this  [lindex $new_text $i]
#     set txt_x [lindex $this 1]
#     set txt_y [lindex $this 2]
#     set lay [lindex $this 0]
#     set txt_str [lindex $this 3]
#     if { [regexp ":" $txt_str] && ![regexp "VDD|VSS" $txt_str] } {
#       foreach p $poly {
#         set p [lindex $p 0]
#         set x [lsort -integer [list [lindex $p 0] [lindex $p 4]]]
#         set y [lsort -integer [list [lindex $p 1] [lindex $p 5]]]
        
#         set x1 [lindex $x 0]
#         set x2 [lindex $x 1]
#         set y1 [lindex $y 0]
#         set y2 [lindex $y 1]
        
#         if { [point_inside_box $txt_x $txt_y [list $x1 $y1 $x2 $y2] ] } {
#           if {[expr $y2 - $txt_y] < [expr $txt_y - $y1]} {
#             set new_text [lreplace $new_text $i $i [list $lay $txt_x $y2 $txt_str]]
#           } else {
#             set new_text [lreplace $new_text $i $i [list $lay $txt_x $y1 $txt_str]]
#           }
#         }      
#         #if { [point_inside_box $txt_x $txt_y [list $x1 $y1 $x2 $y2] ] } {
#         #  set new_text [lreplace $new_text $i [expr $i + 1] [list $lay $txt_x $y1 $txt_str] [list $lay $txt_x $y2 $txt_str] ]  
#         #  break
#         #}
#       }
#       #set i [expr $i + 1]
#     }
#   }
#   return $new_text
# }
