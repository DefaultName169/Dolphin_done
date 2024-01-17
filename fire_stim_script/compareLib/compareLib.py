import os
import sys
import argparse
from liberty.parser import parse_liberty
import numpy as np
import xlsxwriter

parser = argparse.ArgumentParser()    
parser.add_argument('<file1>', help='First file')
parser.add_argument('<file2>', help='Second file')
cli_args = parser.parse_args()

################################### FUNCTION    ####################

def percent_list(list1, list2):
    return np.array([[list1[i][j]/list2[i][j]*100 for j in range(len(list1[i])) ] for i in range(len(list1))] )

def compare_internal_power(lib1, lib2):
    global row
    global sheet
    internal_power1 = lib1.get_groups('internal_power')
    internal_power2 = lib2.get_groups('internal_power')
    for inter1 in internal_power1:
        when = inter1.get_attribute('when')
        inter2 = next(i for i in internal_power2 if i.get_attribute('when') == when)
        start_rise = row 
        condition = 'internal_power ' + str(when) if when != None else '' +' rise_power'
        compare_array(inter1.get_group('rise_power'), inter2.get_group('rise_power'), 'internal_power', 'values')
        for i in range(start_rise, row):
            sheet.write('B' + str(i), condition) 
        
        start_fall = row 
        condition = 'internal_power ' + str(when) if when != None else '' +' fall_power'
        compare_array(inter1.get_group('fall_power'), inter2.get_group('fall_power'), 'internal_power', 'values')
        for i in range(start_fall, row):       
            sheet.write('B' + str(i), condition) 
            
            
def compare_template(lib_content1, lib_content2, temp):
    global row
    global sheet
    lib1 = lib_content1.get_groups(temp)
    lib2 = lib_content2.get_groups(temp)
    
    for pin1 in lib1:
        pin_name = pin1.args[0]
        pin2 = next(i for i in lib2 if i.args[0] == pin_name)
        attr = [i.name for i in pin1.attributes]
        
        for att in attr:
            if 'index' in att:
                index1 = pin1.get_array(att)
                index2 = pin2.get_array(att)
                index_per = percent_list(index1, index2)
                pin1.set_array(att, index_per)
                
     
def compare_timing_bus(lib_content1, lib_content2):
    bus1 = lib_content1.get_groups('bus')
    bus2 = lib_content2.get_groups('bus')
    for b1 in bus1:
        bus_value = b1.args[0]
        b2 = next(i for i in bus2 if i.args[0] == bus_value)
        compare_timing_pin(b1, b2)
        
        
    
def compare_timing_pin(lib_content1, lib_content2):
    global row
    global sheet
    global level
    global max_row
    
    lib1 = lib_content1.get_groups('pin')
    lib2 = lib_content2.get_groups('pin')
    
    lib1 = sorted(lib1, key= lambda x : x.group_name)
    for pin1 in lib1:
        pin_name = pin1.args[0]
        # print (pin_name)
        # add_new_sheet(pin_name)
        pin2 = next(i for i in lib2 if i.args[0] == pin_name)
        
        max_row = row
        row += 1
        start_pin = row
        if pin_name == 'CLK' :
            compare_attribute(pin1, pin2, 'capacitance')
            row+=1
            compare_attribute(pin1, pin2, 'min_pulse_width_high')
            row+=1
            compare_attribute(pin1, pin2, 'min_pulse_width_low')
            row+=1
            
            minimum_period1 = pin1.get_groups('minimum_period')
            minimum_period2 = pin2.get_groups('minimum_period')
            
            for min1 in minimum_period1:
                when = min1.get_attribute('when')
                min2 = next(i for i in minimum_period2 if i.get_attribute('when') == when)
                sheet.write('B' + str(row), 'minimum_period ' + str(when))
                compare_attribute(min1, min2, 'constraint')
                row += 1 
            
            compare_internal_power(pin1, pin2)
            
            
        
        else :
            all_att = [i.name for i in pin1.attributes]
            for att in all_att:
                if 'capacitance' in att:
                    compare_attribute(pin1, pin2, att)
                    row+=1
            timing1s = pin1.get_groups('timing')
            timing2s = pin2.get_groups('timing')
            
            compare_internal_power(pin1, pin2)
            
            for tim1 in timing1s:
                when = tim1.get_attribute('when')
                timing_type = tim1.get_attribute('timing_type')
                tim2 = next(i for i in timing2s if i.get_attribute('when') == when and i.get_attribute('timing_type') == timing_type)
                    
                when = '' if when == None else str(when)
                timing_type = '' if timing_type == None else timing_type
                for tim_gr in tim1.groups:
                    start_timming = row 
                    condition = 'timimg' + ' ' + str(when) + ' ' + timing_type + ' ' + tim_gr.group_name
                    compare_array(tim1.get_group(tim_gr.group_name), tim2.get_group(tim_gr.group_name), 'timing','values')
                    for i in range(start_timming, row):
                        sheet.write('B' + str(i), condition) 
        
        data_max = [str(pin_name), 'Max'] + ['{=INDEX('+chr(i)+str(start_pin)+':'+chr(i)+str(row-1)+',MATCH(MAX(ABS('+chr(i)+str(start_pin)+':'+chr(i)+str(row-1)+')),ABS('+chr(i)+str(start_pin)+':'+chr(i)+str(row-1)+'),0))}' for i in range(ord('C'), ord('H'))]
        sheet.write_row('A' + str(max_row), data_max)
        for i in range(start_pin, row):       
            sheet.write('A' + str(i), str(pin_name))
            sheet.set_row(i - 1, None, None, {'level': level, 'hidden' : True})
        
        
