import sys
import os
import re

# folder path
dir_path = '/data/projects/memory_compiler2/REPOSITORY/Rampiler_doc/archive'

# list to store files
res = []

optionnote = open('/data/projects/memory_compiler2/REPOSITORY/Rampiler_doc/database/technote', 'r').readlines()
option_tech = {}
for line in optionnote : 
    print(line)
    line = line.strip()
    x = re.search(r'(\w+)\s?->\s?(\w+)', line).groups()
    option_tech[x[0]] = x[1]
    
doc = {}

# Iterate directory
for path in os.listdir(dir_path):
    if os.path.isfile(os.path.join(dir_path, path)):
        if not re.search(r'.docx', path):
            continue
        a = re.findall(r'^(.*_Rev_)(\d+.\d+)',path)
        if len(a) < 1:
            continue
        a = a[0]
        if a[0] in doc.keys() :
            if float(doc[a[0]]) < float(a[1]):
                doc[a[0]] = a[1]
        else :
            doc[a[0]] = a[1]
arr = []

# print(doc)
        
for kd, vd in doc.items():
    for kt, vt in option_tech.items():
        a = re.findall('(%s)_(.*?)_'%kt,kd) 
        if len(a) > 0:
            find = 1
            a = a[0]
            arr.append([kd+vd+'.docx',vt,a[1]])
            if re.search(r'tsmc07nm', vt):
                find = 0
                for ar in arr:
                    if ar[1] == 'total_tsmc' and ar[2] == a[1]:
                        find = 1
                        break
                if find == 0 :
                    arr.append([kd+vd+'.docx','tsmc_total',a[1]])
            break
    
        
arr.sort(key=lambda x: (x[1], x[2]))
print(*arr, sep='\n')
path_save = '/data/projects/memory_compiler2/REPOSITORY/Rampiler_doc/database/'    

for a in arr: 
    wordfile = dir_path+ '/' + a[0]
    if not os.path.isdir(path_save + a[1]):
        os.makedirs(path_save + a[1])
    folder = path_save + a[1] + '/' + a[2]
    path = path_save + a[1] + '/' + a[2] + '/tree'
    # if a[1] == 'tsmc03nm' and a[2] == 'SP':
    os.system("python3.8 /data/projects/memory_compiler2/scripts/fire_stim_script/makeDoc/splitDoc.py --w %s --dir %s --file %s" % (wordfile, folder, path))
    # break
