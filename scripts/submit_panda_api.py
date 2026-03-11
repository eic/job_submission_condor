#!/usr/bin/env python3
"""
PanDA submission using panda_api client directly.
Called from submit_csv.sh to submit tasks with resource configuration.
"""
import sys
import argparse
import os
import uuid
import re
import tarfile
import tempfile
from pandaclient import panda_api
from pandaclient import Client


def main():
    parser = argparse.ArgumentParser(description="Submit PanDA tasks with resource configuration")
    parser.add_argument("--exec", dest="exec_cmd", required=True, help="Command to execute")
    parser.add_argument("--nJobs", type=int, required=True, help="Number of jobs")
    parser.add_argument("--outDS", required=True, help="Output dataset name")
    parser.add_argument("--workingGroup", default="EIC", help="Working group")
    parser.add_argument("--vo", default="epic", help="Virtual organization")
    parser.add_argument("--site", default="BNL_OSG_PanDA_1", help="PanDA site")
    parser.add_argument("--prodSourceLabel", default="test", help="Production source label")
    parser.add_argument("--noBuild", action="store_true", default=False, help="Skip build step")
    parser.add_argument("--workDir", default=".", help="Working directory")
    parser.add_argument("--containerImage", default="/cvmfs/singularity.opensciencegrid.org/eicweb/eic_xl:nightly", help="Container image path")
    parser.add_argument("--nCore", type=int, default=1, help="Number of CPU cores")
    parser.add_argument("--memory", type=int, default=4096, help="Memory in MB")
    parser.add_argument("--disk", type=int, default=4096, help="Work disk count in MB")
    parser.add_argument("--taskType", default="prod", help="Task type (test, prod, or anal)")

    args = parser.parse_args()

    # Get PanDA client
    client = panda_api.get_api()

    # Extract sourceURL from Client class (not instance)
    # Use baseURLSSL for VO-based submissions (matching prun logic)
    source_url = None
    if hasattr(Client, 'baseURLSSL'):
        match = re.search(r'(https?://[^/]+)/', Client.baseURLSSL)
        if match:
            source_url = match.group(1)

    # Debug: print the extracted sourceURL
    print(f"DEBUG: Extracted sourceURL = {source_url}")
    print(f"DEBUG: Client.baseURLSSL = {getattr(Client, 'baseURLSSL', 'N/A')}")

    # Build task parameters directly for panda client
    params = {
        'vo': args.vo,
        'site': args.site,
        'workingGroup': args.workingGroup,
        'prodSourceLabel': args.prodSourceLabel,
        'processingType': 'epicproduction',
        'taskType': args.taskType,
        'taskName': args.outDS,
        'userName': None,  # Will be filled by client
        'noInput': True,  # Task does not require input datasets
        'noOutput': True,  # Do not register output files; only payload/pilot logs are kept
        'architecture': '',
        'transUses': '',
        'transHome': None,
        'transPath': 'https://pandaserver-doma.cern.ch/trf/user/runGen-00-00-02',
        'sourceURL': source_url,  # Set sourceURL for ${SURL} substitution
        'coreCount': args.nCore,
        'ramCount': args.memory,
        'nEvents': args.nJobs,
        'nEventsPerJob': 1,
        'jobParameters': [
            {
                'type': 'constant',
                'value': '-j "" --sourceURL ${SURL}',
            },
            {
                'type': 'constant',
                'value': '-r .',
            },
        ],
        'multiStepExec': {
            'preprocess': {
                'command': '${TRF}',
                'args': '--preprocess ${TRF_ARGS}'
            },
            'postprocess': {
                'command': '${TRF}',
                'args': '--postprocess ${TRF_ARGS}'
            },
            'containerOptions': {
                'containerExec': 'echo "=== cat exec script ==="; cat __run_main_exec.sh; echo; echo "=== exec script ==="; /bin/sh __run_main_exec.sh',
                'containerImage': args.containerImage
            }
        },
        'log': {
            'type': 'template',
            'param_type': 'log',
            'value': f'{args.outDS}.$JEDITASKID.${{SN}}.log.tgz',
            'dataset': args.outDS + '_log/',
            'hidden': True
        }
    }

    # Add work disk configuration if specified
    if args.disk is not None:
        params['workDiskCount'] = args.disk
        params['workDiskUnit'] = 'MB'

    # Add container image if specified
    if args.containerImage:
        params['container_name'] = args.containerImage

    # Create and upload tarball with workDir files (matching prun --noBuild behavior)
    archive_name = None
    if not args.noBuild:
        # Create tarball from workDir files
        archive_name = f'jobO.{uuid.uuid4().hex}.tar.gz'

        # Create temporary directory for tarball
        with tempfile.TemporaryDirectory() as tmpdir:
            archive_path = os.path.join(tmpdir, archive_name)

            # Create tar.gz archive with workDir files
            print(f"Creating tarball {archive_name} from {args.workDir}")
            with tarfile.open(archive_path, 'w:gz') as tar:
                for fname in os.listdir(args.workDir):
                    fpath = os.path.join(args.workDir, fname)
                    if os.path.isfile(fpath):
                        # Add file with just the filename (no path)
                        tar.add(fpath, arcname=fname)
                        print(f"  Added: {fname}")

            # Upload tarball to PanDA cache (must be done from the directory containing it)
            print(f"Uploading {archive_name} to PanDA cache")
            # Change to tmpdir so Client.putFile can find the file
            old_cwd = os.getcwd()
            os.chdir(tmpdir)
            status, out = Client.putFile(archive_name, False, useCacheSrv=False, reuseSandbox=True)
            os.chdir(old_cwd)

            if out.startswith("NewFileName:"):
                # Reusing existing sandbox
                archive_name = out.split(":")[-1]
                print(f"Reusing existing sandbox: {archive_name}")
            elif out != "True":
                print(f"Upload output: {out}")
                if status != 0:
                    print(f"ERROR: Failed to upload sandbox with status {status}")
                    return 1
            else:
                print(f"Successfully uploaded {archive_name}")

        # Add -a parameter to jobParameters
        params['jobParameters'].append({
            'type': 'constant',
            'value': f'-a {archive_name}'
        })

    # Parse and handle %RNDM=X pattern (convert to ${SEQNUMBER} template)
    rndm_offset = '0'
    processed_cmd = args.exec_cmd
    rndm_match = re.search(r'%RNDM(:|=)(\d+)', processed_cmd)
    if rndm_match:
        rndm_offset = rndm_match.group(2)
        # Replace %RNDM=X with ${SEQNUMBER}
        processed_cmd = re.sub(r'%RNDM(:|=)\d+', '${SEQNUMBER}', processed_cmd)
        # Add pseudo_input template parameter (after base params, before command)
        params['jobParameters'].append({
            'type': 'template',
            'param_type': 'pseudo_input',
            'value': '${SEQNUMBER}',
            'dataset': 'seq_number',
            'offset': rndm_offset,
            'hidden': True
        })

    # URL-encode the command (replace spaces with %20)
    encoded_cmd = processed_cmd.replace(' ', '%20')
    params['jobParameters'].extend([
        {
            'type': 'constant',
            'value': '-p "',
            'padding': False
        },
        {
            'type': 'constant',
            'value': encoded_cmd
        },
        {
            'type': 'constant',
            'value': '"'
        }
    ])

    # Submit task
    result = client.submit_task(params)

    print(f"Submission result: {result}")

    # Return appropriate exit code
    if result and result[0] == 0:
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