def compare_attribute(lib1, lib2, att):
    global sheet
    global row
    global percent_array
    
    att1 = lib1.get_attribute(att)  
    att2 = lib2.get_attribute(att)  
    n = next(i for i in range(len(lib1.attributes)) if lib1.attributes[i].name == att)
    value = (att1-att2)/att1*100
    percent_array.append(value)
    
    if att == 'area':
        sheet.write_row('C1', ['area1', att1, value])
        sheet.write_row('C2', ['area2', att2, value])
    elif att == 'cell_leakage_power':
        sheet.write_row('F1', ['cell_leakage_power1', att1, value])
        sheet.write_row('F2', ['cell_leakage_power2', att2, value])
    elif att == 'constraint':
        sheet.write_row('D' + str(row) , [att1, att2, value, att1 - att2 ])
    else:
        sheet.write_row('B' + str(row), [att, '', att1, att2, value, att1-att2])
    lib1.attributes[n].value = value


def compare_array(lib1, lib2, pin, att):
    global sheet
    global row
    global max_row
    global percent_array
    global color_red
    global color_orange
    global color_yellow
    
    list1 = lib1.get_array(att)
    list2 = lib2.get_array(att)
    
    # list_per = list1.copy()
    # list_diff = list1.copy()
    
    for i in range(len(list1)):
        for j in range(len(list1[i])):
            index = str(i+1) + '.' + str(j+1)
            value_per = (list1[i][j]-list2[i][j])/list1[i][j] * 100 
            value_per = value_per if not np.isnan(value_per) else 0
            value_diff = (list1[i][j] - list2[i][j])
            # list_per[i][j] = value_per 
            # list_diff[i][j] = value_diff
            
            percent_array.append(value_per)
            
            
            if pin != 'internal_power' :
                value = [index, list1[i][j] * 1000 , list2[i][j] * 1000, value_per, value_diff * 1000]
            else:
                value = [index, list1[i][j] , list2[i][j] , value_per, value_diff]
                
            sheet.write_row('C' + str(row), value)
            if abs(value_per) > 10:
                sheet.set_row(max_row - 1, None, color_red)
                sheet.write('F' + str(row), value_per, color_red)
                sheet.set_tab_color('#ff0000')
            elif abs(value_per) > 5:
                sheet.write('F' + str(row), value_per, color_yellow)
            row += 1
    
    # if not np.any(np.isnan(list_per)):
    #     lib1.set_array(att +'_per' , list_per)
    # remove_attribute(lib1, att)
    # lib1.set_array(att +'_diff', list_diff)
     

def remove_attribute(lib1, att):
    att1 = lib1.attributes
    n = next(i for i in range(len(lib1.attributes)) if lib1.attributes[i].name == att)
    att1.pop(n)

# def add_new_sheet (sheet_name):
#     global workbook
#     global sheet
#     global row 
#     global lib_path1
#     global lib_path2
#     global num_format
#     global area1, area2, cell_leakage_power1, cell_leakage_power2
#     row = 4
#     sheet_name = str(sheet_name).replace('\"','') 
#     sheet_name = str(sheet_name).replace('[', '(')
#     sheet_name = str(sheet_name).replace(']', ')')
#     sheet_name = str(sheet_name).replace(':', '-')
#     sheet = workbook.add_worksheet(name= sheet_name)
#     sheet.set_column('F:F', None, num_format)
#     sheet.set_column('G4:G', None, num_format)
#     # lib_path1 = '1/dti_spp_tm07nmsvta768x47m4c1sespsbsram/dti_spp_tm07nmsvta768x47m4c1sespsbsram_ffgnp0c.lib'
#     # lib_path2 = '2/dti_spp_tm07nmsvta768x47m4c1sespsbsram/dti_spp_tm07nmsvta768x47m4c1sespsbsram_ffgnp0c.lib'
    
