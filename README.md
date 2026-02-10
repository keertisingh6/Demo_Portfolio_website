# Demo_Portfolio_website
# Part 1 — Get the code (Fork & clone)

### Step 1.1: Fork the repository

1. Open the project repo on GitHub.
2. Click **Fork** and create a fork under your GitHub account.

### Step 1.2: Clone your fork

Replace `YOUR_GITHUB_USERNAME` with your GitHub username:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/deployment_demo.git
cd deployment_demo
```

(If you use SSH: `git clone git@github.com:YOUR_GITHUB_USERNAME/deployment_demo.git`)

---
# Part 2 — Set your Docker Hub username

You will use **one Docker Hub username** everywhere: in `docker-compose.yml`, when building/pushing, and on EC2.

- If you don’t have a Docker Hub account: go to [hub.docker.com](https://hub.docker.com) and sign up.
- Choose a **username** (e.g. `johndoe`). We’ll call it `YOUR_DOCKERHUB_USERNAME` in the steps below.

### Step 2.1: Edit docker-compose.yml

Open `docker-compose.yml` and set the image to **your** Docker Hub username:

```yaml
services:
  app:
    image: YOUR_DOCKERHUB_USERNAME/deployment-demo:latest
    container_name: deployment-demo
    ports:
      - "13000:80"
    restart: unless-stopped
```

Replace `YOUR_DOCKERHUB_USERNAME` with your actual Docker Hub username (e.g. `johndoe/deployment-demo:latest`). Save the file.

---
# Part 3 — Build and push image to Docker Hub

Do this on **your laptop** (or any machine where you develop). The image will be **public** on Docker Hub so EC2 can pull it.

### Step 3.1: Install Docker

- Install [Docker Desktop](https://www.docker.com/products/docker-desktop) (or Docker Engine + Docker Compose plugin).
- Ensure `docker` and `docker buildx` work:

```bash
docker --version
docker buildx version
```
### Step 3.2: Log in to Docker Hub

```bash
docker login
```

- Enter your **Docker Hub username**.
- Enter your **password** (or access token if you use 2FA).  
You only need to do this once per machine (or until you log out).

### Step 3.3: Build and push the image

From the **project root** (where `Dockerfile` and `docker-compose.yml` are):

```bash
./scripts/build-and-push.sh YOUR_DOCKERHUB_USERNAME
```

Replace `YOUR_DOCKERHUB_USERNAME` with your Docker Hub username (same as in `docker-compose.yml`).

**If you already set the image in docker-compose.yml**, you can run:

```bash
./scripts/build-and-push.sh
```

The script will:

- Build the image for **linux/amd64** and **linux/arm64** (works on x86 and ARM EC2).
- Push to `YOUR_DOCKERHUB_USERNAME/deployment-demo:latest`.

Pushing can take a few minutes. When it finishes, your image is on Docker Hub and EC2 can pull it.


---
# Part 4 — AWS EC2: Create the instance

### Step 4.1: Launch an EC2 instance

1. Go to **AWS Console → EC2 → Launch Instance**.
2. Use workshop-friendly settings:
   - **Name:** e.g. `workshop-demo`
   - **AMI:** **Ubuntu Server 22.04 LTS**
   - **Instance type:** `t2.micro` or `t3.micro`
   - **Key pair:** Create a new key pair or select an existing one (you need the `.pem` file to SSH).
   - **Network:** Default VPC.
   - **Auto-assign public IP:** Enable.

3. In **Network settings**, we’ll add a security group in the next part. For now you can leave defaults and edit the security group after launch, or go to Step 5.2 below before launching.

4. **Launch** the instance.

### Step 4.2: Security group (required for the app to be reachable)

If you didn’t configure the security group during launch:

1. EC2 → **Security Groups** → select the security group attached to your instance (or create one and attach it).
2. **Edit inbound rules** and ensure you have:

| Type       | Protocol | Port  | Source        |
|-----------|----------|-------|---------------|
| SSH       | TCP      | 22    | My IP or your IP (`x.x.x.x/32`) |
| Custom TCP| TCP      | 13000 | `0.0.0.0/0`   |

3. Save the rules.

- **Port 22:** So you can SSH into the instance.
- **Port 13000:** So the browser can reach the app. The app listens on **80 inside the container**; we map **host 13000 → container 80** in `docker-compose.yml`. If 13000 is not open, the app will run but won’t load in the browser.

---

# Part 5 — Connect to EC2

### Step 5.1: SSH into the instance

From your laptop (same directory as your `.pem` key):

#### Step 5.1.1: Give the appropriate permissions to file 
```bash MacOS
chmod 400 /path/to/your-key.pem
```
For Windows in CMD
```bash Windows
icacls "your-key.pem" /inheritance:r
icacls "your-key.pem" /grant:r "%username%":F
```

#### Step 5.1.2: Connect to your instance
```bash
ssh -i /path/to/your-key.pem ubuntu@EC2_PUBLIC_IP
```

Replace:

- `/path/to/your-key.pem` with the path to your key file.
- `EC2_PUBLIC_IP` with the instance’s **Public IPv4 address** (from EC2 console).

If you use **Amazon Linux** instead of Ubuntu, the user is `ec2-user`:

```bash
ssh -i /path/to/your-key.pem ec2-user@EC2_PUBLIC_IP
```

You should see a prompt like:

```bash
ubuntu@ip-172-31-xx-xx:~$
```

---
# Part 6 — Install prerequisites on EC2 (one-time)

Docker and the Docker Compose plugin need to be installed once on the instance.

### Step 6.1: Create the install script

Either copy the script from your repo to the server, or on the server run:

```bash
cat << 'EOF' > install_prerequisites.sh
#!/bin/bash
set -e

