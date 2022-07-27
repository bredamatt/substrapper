# Bootstrapping local parachains in (local) Kubernetes clusters

## Deps

- docker
- kind
- kubectl
- zombienet
- ...An internet connection
- ...Enough hardware resources on your machine 

## Installation of deps

This is based on the OS. I use an Old and rusty Macbook Pro from 2013. I added Ubuntu instructions below.

### For Ubuntu

#### Docker
```shell
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Get Docker GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Setup repo
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# install
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# test
sudo docker run hello-world
```

#### Kind
```shell
sudo curl -L “https://kind.sigs.k8s.io/dl/v0.8.1/kind-$(uname)-amd64” -o /usr/local/bin/kind
sudo chmod +x /usr/local/bin/kind

# Check it works
kind get clusters
```

#### Kubectl
```shell
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"


# validate
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# install (sudo based)
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

### If no sudo
# chmod +x kubectl
# mkdir -p ~/.local/bin
# mv ./kubectl ~/.local/bin/kubectl

# check if it works
kubectl version --client
```