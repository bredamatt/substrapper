# substrapper
Used for optimised builds of substrate runtimes

## Building A Substrate Node in AWS

The guide below is intended for creating a workspace for a developer to work in
Substrate code with fast incremental build times, to make it easier to iterate 
on code. As a result, compiler optimizations are dropped in the interest of
speed of build. With these optimizations, the node won't run as fast, so depending
on how heavy the code is and the nature of the transactions, the compiler options
may not result in a binary that will be able to keep up with 6-second block times.
So tweak this to fit your particular use case.

### Recommended instance configuration

On AWS you can compare various instance configurations here:
* https://aws.amazon.com/ec2/instance-explorer/
* https://calculator.aws/#/addService/EC2?nc2=h_ql_pr_calc

To actually get set up on AWS you will need an account, and can then get started 
setting up an instance. In general, I look for the regions where instances are
cheapest, e.g., us-east-1 or us-east-2.

The configuration I selected was:
    m6g.4xlarge, 16 cores, 64GB RAM, 64GB gp3 SSD ($0.616 USD per Hour)
        64-bit ARM architecture with Amazon Linux

I also tried the following, which are slower or significantly more expensive:
    t4g.2xlarge, 8 cores, 32GB RAM, 64GB gp3 SSD ($0.2688 USD per Hour)
    a1.metal
    mac2.metal -- this was around the same speed, but required a dedicated host and was more expensive

### Setting up the instance

When creating an instance you will need to create a keypair, and keep the private
key on your local machine (as part of the setup you download the private key to 
your machine). You will need to put the key into your `~/.ssh` directory. You should
also add the following to your `~/.ssh/config` file:

    Host RustEC2
        User ec2-user
        HostName [PUBLIC IP ADDRESS OF YOUR INSTANCE]
        IdentityFile ~/.ssh/[YOUR_KEY].pem

Now you can connect to the instance via ssh:

    ssh -i ~/.ssh/[YOUR_KEY].pem ec2-user@[IP_ADDRESS]

### Software installations

#### Update the system and install a compiler chain:
    sudo yum update
    sudo yum groupinstall "Development Tools"

For the following, if you are going to use mold or lld then you will also wind up building
a new, recent version of llvm and clang below, so technically you don't need them here:

    sudo yum install openssl-devel llvm clang libstdc++10-devel.aarch64

If you want to compile inside a RAMdisk, you will need a pretty big /dev/shm tmpfs partition.
We would do this to increase I/O performance, but it isn't clear if it helps.
When looking at frameless-node-template, I have seen 4G after release compilation, and if you
also compile in debug I've seen it at 19G. If you need to make /dev/shm bigger you can do it as 
follows - e.g., to make it 24G:

    sudo mount -o remount,size=24G /dev/shm

To validate the new size:

    df -h /dev/shm

    #    Filesystem      Size  Used Avail Use% Mounted on
    #    tmpfs           2.0G     0  2.0G   0% /dev/shm

    free -h

    #                total        used        free      shared  buff/cache   available
    #  Mem:            30G        196M        2.5G         23G         27G        6.4G
    #  Swap:            0B          0B          0B

Next, you also need a recent cmake to compile substrate, not yet available in Amazon package repo.
This will take a while to compile ( ~1 hour). You can install rust etc. below in the meantime.
We will build in the /dev/shm ramdisk to try to improve I/O performance; unclear if this helps.

    cd /dev/shm
    wget https://cmake.org/files/v3.23/cmake-3.23.2.tar.gz
    tar -xvzf cmake-3.23.2.tar.gz
    cd cmake-3.23.2
    ./bootstrap
    gmake
    sudo make install
    cd ..
    rm -Rf cmake-3.23.2

Install rust etc, following the instructions here: https://github.com/substrate-developer-hub/substrate-node-template/blob/main/docs/rust-setup.md

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source ~/.cargo/env
    rustup default stable
    rustup update
    rustup update nightly
    rustup target add wasm32-unknown-unknown --toolchain nightly

#### Optional: If you want to use mold as the linker:

