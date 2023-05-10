# Steps to setup a campaign on the Open Science Grid


We have be focusing on OSG to run simulation campaigns, through login05.osgconnect.net (single point of access, no lab account needed, intended for accessibility for foreign users, and because at the time we started there was no official VOMS for EIC which was required for lab submit nodes). Login can be requested through the format OSG open pool account request process.

OSG typically has many times more free nodes than the combined JLab and BNL allocation to EIC. 

OSG does impose conditions on jobs, in particular short jobs (2 hours) and ideally self-contained jobs that don't talk to the generic internet (xrootd is ok).

OSG uses Htcondor:

Htcondor takes care of the S3 transfer of simulation products which greatly facilitates the job management compared to slurm.
Htcondor puts failed jobs in a hold state which greatly facilitates triaging failures and simply resubmitting if it was a transient (as is typical).
JLab and BNL access nodes to OSG are a bit problematic: JLab now has an access node that can also support the EIC VO (instead of us submitting jobs pretending to be GlueX). BNL had their setup messed up and jobs only got farmed to a single site at UCSD, which is likely not been fixed yet. BNL is also a messed up system of many individual interactive nodes and you have to know which one to go to to do any specific thing.

Job scripts, whether htcondor or slurm, are all starting jobs inside the eic-shell container on /cvmfs/singularity.opensciencegrid.org/, the same image that users see in eic-shell (though a pinned stable version, typically). Here are the job submission scripts:

https://github.com/eic/job_submission_condor: scripts/submit_csv.sh
https://github.com/eic/job_submission_slurm: scripts/submit.sh
Job submitters on OSG will want to git clone the first repo.

Here are the job scripts that run inside the container (installed inside the container, no need to clone):

https://github.com/eic/simulation_campaign_single: scripts/run.sh (see CI for examples)
https://github.com/eic/simulation_campaign_hepmc3: scripts/run.sh (see CI for examples)
These are different for historical reason but they do mostly the exact same thing. These job scripts assume input data is accessible and just leave output data where they produce it (no attempt to upload). That allows them to be used by slurm and condor alike. Modifications to these scripts are likely only needed when the actual underlying calling syntax of the reconstruction needs changes.

Because we target 2 hours per job and because that varies for different data sets, we run benchmarks on all data sets that we simulate:

https://github.com/eic/simulation_campaign_datasets, but that's a mirror of https://eicweb.phy.anl.gov/EIC/campaigns/datasets for CI reasons (takes a few 100 core hours to benchmark all the datasets, can't fit in github CI).
The data sets produce a simple csv file with info about that data sets: running time per event, number of events, etc. Then submit_csv.sh (for condor) takes that and submits it for a specific target job duration, ensuring disk space and memory request are appropriate.

When submitting 10k to 100k jobs, dealing with failing jobs has two options: don't care about failures, or look a them with a semi-automated approach. scripts/hold_release_and_review.sh looks at stdout, stderr, and condor log, greps for patterns, does automatic resubmit. It's useful to keep an eye on now failures so we can document and fix them. Most common error is failure to write to S3 at the end of a job, which just needs a resubmit (but does mean we ran the job for nothing).
