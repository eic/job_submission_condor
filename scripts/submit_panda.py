import subprocess
import sys
import csv

# read params
n = int(sys.argv[1])
with open(sys.argv[2]) as f:
    reader = csv.reader(f)
    params = list(reader)[n]  # params is now a list of fields

# construct exec string with multiple fields
exec_str = f"/opt/campaigns/hepmc3/scripts/run.sh {params[0]} {params[1]} {param[2]} {param[3]}"

# execute
ps = subprocess.Popen(exec_str, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True, bufsize=1)
for l in ps.stdout:
    print(l.strip())
c = ps.wait()
sys.exit(c)