First you will need to compile a recent version of clang/llvm/lld. This will take hours.

    cd /dev/shm
    git clone --branch llvmorg-14.0.6 --depth 1 https://github.com/llvm/llvm-project
    cd llvm-project
    mkdir build
    cd build

    cmake -DLLVM_ENABLE_PROJECTS=clang -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" ../llvm
    nohup make &
    sudo make install

    cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS=lld -DCMAKE_INSTALL_PREFIX=/usr/local ../llvm
    nohup make &
    sudo make install

Now compile mold -- this is relatively fast.

    cd /dev/shm
    git clone https://github.com/rui314/mold.git
    cd mold
    git checkout v1.3.1
    # Below, the gold linker should be usable here; if not you can try some otehrs
    make -j$(nproc) CXX=clang++ LDFLAGS="-fuse-ld=gold"  
    sudo make install

### Compiler optimization

Create a .cargo/config.toml in your home directory with the following. If you're not using mold and you 
didn't compile clang above, you don't need the first build target configurations. The profile.fast configuration
speeds up your build regardless of what linker you use.

    [target.aarch64-unknown-linux-gnu]
    rustflags = ["-C", "linker=clang", "-C", "link-arg=-fuse-ld=/usr/local/bin/mold"]

    [target.wasm32-unknown-unknown]
    rustflags = ["-C", "linker=clang", "-C", "link-arg=-fuse-ld=lld"]                                             

    [profile.fast]
    inherits = "release"
    opt-level = 0
    lto = "off"
    incremental = true
    codegen-units = 256

    # [term]
    # verbose = true

### Workspace setup

If you want to check out permissioned repos from GitHub, you will need your private key for GitHub 
on the remote server:

    scp -i ~/.ssh/[YOUR_AWS_KEY].pem ~/.ssh/[YOUR_GITHUB_PRIVATE_KEY] ec2-user@[IP_ADDRESS]:/home/ec2-user
    ssh -i ~/.ssh/[YOUR_AWS_KEY].pem ec2-user@[IP_ADDRESS]
    mv [YOUR_GITHUB_PRIVATE_KEY] .ssh/
    chmod 400 [YOUR_GITHUB_PRIVATE_KEY]
    
Now you can check out a workspace that is password-protected for your account on GitHub.

    cd ..
    git clone git@github.com:[ORG]/[REPO].git

or if your GitHub private key is not named id_rsa:

    GIT_SSH_COMMAND="ssh -i ~/.ssh/[YOUR_GITHUB_PRIVATE_KEY]"  git clone git@github.com:[ORG]/[REPO].git

With this second git clone command, you will be asked for the passphrase for the key.

If you want to compile on the RAMdisk, check out another copy there, which you will edit and then later 
push your changes back to the source repo on disk. (Note that every time you restart your instance whatever
is on the RAMdisk disappears, so you have to make sure you push before you stop the instance when you're 
not using it.)

    cd /dev/shm
    git clone /home/ec2-user/[REPO]

Now you can try compiling inside the repo using the fast profile set up above:

    cargo build --profile=fast
    cargo run --profile=fast -- --dev

### Remote editing with Visual Studio Code running locally

Set up the VSCode remote development extensions. See the following:

* https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack
* https://code.visualstudio.com/docs/remote/troubleshooting

With this set up you will be able to click the icon in the left bar, that will show you the remote
hosts configured in your `~/.ssh/config` file that you can connect to. Note that you will need to 
change the IP address in your .ssh/config file every time you restart your AWS instance.

### Remote editing with Visual Studio Code running remotely

You may find that running Visual Studio Code locally with Rust analyzer is too slow or too taxing
on your machine. There is another option: You can use Visual Studio Code for the web. See:

* https://code.visualstudio.com/docs/editor/vscode-web

You will need to have your code on GitHub in order to do this. Visual Studio Code for the web will
check the code out from GitHub to its local workspace and allow you to edit there and push back
to GitHub. You will then need to pull from GitHub to your AWS instance to fetch your latest edits
so that you can build them. Note that Visual Studio Code for the web is set up with some features
for Rust such that you can navigate Rust code with Outline/Go to Symbol and Symbol Search; there is
also text-basd completion, code syntax colorization, and bracket pair colorization.
