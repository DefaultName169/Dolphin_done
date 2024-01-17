import sys
import os
import argparse

parser = argparse.ArgumentParser()

parser.add_argument('-split', action='store_true', help='-split')
parser.add_argument('-make', action='store_true', help='-make --tech TECH --type TYPE')
# parser.add_argument('-make', help='[-split] or [-make]')

parser.add_argument('--tech', required=False, help="")
parser.add_argument('--type', required=False, help="")

def get_input(var_name):
    auto_input = getattr(cli_args, var_name, None) 
    if auto_input :
        return auto_input
    else:
        return input("%s input: "%var_name)

cli_args = parser.parse_args()

if cli_args.split :
    os.system("python3.8 /data/projects/memory_compiler2/scripts/fire_stim_script/makeDoc/makeDatabase.py")
elif cli_args.make:
    tech = get_input("tech")
    type = get_input("type")
    os.system("python3.8 /data/projects/memory_compiler2/scripts/fire_stim_script/makeDoc/mergeDoc.py --tech %s --type %s" % (tech,type))
else: 
    print('command incorrect')
    exit()

