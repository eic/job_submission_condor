import subprocess
import sys
import csv
from itertools import islice

# read params
n = int(sys.argv[1])
csv_base = sys.argv[2]

# PanDA SEQNUMBER starts from 1, but CSV is 0-indexed
csv_index = n - 1

# Memory-efficient: read only the nth row without loading entire file
with open(f"{csv_base}.csv") as f:
    reader = csv.reader(f)
    # Skip to nth row without loading all rows into memory
    params = next(islice(reader, csv_index, csv_index+1), None)
    if params is None:
        print(f"Error: Row {n} not found in CSV file", file=sys.stderr)
        sys.exit(1)

# execute directly without shell
result = subprocess.run(
    ["/opt/campaigns/hepmc3/scripts/run.sh", f"EVGEN/{params[0]}", params[1], params[2], params[3]],
    text=True
)
sys.exit(result.returncode)
