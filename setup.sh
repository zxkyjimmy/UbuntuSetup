#!/usr/bin/bash
set -euo pipefail

function step(){
  echo "$(tput setaf 10)$1$(tput sgr0)"
}

Port="${1:-22}"

step "Set locale"
sudo locale-gen en_US.UTF-8
sudo locale-gen zh_TW.UTF-8
export LC_ALL=en_US.UTF-8

step "Update all packages"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

step "Stop unattended upgrade"
sudo sed -E 's;APT::Periodic::Unattended-Upgrade "1"\;;APT::Periodic::Unattended-Upgrade "0"\;;g' -i /etc/apt/apt.conf.d/20auto-upgrades

step "Configuring git"
git config --global user.name "Yen-Chi Chen"
git config --global user.email "zxkyjimmy@gmail.com"
git config --global pull.rebase false

step "Get useful commands"
sudo apt update
sudo apt install -y git curl zsh wget htop vim tree openssh-server lm-sensors \
                    cmake tmux python3-pip python-is-python3 clang clang-tools \
                    python3-packaging # To build from source of TensorFlow

step "Get YAPF"
sudo apt install -y python3-yapf
[ -d ${HOME}/.config/yapf ] || mkdir -p ${HOME}/.config/yapf
cat <<EOF | tee ${HOME}/.config/yapf/style
[style]
based_on_style = google
EOF

step "Pip install protobuf"
sudo pip install -U protobuf

step "Set ssh port&key"
sudo sed -E 's;#?(Port ).*;\1'"$Port"';g' -i /etc/ssh/sshd_config
sudo service ssh restart
[ -d ~/.ssh ] || mkdir ~/.ssh
ssh-keygen -b 4096 -t rsa -f ~/.ssh/id_rsa -q -N "" <<< y
echo "" # newline

step "Get Font"
FONTBASE=https://github.com/ryanoasis/nerd-fonts/raw/5454877c01e5efb4b902151655f75d950678dc34/patched-fonts
wget $FONTBASE/SourceCodePro/Regular/complete/Sauce%20Code%20Pro%20Nerd%20Font%20Complete%20Mono.ttf
wget $FONTBASE/SourceCodePro/Regular/complete/Sauce%20Code%20Pro%20Nerd%20Font%20Complete.ttf
wget $FONTBASE/CascadiaCode/Regular/complete/Caskaydia%20Cove%20Nerd%20Font%20Complete%20Mono%20Regular.otf
wget $FONTBASE/CascadiaCode/Regular/complete/Caskaydia%20Cove%20Nerd%20Font%20Complete%20Regular.otf
mkdir -p ~/.local/share/fonts
cp *.ttf ~/.local/share/fonts
cp *.otf ~/.local/share/fonts
sudo fc-cache -f -v

step "Tweak theme and terminal"
PROFILE_ID=$( gsettings get org.gnome.Terminal.ProfilesList default | xargs echo )
dconf write /org/gnome/terminal/legacy/profiles:/:${PROFILE_ID}/use-system-font false
dconf write /org/gnome/terminal/legacy/profiles:/:${PROFILE_ID}/font "'SauceCodePro Nerd Font Mono Regular 14'"

step "Get oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

step "Get Oh my tmux"
git clone https://github.com/gpakosz/.tmux.git ${HOME}/.tmux
ln -s -f ${HOME}/.tmux/.tmux.conf ${HOME}

step "Copy environment"
sudo chsh -s /usr/bin/zsh ${USER}
cp .p10k.zsh .zshrc .tmux.conf.local ${HOME}/

step "Set Time Zone"
sudo timedatectl set-timezone Asia/Taipei

step "Get conda"
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -p $HOME/miniconda
eval "$(${HOME}/miniconda/bin/conda shell.bash hook)"
conda init zsh
conda config --set auto_activate_base false

step "Get CUDA"
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
sudo apt update
#sudo apt install -y cuda-drivers
#sudo apt install -y cuda-11-8
sudo apt install -y cuda libcudnn8 libcudnn8-dev
sudo sed -E 's;PATH="?(.+)";PATH="/usr/local/cuda/bin:\1";g' -i /etc/environment

step "Install Bazel"
sudo apt install -y apt-transport-https curl gnupg
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel-archive-keyring.gpg
sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
sudo apt update
sudo apt install -y bazel

step "Install Podman"
sudo apt update
sudo apt upgrade -y
sudo apt install -y podman
sudo sed -E 's;# unqualified-search-registries = \["example.com"\];unqualified-search-registries = \["docker.io"\];1' -i /etc/containers/registries.conf

step "Install nvidia-container-runtime"
curl -fsSL https://nvidia.github.io/nvidia-container-runtime/gpgkey | \
  gpg --dearmor > nvidia-container-runtime.gpg
sudo mv nvidia-container-runtime.gpg /etc/apt/trusted.gpg.d/
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list
sudo apt update
sudo apt install -y nvidia-container-runtime
sudo sed -i 's/^#no-cgroups = false/no-cgroups = true/;' /etc/nvidia-container-runtime/config.toml
sudo mkdir -p /usr/share/containers/oci/hooks.d
cat <<EOF | sudo tee /usr/share/containers/oci/hooks.d/oci-nvidia-hook.json
{
    "version": "1.0.0",
    "hook": {
        "path": "/usr/bin/nvidia-container-toolkit",
        "args": ["nvidia-container-toolkit", "prestart"],
        "env": [
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ]
    },
    "when": {
        "always": true,
        "commands": [".*"]
    },
    "stages": ["prestart"]
}
EOF

step "stop cups-browsed"
sudo systemctl stop cups-browsed.service
sudo systemctl disable cups-browsed.service

step "clean up"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt autoclean
