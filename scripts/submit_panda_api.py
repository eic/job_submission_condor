#!/usr/bin/env python3
"""
PanDA submission using PrunScript and panda_api.
Called from submit_csv.sh to submit tasks with resource configuration.
"""
import sys
import argparse
from pandaclient import PrunScript
from pandaclient import panda_api


def main():
    parser = argparse.ArgumentParser(description="Submit PanDA tasks with resource configuration")
    parser.add_argument("--exec", dest="exec_cmd", required=True, help="Command to execute")
    parser.add_argument("--nJobs", type=int, required=True, help="Number of jobs")
    parser.add_argument("--outDS", required=True, help="Output dataset name")
    parser.add_argument("--vo", required=True, help="Virtual organization")
    parser.add_argument("--site", required=True, help="PanDA site")
    parser.add_argument("--prodSourceLabel", required=True, help="Production source label")
    parser.add_argument("--workingGroup", required=True, help="Working group")
    parser.add_argument("--noBuild", action="store_true", help="Skip build step")
    parser.add_argument("--workDir", default=".", help="Working directory")
    parser.add_argument("--containerImage", default=None, help="Container image path")
    parser.add_argument("--nCore", type=int, default=1, help="Number of CPU cores")
    parser.add_argument("--memory", type=int, default=4096, help="Memory in MB")
    parser.add_argument("--disk", type=int, default=None, help="Work disk count in MB")

    args = parser.parse_args()

    # Build prun arguments for PrunScript
    prun_args = [
        "--exec", args.exec_cmd,
        "--nJobs", str(args.nJobs),
        "--outDS", args.outDS,
        "--vo", args.vo,
        "--site", args.site,
        "--prodSourceLabel", args.prodSourceLabel,
        "--workingGroup", args.workingGroup,
        "--workDir", args.workDir,
        "--nCore", str(args.nCore),
        "--memory", str(args.memory)
    ]

    if args.noBuild:
        prun_args.append("--noBuild")

    if args.containerImage:
        prun_args.extend(["--containerImage", args.containerImage])

    # Parse parameters using PrunScript
    params = PrunScript.main(True, prun_args)

    # Add work disk configuration if specified
    if args.disk is not None:
        params['workDiskCount'] = args.disk
        params['workDiskUnit'] = 'MB'

    # Submit task
    client = panda_api.get_api()
    result = client.submit_task(params)

    print(f"Submission result: {result}")

    # Return appropriate exit code
    if result and result[0] == 0:
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