#     sheet.write_row('A1', ['File1:', lib_path1, 'area', area1, 'cell_leakage_power', cell_leakage_power1])
#     sheet.write_row('A2', ['File2:', lib_path2, 'area', area2, 'cell_leakage_power', cell_leakage_power2])
#     sheet.write_row('A3', ['Pin:', 'Condition', 'index', 'Value1', 'Value2', 'Percent(%)', 'Diff(ps)'])
    # return sheet
########################################## MAIN ##########################
# sheet = None
# row = None
# area1 = None
# area2 = None
# cell_leakage_power1 = None
# cell_leakage_power2 = None

workbook  = xlsxwriter.Workbook('output.xlsx')

lib_path1 = sys.argv[1]
lib_path2 = sys.argv[2]
# lib_path1 = '1/dti_spp_tm07nmsvta768x47m4c1sespsbsram/dti_spp_tm07nmsvta768x47m4c1sespsbsram_ffgnp0c.lib'
# lib_path2 = '2/dti_spp_tm07nmsvta768x47m4c1sespsbsram/dti_spp_tm07nmsvta768x47m4c1sespsbsram_ffgnp0c.lib'

percent_array = []
max_row = 0
row = 4
level = 1
num_format = workbook.add_format({'num_format': '0.00'})
sheet = workbook.add_worksheet(name= os.path.splitext(lib_path1)[0][-31:])
# sheet = workbook.add_worksheet()

sheet.set_column('D4:F', None, num_format)
sheet.set_column('E4:G', None, num_format)
sheet.set_column('F4:F', None, num_format)
sheet.set_column('G4:G', None, num_format)
sheet.write_row('A1', ['File1:', os.path.abspath(lib_path1)])
sheet.write_row('A2', ['File2:', os.path.abspath(lib_path2)])
sheet.write_row('A3', ['Pin:', 'Condition', 'index', 'Value1', 'Value2', 'Percent(%)', 'Diff(ps)'])


color_yellow = workbook.add_format({'bg_color': 'yellow'})
color_orange = workbook.add_format({'bg_color': 'orange'})
color_red = workbook.add_format({'bg_color': 'red'})

lib_content1 = parse_liberty(open(lib_path1).read())
lib_content2 = parse_liberty(open(lib_path2).read())

all_groups = [i.group_name for i in lib_content1.groups]
all_groups = set(all_groups)

for groups in all_groups:
    if "template" in groups:
        compare_template(lib_content1, lib_content2, groups)
    if groups == 'cell':
        cell1 = lib_content1.get_group('cell')
        cell2 = lib_content2.get_group('cell')
        
        # leak_pow1 = cell1.get_group('leakage_power')
        # leak_pow2 = cell2.get_group('leakage_power')
        
        # compare_attribute(leak_pow1, leak_pow2, 'value')
        
        
        compare_attribute(cell1, cell2, 'area')
        compare_attribute(cell1, cell2, 'cell_leakage_power')
        
        compare_timing_pin(cell1, cell2)
        compare_timing_bus(cell1, cell2)

sheet.autofit()

percent_array = sorted(percent_array, key= lambda x: abs(x))
if percent_array[-1] != 0:
    print(lib_path1, lib_path2, percent_array[-1], 'DIFF')
else: 
    print(lib_path1, lib_path2, 0, 'SAME')

workbook.close()


# with open(file_out, 'w') as output_file:
#     output_file.write(str(lib_content1))
    
# lines = open(file_out, 'r').readlines()
# debug = open(file_debug, 'w')
# debug = open(file_debug, 'a')


# start_index = False
# lastname = ''
# for line_index in range(len(lines)):
#     line_ori = lines[line_index]
#     line = line_ori.strip()
#     if re.search( r'index|values_diff', line):
#         start_index = True
        
#         continue
#     if ');' in line and start_index :
#         start_index = False
        
#     if start_index:
#         line = re.sub(r'\"|\\','',line)
#         data = np.fromstring(line, sep=', ')
#         if not (np.all(data == 0) or np.all(data == 100)):
#             if lastname == name:
#                 debug.write(name +':\n')  
#                 lastname = ''
#             debug.write('\t' + str(line_index + 1) + '\n')            

#     elif re.search(r'^\s{2,4}((.*?template|pin|bus)\s\(.*\))', line_ori):
#         name = re.search(r'^\s{2,4}((.*?template|pin|bus)\s\(.*\))',line_ori).group(1)
#         lastname = name