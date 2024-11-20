# Instructions for Running a Simulation Campaign on the Open Science Grid


## 1 Getting an account
Create an account at https://www.ci-connect.net/.
Once logged in, request for membership of https://www.ci-connect.net/groups/root.collab and https://www.ci-connect.net/groups/root.collab.ePIC. 
Once your account is approved, you can setup a private and public key pair after clicking on Edit Profile. Store the public key on the ci-connect account and private key in your machine. Then you can ssh to login.collab.ci-connect.net.

### 2 Restrictions
OSG does impose conditions on jobs, in particular short jobs (2 hours) and ideally self-contained jobs that don't talk to the generic internet (xrootd is ok). 

### 3 HTCondor
OSG uses Htcondor for job submissions. Htcondor takes care of the S3 transfer of simulation products which greatly facilitates the job management compared to slurm. Htcondor puts failed jobs in a hold state which greatly facilitates triaging failures and simply resubmitting if it was a transient (as is typical).

### 4 Setting up campaign 
To set up the running environment (cloning [this repository](https://github.com/eic/job_submission_condor) and setting up the secret access key), ask the production WG for help in the sim-prod mattermost channel.  

### 5 Running a campaign
The relevant submission script is:
https://github.com/eic/job_submission_condor: scripts/submit_csv.sh

It starts jobs inside the eic-shell container on /cvmfs/singularity.opensciencegrid.org/, the same image that users see in eic-shell (though a pinned stable version, typically).

Here are the job scripts that run inside the container (installed inside the container, no need to clone):
https://github.com/eic/simulation_campaign_single: scripts/run.sh (see CI for examples)
https://github.com/eic/simulation_campaign_hepmc3: scripts/run.sh (see CI for examples)
These are different for historical reason but they do mostly the exact same thing. These job scripts assume input data is accessible and just leave output data where they produce it (no attempt to upload). That allows them to be used by slurm and condor alike. Modifications to these scripts are likely only needed when the actual underlying calling syntax of the reconstruction needs changes.

Because we target 2 hours per job and because that varies for different data sets, we run benchmarks on all data sets that we simulate:
https://github.com/eic/simulation_campaign_datasets, but that's a mirror of https://eicweb.phy.anl.gov/EIC/campaigns/datasets for CI reasons (takes a few 100 core hours to benchmark all the datasets, can't fit in github CI). The data sets produce a simple csv file with info about that data sets: running time per event, number of events, etc. Then submit_csv.sh (for condor) takes that and submits it for a specific target job duration, ensuring disk space and memory request are appropriate.

### 6 Monitoring Failures
When submitting 10k to 100k jobs, dealing with failing jobs has two options: don't care about failures, or look a them with a semi-automated approach. scripts/hold_release_and_review.sh looks at stdout, stderr, and condor log, greps for patterns, does automatic resubmit. It's useful to keep an eye on now failures so we can document and fix them. Most common error is failure to write to S3 at the end of a job, which just needs a resubmit (but does mean we ran the job for nothing).