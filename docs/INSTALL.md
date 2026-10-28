# Install

Everything needed to run this service locally: Java 21, Maven, and a
container engine (Docker **or** Podman — pick one, don't mix).

After installing, confirm versions:

```
java -version   # should print 21.x
mvn -version    # should print Maven 3.9+
docker version || podman version
```

---

## macOS

Using [Homebrew](https://brew.sh):

```bash
brew install openjdk@21 maven
sudo ln -sfn /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk \
  /Library/Java/JavaVirtualMachines/openjdk-21.jdk
```

Then pick **one** container engine:

```bash
# Option A: Docker Desktop
brew install --cask docker
open -a Docker   # start it once so the daemon is running

# Option B: Podman
brew install podman podman-compose
podman machine init
podman machine start
```

If you went with Podman, also do the one-time Testcontainers setup in
["Podman + Testcontainers" below](#podman--testcontainers-mvn-test) — it's
needed for `make test` and `mvn test` to find the container engine.

---

## Linux

Package names vary by distro; examples below are for Debian/Ubuntu (`apt`)
and Fedora/RHEL (`dnf`).

**Java 21 + Maven:**

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install -y openjdk-21-jdk maven

# Fedora/RHEL
sudo dnf install -y java-21-openjdk-devel maven
```

**Container engine — pick one:**

```bash
# Option A: Docker Engine (see https://docs.docker.com/engine/install/
# for the current distro-specific steps; summary for Debian/Ubuntu):
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # log out/in afterwards
docker compose version           # confirms the compose plugin is present

# Option B: Podman
# Debian/Ubuntu
sudo apt install -y podman
pip install --user podman-compose
# Fedora/RHEL
sudo dnf install -y podman podman-compose
```

If you went with Podman, also do the one-time Testcontainers setup in
["Podman + Testcontainers" below](#podman--testcontainers-mvn-test).

---

## Windows

Recommended: **WSL2** with an Ubuntu distro, then follow the **Linux**
instructions above *inside* WSL2 for Java, Maven, and the container engine.
This keeps Make, shell scripts, and file paths identical across the whole
team instead of fighting PowerShell/CMD quoting differences.

```powershell
wsl --install -d Ubuntu
```

Then open the Ubuntu terminal and follow the Linux section above. `make`
is available via `sudo apt install -y make` if it isn't already present.

If you'd rather stay native on Windows instead of WSL2:

```powershell
winget install EclipseAdoptium.Temurin.21.JDK
winget install Apache.Maven
winget install Docker.DockerDesktop   # enable the WSL2 backend when prompted
winget install GnuWin32.Make          # or use Git Bash, which ships `make`
```

Podman on native Windows (outside WSL2) also works via `podman machine`,
but it runs its own small Linux VM to do so — if you're going to run a
Linux VM either way, WSL2 + Linux Podman/Docker (above) is simpler and is
what the rest of this doc assumes.

---

## Podman + Testcontainers (`mvn test`)

`make up`/`make build` work with plain Podman out of the box. `mvn test`
is different: Quarkus Dev Services use [Testcontainers](https://testcontainers.com)
under the hood, which by default looks for a Docker-compatible socket.
Point it at Podman's socket once per machine:

**macOS / Linux:**

```bash
export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || echo /run/user/$(id -u)/podman/podman.sock)"
export TESTCONTAINERS_RYUK_DISABLED=true
```

(`podman machine inspect` is macOS-only; on Linux the rootless socket path
on the right-hand side of `||` is used instead. Rootless Podman on Linux
needs the socket enabled once: `systemctl --user enable --now podman.socket`.)

Add those two `export` lines to your shell profile (`~/.zshrc`,
`~/.bashrc`) so they're set in every new terminal, not just this session.

`TESTCONTAINERS_RYUK_DISABLED=true` disables Testcontainers' cleanup
sidecar container ("Ryuk"), which doesn't work reliably with rootless
Podman. It just means test containers are cleaned up when Podman itself
garbage-collects stopped containers instead of immediately — harmless for
local dev.

With Docker, none of this is needed — skip this section entirely.

---

## Known harmless noise

`podman compose down` / `make down` / `make clean` print a handful of
`Error: no container with name or ID "service_xyz_1" found` lines when run
against a stack that's already stopped, or when the (profile-gated) `app`
container was never built. This is a quirk of `podman-compose` trying to
remove containers unconditionally; the command still exits `0` and nothing
is wrong.
