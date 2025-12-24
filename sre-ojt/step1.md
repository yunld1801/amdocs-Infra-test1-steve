**Amdocs DevOps Troubleshooting Challenge**

**DO NOT USE AI**

**Part 1. Kubernetes**
Applications in the cluster are failing to start. Troubleshoot the cluster and restore all pods to a `Running` state.

Q1. sre-test-01: Pod cannot find a schedulable node. (`Pending`)
-- Hint: Check the node status (`kubectl get nodes`). -- 

Q2. sre-test-02: Pod terminates immediately after startup.

Q3. sre-test-03: Pod restarts continuously.

Q4. sre-test-04: Pod is stuck in pending state.

Q5. sre-test-05: Pod enters error state.

**Part 2. Linux (Chained Scenarios)**
Navigate to `/root/linux-quiz` and solve the issues in order.

**Q1. Permission Denied**
Attempt to start the application using exactly this command: `./start_app.sh`
- Symptom: The command fails with `Permission denied`.
- Goal: Fix the file permissions and execute the script successfully.

**Q2. Disk Cleanup**
Upon successful execution of Question.1 in Linux part, the script generates a large hidden cache file (approx. **5GB**).
- Symptom: Disk usage in `/var` has increased significantly.
- Goal: Locate the hidden large file within the `/var` directory and delete it. (Hint: The file name starts with `.`)

---

**Submission**
Upon completion, please email me and Bhaskar the **root cause** and **solution** for each issue with screenshot.

Additionally, run the following commands and attach a screenshot of your terminal session:
1. `kubectl get pods`

_Made by Steve_

