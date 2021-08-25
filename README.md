# condor

Out-of-container supports for full simulation campaigns on condor-based systems.

## Usage

The following command indicates how to submit 100 single particle jobs of 10000 events each to the BNL farm:
```
./scripts/submit.sh templates/bnl.in single EVGEN/SINGLE/e-_100MeV_3to50deg.steer 10000 100
```
This can be run on EIC nodes, e.g. eic07.
