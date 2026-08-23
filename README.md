# Abode DevOps CI/CD Capstone

An end-to-end CI/CD pipeline that builds, tests, and deploys a containerized web application whenever code is pushed to GitHub — using Jenkins, Docker, Ansible, and AWS EC2.

## Architecture

```
Developer
   |
   | git push
   ↓
GitHub Repository
   |
   | Webhook
   ↓
Jenkins Controller
   |
   ↓
Job 1 - BUILD  (checkout + docker build)
   |
   ↓
Job 2 - TEST   (docker run + curl + docker rm)   → runs on TEST-AGENT
   |
   ├── develop branch  → STOP
   |
   └── master branch   → Job 3 - PRODUCTION       → runs on PROD-AGENT
                              |
                              ↓
                        Docker + Apache
                              |
                              ↓
                        Web Application
```

## Infrastructure

Three AWS EC2 (Ubuntu 24.04) instances in `ap-southeast-2`:

| Instance     | Role                          | Jenkins Node |
|--------------|-------------------------------|--------------|
| `controller` | Jenkins Controller + Ansible  | Built-in     |
| `test-agent` | Runs Job 2 (test)             | label: `test`|
| `production` | Runs Job 3 (deploy)           | label: `prod`|

**Security group inbound rules:**

| Port | Purpose        |
|------|-----------------|
| 22   | SSH             |
| 80   | HTTP (app)      |
| 8080 | Jenkins UI      |
| 8081 | Jenkins agent   |

## Tech Stack

- **Source control:** Git, GitHub, GitHub Webhooks
- **CI/CD:** Jenkins (Controller + Agents), Jenkinsfile (Pipeline as Code)
- **Containerization:** Docker
- **Configuration management:** Ansible
- **Web server:** Apache (inside the container)
- **OS:** Ubuntu 24.04
- **Runtime:** Java 21, Python 3

## Repository Structure

```
.
├── index.html          # Application source (served by Apache)
├── Dockerfile           # Ubuntu 24.04 + Apache image definition
├── .dockerignore
├── Jenkinsfile           # 3-stage pipeline: BUILD → TEST → PRODUCTION
├── README.md
└── ansible/
    ├── inventory         # test/prod private IPs
    └── setup.yml         # provisions Git, Java 21, Python, Docker on agents
```

## Pipeline Stages

**1. BUILD** — checks out the source and builds a Docker image tagged with the Jenkins build number:
```bash
docker build -t abode-web:${BUILD_NUMBER} .
```

**2. TEST** (runs on `test-agent`) — spins up the image, verifies it responds, then tears it down:
```bash
docker run -d --name abode-test -p 8080:80 abode-web:${BUILD_NUMBER}
curl -f http://localhost:8080
docker rm -f abode-test
```

**3. PRODUCTION** (runs on `prod-agent`, `master` branch only) — deploys the built image:
```bash
docker rm -f abode-web || true
docker run -d --name abode-web -p 80:80 abode-web:${BUILD_NUMBER}
```

Production deployment is gated with:
```groovy
when {
    branch 'master'
}
```
so pushes to `develop` build and test but never reach production.

## Branch Strategy

| Branch    | Build | Test | Deploy to Production |
|-----------|:-----:|:----:|:---------------------:|
| `develop` | ✅    | ✅   | ❌ (stops after test) |
| `master`  | ✅    | ✅   | ✅                     |

## GitHub Webhook

Configured under **Settings → Webhooks**:

- **Payload URL:** `http://<JENKINS_PUBLIC_IP>:8080/github-webhook/`
- **Content type:** `application/json`
- **Events:** Just the `push` event
- **Jenkins trigger:** "GitHub hook trigger for GITScm polling"

Every push to `develop` or `master` automatically starts the pipeline — no manual "Build Now" required.

## Setup

### 1. Provision infrastructure
Launch three EC2 instances (controller, test-agent, production) and open the required security group ports (see table above).

### 2. Configure the controller
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git python3 openjdk-21-jdk ansible -y
sudo apt install jenkins -y
sudo systemctl enable --now jenkins
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### 3. Set up SSH access from controller to agents
```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub   # add to authorized_keys on test-agent & production
```

### 4. Provision the agents with Ansible
```bash
cd ~/capstone
ansible -i inventory agents -m ping
ansible-playbook -i inventory setup.yml
```

### 5. Add Jenkins agents
Create two nodes in Jenkins: `test-agent` (label `test`) and `prod-agent` (label `prod`).

### 6. Create the webhook
Add the webhook in GitHub pointing at the Jenkins controller, as described above.

### 7. Push and watch it deploy
```bash
git checkout develop
git add .
git commit -m "Update application"
git push origin develop     # builds + tests, stops before production

git checkout master
git merge develop
git push origin master      # builds + tests + deploys to production
```

## Verification

```bash
# On the production server
docker ps
curl http://localhost
```

Or visit `http://<PRODUCTION_PUBLIC_IP>` in a browser.

## Problems Encountered & Fixes

| Problem | Fix |
|---|---|
| `Permission denied (publickey)` when Controller SSH'd to agents | Added controller's public key to each agent's `~/.ssh/authorized_keys` |
| Jenkins couldn't run Docker commands | Added the `jenkins` user to the `docker` group and restarted Jenkins |
| Java version confusion across services | Standardized all servers on Java 21 (`openjdk-21-jdk`) |
| Deployments running on the wrong node | Introduced explicit agent labels (`test`, `prod`) and pinned each pipeline stage to the correct label |
| `develop` branch reaching production | Added a `when { branch 'master' }` guard on the production stage |
| Webhook not firing reliably | Verified via GitHub's **Recent Deliveries** tab and cross-checked against Jenkins **Build History** |

## Author

Sachin Rathod
