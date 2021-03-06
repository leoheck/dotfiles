#!/bin/sh

# Usage: ./install-mac.sh github_name github_gmail

github_name="$1"
github_email="$2"

fancy_echo()
{
    printf "\n\n>> %s\n" "$@"
}

set_hostname()
{
    fancy_echo "Setting hostname"
    sudo scutil --set ComputerName $USER
    sudo scutil --set LocalHostName $USER
    dscacheutil -flushcache
}

enable_services()
{
    fancy_echo "Enabling SSH service"
    sudo  systemsetup -f -setremotelogin on

    fancy_echo "Enabling Screen sharing"
    sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
        -activate -configure -access -off -restart -agent -privs -all -allowAccessFor -allUsers
}

set_hostname
enable_services

git_mod()
{
    /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
}

fancy_echo "Installing oh-my-zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]
then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

fancy_echo "Installing Homebrew ..."
if ! command -v brew >/dev/null; then
    curl -fsS \
        'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

    git_mod checkout $HOME/.zshrc

    echo >> $HOME/.zshrc
    echo '# Recommended by brew doctor' >> $HOME/.zshrc
    echo 'export PATH="/usr/local/bin:$PATH"' >> $HOME/.zshrc
    echo 'export PATH="/usr/local/sbin:$PATH"'>> $HOME/.zshrc

    export PATH="/usr/local/bin:$PATH"
    export PATH="/usr/local/sbin:$PATH"
fi

if [ ! -f "$HOME/.ssh/id_rsa" ]
then
    fancy_echo "Installing git keys"
    fancy_echo "Writing to $HOME/.gitconfig"
    echo "
    [user]
        name = $github_name
        email = $github_email
     " >> $HOME/.gitconfig

    fancy_echo "Generating & configuringssh keys"
    ssh-keygen -t rsa -b 4096 -C $github_email -N "" -f $HOME/.ssh/id_rsa
    eval "$(ssh-agent -s)"

    touch $HOME/.ssh/config
    echo "
    Host *
        AddKeysToAgent yes
        UseKeychain yes
        IdentityFile $HOME/.ssh/id_rsa" >> $HOME/.ssh/config

    ssh-add -K $HOME/.ssh/id_rsa

    fancy_echo "Please copy your ssh public keys to github"
    open https://help.github.com/en/articles/adding-a-new-ssh-key-to-your-github-account

    echo "
    [user]
	authors:
	  $username: $c

	email_addresses:
	  $username: $github_email

     " >> $HOME/.gitconfig
    echo > ~/.git-authors
fi

fancy_echo "Installing brew bundles..."
brew bundle

fancy_echo "Installing spacemacs"
if [ ! -d "$HOME/.emacs.d" ]
then
    git clone https://github.com/syl20bnr/spacemacs $HOME/.emacs.d
fi

fancy_echo "Installing asdf"
if [ ! -d "$HOME/.asdf" ]
then
    git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf
    cd $HOME/.asdf
    git checkout "$(git describe --abbrev=0 --tags)"
fi

. $HOME/.asdf/asdf.sh
. $HOME/.asdf/completions/asdf.bash

find_latest_asdf() {
    asdf list-all "$1" | grep -v - | tail -1 | sed -e 's/^ *//'
}
asdf_plugin_present() {
    $(asdf plugin-list | grep "$1" > /dev/null)
    return $?
}

fancy_echo "Adding asdf plugins"
asdf_plugin_present elixir || asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf_plugin_present erlang || asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf_plugin_present nodejs || asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git

install_asdf_plugin()
{
    plugin_version=$(find_latest_asdf $1)
    fancy_echo "Installing $1 $plugin_version"
    asdf install $1 $plugin_version
    asdf global $1 $plugin_version
}

fancy_echo "Installing asdf plugins"
export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac"
install_asdf_plugin erlang
install_asdf_plugin elixir

fancy_echo "Installing Visual Studio Code"
if [ ! -d "/Applications/Visual Studio Code.app" ]
then
    curl -Lo /Applications/Visual\ Studio\ Code.zip https://update.code.visualstudio.com/1.31.1/darwin/stable
    tar -xf /Applications/Visual\ Studio\ Code.zip
fi

fancy_echo "Installing Docker"
if [ ! -d "/Applications/Docker.app" ]
then
    curl -Lo ~/Downloads/Docker.dmg  https://download.docker.com/mac/stable/Docker.dmg
    sudo hdiutil attach  -mountpoint <path-to-desired-mountpoint> ~/Downloads/Docker.dmg
    sudo cp -R "/Volumes/Docker/Docker.app" /Applications
    sudo hdiutil unmount "/Volumes/Docker"
fi

fancy_echo "Installing Google Chat"
if [ ! -d "/Applications/Chat.app" ]
then
    curl -Lo ~/Downloads/InstallHangoutsChat.dmg https://dl.google.com/chat/latest/InstallHangoutsChat.dmg
    sudo hdiutil attach ~/Downloads/InstallHangoutsChat.dmg
    sudo cp -R "/Volumes/Install Hangouts Chat/Chat.app" /Applications
    sudo hdiutil unmount "/Volumes/Install Hangouts Chat"
fi

fancy_echo "Installing GPG Suite"
if [ ! -d "/Applications/GPG Keychain.app" ]
then
    curl -Lo ~/Downloads/GPG_Suite-2018.5.dmg https://releases.gpgtools.org/GPG_Suite-2018.5.dmg
    sudo hdiutil attach ~/Downloads/GPG_Suite-2018.5.dmg
    sudo cp -R "/Volumes/GPG Suite/Install.app" /Applications
    sudo hdiutil unmount "/Volumes/GPG Suite"
fi
