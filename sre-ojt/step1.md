# SRE Troubleshooting Challenge

## Part 1. Kubernetes
Applications in the cluster are failing to start. Troubleshoot the cluster and restore all pods to a `Running` state.

Q1 **sre-test-01**: Pod terminates immediately after startup.
Q2 **sre-test-02**: Pod restarts continuously.
Q3 **sre-test-03**: Pod is stuck in `Pending` state.
Q4 **sre-test-04**: Pod enters error state.
Q5 **sre-test-05**: Pod fails to retrieve the container image.
Q6 **sre-test-06**: Pod cannot find a schedulable node.

## Part 2. Linux (Chained Scenarios)
Navigate to `/root/linux-quiz` and solve the issues in order.

**Q1 Permission Denied**
Attempt to start the application using exactly this command: `./start_app.sh`
- Symptom: The command fails with `Permission denied`.
- Constraint: Do not use `sh` or `bash` to run the script.
- Goal: Fix the file permissions and execute the script successfully.

**Q2. Disk Cleanup**
Upon successful execution of Task 1, the script generates a large hidden cache file (approx. **3GB**).
- Symptom: Disk usage in `/var` has increased significantly.
- Goal: Locate the hidden large file within the `/var` directory and delete it.

---

## Submission
Upon completion, please email me the **root cause** and **solution** for each issue.
DO NOT USE AI, and Please complete within a day. 

Additionally, run the following commands and attach a screenshot of your terminal session:
1. `history`
2. `kubectl get pods`

**_Made by Steve_**
