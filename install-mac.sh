#!/bin/bash

read -r -d '' SCRIPT_USAGE << EOM
USAGE:
    ./install-mac.sh -n GITHUB_NAME -e GITHUB_EMAIL [-d|--defaults] [-s|--support]

REQUIRED:
-n GITHUB_NAME ---- Set the github user name, e.g "Munjal Buda"
-e GITHUB_EMAIL --- Set the github email, e.g. "munjal@deepx.it"

OPTIONAL:
-d|--defaults ----- Set MAC defaults settings
-s|--support ------ Use this if the person is not a developer

EOM

export GITHUB_NAME=""
export GITHUB_EMAIL=""

export MAC_DEFAULT_SETTINGS="0"
export IS_DEVELOPER="1"

parse_cli()
{
    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -n|--github_name)
                shift
                GITHUB_NAME="$1"
                shift
                ;;
            -e|--github_email)
                shift
                GITHUB_EMAIL="$1"
                shift
                ;;
            -d|--defaults)
                MAC_DEFAULT_SETTINGS="1"
                shift
                ;;
            -s|--support)
                IS_DEVELOPER="1"
                shift
                ;;
            -h|--help)
                printf "\n%s\n\n" "$SCRIPT_USAGE"
                exit 1
                ;;
            *)
                printf "Unknown arg: (%s)" "$1"
                printf "\n%s\n\n" "$SCRIPT_USAGE"
                exit 1
                ;;
        esac
    done
    set -- "${POSITIONAL[@]}"

    if [ "$GITHUB_NAME" == "" ]; then printf "GITHUB_NAME is missing\n"; exit 1; fi
    if [ "$GITHUB_EMAIL" == "" ]; then printf "GITHUB_EMAIL is missing\n"; exit 1; fi
}

fancy_echo()
{
    printf "\n\n>> %s\n" "$@"
    printf "=====================================================\n"
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

parse_cli "$@"
set_hostname
enable_services

config()
{
    /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
}

if [ $MAC_DEFAULT_SETTINGS ];
then
    # Tap to click
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
    sudo defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    sudo defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    sudo defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

    # Display only active applications in dock
    defaults write com.apple.dock static-only -bool TRUE

    # Enable the recent items menu
    defaults write com.apple.dock persistent-others -array-add '{"tile-data" = {"list-type" = 1;}; "tile-type" = "recents-tile";}'

    # Autohide dock
    defaults write com.apple.dock showhidden -bool TRUE

    # Move the dock to the left
    defaults write com.apple.dock pinning -string left

    killall Dock
fi

fancy_echo "Installing oh-my-zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]
then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sed 's:env zsh -l::g' | sed 's:chsh -s .*$::g')"
fi

if [ $IS_DEVELOPER ];
then
    fancy_echo "Installing Homebrew ..."
    if ! command -v brew >/dev/null; then
        curl -fsS \
            'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

        config checkout $HOME/.zshrc

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
            name = $GITHUB_NAME
            email = $GITHUB_EMAIL
         " >> $HOME/.gitconfig

        fancy_echo "Generating & configuringssh keys"
        ssh-keygen -t rsa -b 4096 -C $GITHUB_EMAIL -N "" -f $HOME/.ssh/id_rsa
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
    	  $username: $GITHUB_EMAIL

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

    fancy_echo "Installing Rust"
    rustup-init -y # Installs the default toolchain
    echo "export PATH=$PATH:$HOME/.cargo/bin" >> ~/.zshrc
    source $HOME/.cargo/env
    rustup toolchain add nightly
    cargo +nightly install racer
    rustup component add rust-src
    rustup update
    echo "export RUST_SRC_PATH=$(rustc --print sysroot)/lib/rustlib/src/rust/src" >> ~/.zshrc

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
        curl -Lo "/Applications/Visual Studio Code.zip" https://update.code.visualstudio.com/1.31.1/darwin/stable
        tar -xf "/Applications/Visual Studio Code.zip"
    fi

    fancy_echo "Installing Docker"
    if [ ! -d "/Applications/Docker.app" ]
    then
        curl -Lo ~/Downloads/Docker.dmg  https://download.docker.com/mac/stable/Docker.dmg
        sudo hdiutil attach ~/Downloads/Docker.dmg
        sudo cp -R "/Volumes/Docker/Docker.app" /Applications
        sudo hdiutil unmount "/Volumes/Docker"
    fi
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

fancy_echo "Installing Google Chrome"
if [ ! -d "/Applications/googlechrome.app" ]
then
    curl -Lo ~/Downloads/googlechrome.app https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg
    sudo hdiutil attach ~/Downloads/googlechrome.app
    sudo cp -R "/Volumes/Google Chrome.app" /Applications
    sudo hdiutil unmount "/Volumes/Google Chrome"
fi

fancy_echo "Installing Google Drive"
if [ ! -d "/Applications/Google Drive File Stream.app" ]
then
    curl -Lo ~/Downloads/GoogleDriveFileStream.dmg https://dl.google.com/drive-file-stream/GoogleDriveFileStream.dmg
    hdiutil mount ~/Downloads/GoogleDriveFileStream.dmg
    sudo installer -pkg "/Volumes/Install Google Drive File Stream/GoogleDriveFileStream.pkg" -target "/dev/disk1s1"
    hdiutil unmount "/Volumes/Install Google Drive File Stream/"
fi
