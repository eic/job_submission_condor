#!/usr/bin/env python3
"""
PanDA submission using panda_api client directly.
Called from submit_csv.sh to submit tasks with resource configuration.
"""
import sys
import argparse
import os
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
    parser.add_argument("--taskType", default="epicproduction", help="Task type (e.g., test, prod, analysis)")

    args = parser.parse_args()

    # Build task parameters directly for panda client
    params = {
        'vo': args.vo,
        'site': args.site,
        'workingGroup': args.workingGroup,
        'prodSourceLabel': args.prodSourceLabel,
        'processingType': 'analysis',
        'taskType': args.taskType,
        'taskName': args.outDS,
        'userName': None,  # Will be filled by client
        'architecture': '',
        'transUses': '',
        'transHome': None,
        'transPath': 'python3',
        'coreCount': args.nCore,
        'ramCount': args.memory,
        'nJobs': args.nJobs,
        'nEventsPerJob': 1,
        'nEventsPerRange': 1,
        'nFilesPerJob': 1,
        'jobParameters': [
            {
                'type': 'constant',
                'value': args.exec_cmd,
                'padding': False,
                'offset': 0
            }
        ],
        'log': {
            'type': 'template',
            'param_type': 'log',
            'value': f'{args.outDS}.$(SN).log.tgz',
            'dataset': args.outDS + '_log/',
            'hidden': False
        }
    }

    # Add work disk configuration if specified
    if args.disk is not None:
        params['workDiskCount'] = args.disk
        params['workDiskUnit'] = 'MB'

    # Add container image if specified
    if args.containerImage:
        params['container_name'] = args.containerImage

    # Add current working directory files if not noBuild
    if not args.noBuild:
        # Get list of files in working directory
        work_files = []
        for fname in os.listdir(args.workDir):
            fpath = os.path.join(args.workDir, fname)
            if os.path.isfile(fpath):
                work_files.append(fname)

        if work_files:
            params['inputFiles'] = ','.join(work_files)

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
