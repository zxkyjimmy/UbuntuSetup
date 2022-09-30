#!/usr/bin/bash
set -euo pipefail

function step(){
  echo "$(tput setaf 10)$1$(tput sgr0)"
}

step "Set locale"
export LC_ALL=en_US.UTF-8

step "Get YAPF"
[ -d ${HOME}/.config/yapf ] || mkdir -p ${HOME}/.config/yapf
cat <<EOF | tee ${HOME}/.config/yapf/style
[style]
based_on_style = yapf
EOF

step "Set ssh port&key"
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
fc-cache -f -v

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
chsh -s /usr/bin/zsh ${USER}
cp .p10k.zsh .zshrc .tmux.conf.local ${HOME}/

step "Get conda"
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -p $HOME/miniconda
eval "$(${HOME}/miniconda/bin/conda shell.bash hook)"
conda init zsh
conda init bash
conda config --set auto_activate_base false