echo "🔹 Updating system"
sudo apt update -y
sudo apt upgrade -y

echo "🔹 Installing basic utilities"
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "🔹 Installing Docker"
curl -fsSL https://get.docker.com | sudo bash

echo "🔹 Enabling Docker"
sudo systemctl start docker
sudo systemctl enable docker

echo "🔹 Adding user to docker group"
sudo usermod -aG docker $USER

echo "🔹 Installing Docker Compose (plugin)"
COMPOSE_VERSION="v2.25.0"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  COMPOSE_ARCH="x86_64" ;;
  aarch64|arm64) COMPOSE_ARCH="aarch64" ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "✅ Installation complete"
echo "⚠️  Logout and login again for docker permissions to apply"
EOF
```

### Step 6.2: Run the script

```bash
chmod +x install_prerequisites.sh
./install_prerequisites.sh
```

### Step 6.3: Log out and log back in (required)

Docker group permissions apply only after a new login:

```bash
exit
```

Then SSH in again:

```bash
ssh -i /path/to/your-key.pem ubuntu@EC2_PUBLIC_IP
```

Verify Docker and Compose:

```bash
docker --version
docker compose version
```

---

# Part 7 — Deploy the app on EC2

### Step 7.1: Create app directory

```bash
mkdir -p deployment-demo
cd deployment-demo
```

### Step 7.2: Create docker-compose.yml on the server

Create `docker-compose.yml` **with your Docker Hub username**:

```bash
cat << 'EOF' > docker-compose.yml
services:
  app:
    image: YOUR_DOCKERHUB_USERNAME/deployment-demo:latest
    container_name: deployment-demo
    ports:
      - "13000:80"
    restart: unless-stopped
EOF
```

**Important:** Replace `YOUR_DOCKERHUB_USERNAME` with your actual Docker Hub username (same one you used in Part 4).

Or copy the file from your laptop:

```bash
# From your laptop (run in project root):
scp -i /path/to/your-key.pem docker-compose.yml ubuntu@EC2_PUBLIC_IP:~/deployment-demo/
```

Make sure the `image:` line in that file uses your username.

### Step 7.3: (Optional) Create deploy.sh on the server

For easy redeploys (pull + restart):

```bash
cat << 'EOF' > deploy.sh
#!/bin/bash
set -e

echo "🔹 Pulling latest Docker image"
docker compose pull

echo "🔹 Stopping old containers (if any)"
docker compose down || true

echo "🔹 Starting application"
docker compose up -d

echo "✅ Application deployed"
docker compose ps
EOF

chmod +x deploy.sh
```

### Step 7.4: Pull the image and start the app

**Option A — Using deploy.sh:**

```bash
./deploy.sh
```

**Option B — Manual commands:**

```bash
docker compose pull
docker compose up -d
```

### Step 7.5: Check that the container is running

```bash
docker compose ps
```

You should see something like:

```
NAME                IMAGE                                  STATUS    PORTS
deployment-demo     YOUR_DOCKERHUB_USERNAME/deployment-demo:latest   Up   0.0.0.0:13000->80/tcp
```

---

# Part 8 — Access the application

In your browser open:

```
http://EC2_PUBLIC_IP:13000
```

Replace `EC2_PUBLIC_IP` with your instance’s public IP. You should see the same Workshop Lounge app (counter, moods, messages, click game).

---

# Part 9 — Workshop concepts (teaching notes)

### Security group

- **Security groups** are AWS firewalls. If port **13000** is not allowed in the security group, the app will run in Docker but the browser cannot reach it.

### EC2 and Docker

- EC2 **does not build** the image. It only **pulls** the image from Docker Hub and **runs** it. Build and push happen on your laptop (or in CI).

### Port mapping

- **Browser** → **EC2:13000** → **Container:80**   
  `13000` is the host port we expose; `80` is the port the app listens on inside the container.

### End-to-end flow

| Step        | Where      | What you do                          |
|------------|------------|--------------------------------------|
| Build      | Your laptop| `./scripts/build-and-push.sh USER`   |
| Registry   | Docker Hub | Image is stored (public)             |
| Run        | EC2        | `docker compose pull` + `up -d`       |
| Redeploy   | EC2        | `./deploy.sh` or `pull` + `up -d`     |

---

# Part 10 — Debug checklist

| Symptom                 | What to check |
|-------------------------|---------------|
| Site doesn’t load       | Security group: inbound rule for **TCP 13000** from `0.0.0.0/0` (or your IP). |
| “Permission denied” docker | Log out and log back in after running `install_prerequisites.sh`. |
| Container exits         | `docker logs deployment-demo` |
| “no matching manifest”   | Image was built only for one architecture. Re-run `./scripts/build-and-push.sh` (builds amd64 + arm64). |
| Compose not found       | Install Docker Compose plugin (Part 7) and use `docker compose` (with a space). |

---

# Part 11 — Cleanup (optional)

On EC2, to stop and remove the app and free space:

```bash
cd ~/deployment-demo
docker compose down
docker system prune -af
```

You can terminate the EC2 instance from the AWS Console when you’re done.

---
