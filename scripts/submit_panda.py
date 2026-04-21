import subprocess
import sys
import os
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
    params = next(islice(reader, csv_index, csv_index + 1), None)
    if params is None:
        print(f"Error: Row {n} not found in CSV file", file=sys.stderr)
        sys.exit(1)

# CSV columns: numberOfEvents, seed
n_events = params[0]
seed = params[1]

# Clone Celeritas from fork
CELERITAS_REPO = "https://github.com/rahmans1/celeritas.git"
CELERITAS_BRANCH = "enable-dd4hep-particle-handler"

src_dir = os.path.abspath("celeritas")
build_dir = os.path.abspath("build")
install_dir = os.path.abspath("install")

print(f"=== Cloning Celeritas ({CELERITAS_BRANCH}) ===")
result = subprocess.run([
    "git", "clone", "--branch", CELERITAS_BRANCH, "--depth", "1",
    CELERITAS_REPO, src_dir,
], text=True)
if result.returncode != 0:
    print("ERROR: git clone failed", file=sys.stderr)
    sys.exit(result.returncode)

os.makedirs(build_dir, exist_ok=True)

print(f"=== Configuring Celeritas ===")
result = subprocess.run([
    "cmake",
    "-GNinja",
    f"-DCMAKE_INSTALL_PREFIX={install_dir}",
    "-DCELERITAS_USE_CUDA=ON",
    "-DCELERITAS_USE_DD4hep=ON",
    "-DCMAKE_CUDA_ARCHITECTURES=native",
    "-DCELERITAS_USE_VecGeom=ON",
    "-S", src_dir,
    "-B", build_dir,
], text=True)
if result.returncode != 0:
    print("ERROR: CMake configure failed", file=sys.stderr)
    sys.exit(result.returncode)

print(f"=== Building Celeritas ===")
result = subprocess.run(["ninja", "install"], cwd=build_dir, text=True)
if result.returncode != 0:
    print("ERROR: Build failed", file=sys.stderr)
    sys.exit(result.returncode)

# Run ddceler example
os.environ["Celeritas_ROOT"] = install_dir

run_script = os.path.join(src_dir, "example", "ddceler", "run-preshower.sh")
print(f"=== Running ddceler: {n_events} events, seed {seed} ===")
result = subprocess.run(
    [run_script, "celeritas", f"--numberOfEvents={n_events}", f"--random.seed={seed}"],
    text=True,
)
sys.exit(result.returncode)
