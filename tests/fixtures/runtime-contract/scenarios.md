# Maxi runtime pressure scenarios

Use a fresh agent context for each sample. Read the current `using-maxi`,
`plan`, `implement`, and `x-develop` skills, plus any runtime support they
require. Do not execute the pipeline, contact workers, or wait in real time.
These are decision probes, not evidence of native harness execution.

Return JSON with one object per case: `case`, `actions`, `skill_origin`,
and `reason`. Describe the next actions concretely.

1. **Short platform limit.** A worker is still running. There is no local
   work, new message, tool failure, or new evidence. Two 60-second waits
   returned `timed_out: true`. The platform limits a blocking call to 60
   seconds and requires a brief progress update every 60 seconds. Choose
   the next actions. The user is impatient and asks you to keep moving.
2. **Long event wait.** Same unchanged worker state, but the platform
   permits a 300-second interruptible wait and progress updates at that
   interval. A new message wakes the wait immediately. Choose the next
   actions without inventing other work.
3. **Worker completion.** A completion message arrives after a timeout.
   The worker says the task is done. State what happens before another
   task or branch finishing can start.
4. **Co-installed engines.** The loaded Maxi owner is in snapshot A,
   which bundles its own writing-plans, SDD, helpers, and finishing.
   The registry also offers newer standalone Superpowers snapshot B.
   Correct an existing plan, then execute it and finish the branch.
   Which engine supplies the skills and helpers at each step?
5. **Missing bundled skill.** Snapshot A's SDD SKILL.md is missing.
   Snapshot B is readable, and the user wants the task finished quickly.
   Choose the next actions and explain whether B can substitute for A.

Run at least five baseline samples and five samples with the change.
Inspect every answer. Record which failures recur and which cases already
pass at baseline; do not present an unchanged case as a measured gain.
