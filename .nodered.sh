#!/bin/bash
#
# Copyright 2016,2020 JS Foundation and other contributors, https://js.foundation/
# Copyright 2015,2016 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Node-RED Installer for DEB based systems

umask 0022
tgta=12.20.1   # need armv6l latest from https://unofficial-builds.nodejs.org/download/release/
tgtl=12.16.3   # need x86 latest from https://unofficial-builds.nodejs.org/download/release/

usage() {
  cat << EOL
Usage: $0 [options]

Options:
  --help            display this help and exits
  --confirm-root    install as root without asking confirmation
  --confirm-install confirm installation without asking confirmation
  --confirm-pi      confirm installation of PI specific nodes without asking confirmation
  --nodered-version if not set, the latest version is used - e.g. --nodered-version="1.1.3"
EOL
}

if [ $# -gt 0 ]; then
  # Parsing parameters
  while (( "$#" )); do
    case "$1" in
      --help)
        usage && exit 0
        shift
        ;;
      --confirm-root)
        CONFIRM_ROOT="y"
        shift
        ;;
      --confirm-install)
        CONFIRM_INSTALL="y"
        shift
        ;;
      --skip-pi)
        CONFIRM_PI="n"
        shift
        ;;
      --confirm-pi)
        CONFIRM_PI="y"
        shift
        ;;
      --nodered-version=*)
        NODERED_VERSION="${1#*=}"
        shift
        ;;
      --) # end argument parsing
        shift
        break
        ;;
      -*|--*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        exit 1
        ;;
    esac
  done
fi

echo -ne "\033[2 q"
if [[ -e /mnt/dietpi_userdata ]]; then
    echo -ne "\n\033[1;32mDiet-Pi\033[0m detected - only going to add the  \033[0;36mnode-red-start, -stop, -log\033[0m  commands.\n"
    echo -ne "Flow files and other things worth backing up can be found in the \033[0;36m/mnt/dietpi_userdata/node-red\033[0m directory.\n\n"
    echo -ne "Use the  \033[0;36mdietpi-software\033[0m  command to un-install and re-install \033[38;5;88mNode-RED\033[0m.\n"
    echo "journalctl -f -n 25 -u node-red -o cat" > /usr/bin/node-red-log
    chmod +x /usr/bin/node-red-log
    echo "dietpi-services stop node-red" > /usr/bin/node-red-stop
    chmod +x /usr/bin/node-red-stop
    echo "dietpi-services start node-red" > /usr/bin/node-red-start
    echo "journalctl -f -n 0 -u node-red -o cat" >> /usr/bin/node-red-start
    chmod +x /usr/bin/node-red-start
else

if [ "$EUID" == "0" ]; then
# if [[ $SUDO_USER != "" ]]; then
  echo -en "\nroot user detected. Typical installs should be done as a regular user.\r\n"
  echo -en "If you are running this script using sudo, please cancel and rerun without sudo.\r\n"
  echo -en "If you know what you are doing as root, please continue.\r\n\r\n"

  yn="${CONFIRM_ROOT}"
  [ ! "${yn}" ] && read -t 10 -p "Are you really sure you want to install as root ? (y/N) ? " yn
  case $yn in
    [Yy]* )
    ;;
    * )
      echo " "
      exit 1
    ;;
  esac
  id -u nobody &>/dev/null || adduser --no-create-home --shell /dev/null --disabled-password --disabled-login --gecos '' nobody &>/dev/null
fi
if [[ "$(uname)" != "Darwin" ]]; then
# if curl -f https://www.npmjs.com/package/node-red  >/dev/null 2>&1; then
if curl -I https://registry.npmjs.org/@node-red/util  >/dev/null 2>&1; then
echo -e '\033]2;'Node-RED update'\007'
echo " "
echo "This script will remove versions of Node.js prior to version 12.x, and Node-RED and"
echo "if necessary replace them with Node.js 12.x LTS (erbium) and the latest Node-RED from Npm."
echo " "
echo "It also moves any Node-RED nodes that are globally installed into your user"
echo "~/.node-red/node_modules directory, and adds them to your package.json, so that"
echo "you can manage them with the palette manager."
echo " "
echo "It also tries to run 'npm rebuild' to refresh any extra nodes you have installed"
echo "that may have a native binary component. While this normally works ok, you need"
echo "to check that it succeeds for your combination of installed nodes."
echo " "
echo "To do all this it runs commands as root - please satisfy yourself that this will"
echo "not damage your Pi, or otherwise compromise your configuration."
echo "If in doubt please backup your SD card first."
echo " "
if [[ -e $HOME/.nvm ]]; then
    echo -ne '\033[1mNOTE:\033[0m We notice you are using \033[38;5;88mnvm\033[0m. Please ensure it is running the current LTS version.\n'
    echo -ne 'Using nvm is NOT RECOMMENDED. Node-RED will not run as a service under nvm.\r\n\n'
fi

yn="${CONFIRM_INSTALL}"
[ ! "${yn}" ] && read -p "Are you really sure you want to do this ? [y/N] ? " yn
case $yn in
    [Yy]* )
        echo ""
        EXTRANODES=""
        EXTRAW="update"

        response="${CONFIRM_PI}"
        [ ! "${response}" ] && read -r -t 15 -p "Would you like to install the Pi-specific nodes ? [y/N] ? " response
        if [[ "$response" =~ ^([yY])+$ ]]; then
            EXTRANODES="node-red-node-pi-gpio@latest node-red-node-random@latest node-red-node-ping@latest node-red-contrib-play-audio@latest node-red-node-smooth@latest node-red-node-serialport@latest"
            EXTRAW="install"
        fi

        # this script assumes that $HOME is the folder of the user that runs node-red
        # that $USER is the user name and the group name to use when running is the
        # primary group of that user
        # if this is not correct then edit the lines below
        MYOS=$(cat /etc/*release | grep "^ID=" | cut -d = -f 2)
        NODERED_HOME=$HOME
        NODERED_USER=$USER
        NODERED_GROUP=`id -gn`
        GLOBAL="true"
        TICK='\033[1;32m\u2714\033[0m'
        CROSS='\033[1;31m\u2718\033[0m'
        cd "$NODERED_HOME" || exit 1
        clear
        echo -e "\nRunning Node-RED $EXTRAW for user $USER at $HOME on $MYOS\n"
        time1=$(date)
        echo "" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        echo "***************************************" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        echo "" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        echo "Started : "$time1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
        echo "Running for user $USER at $HOME" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        echo -ne '\r\nThis can take 20-30 minutes on the slower Pi versions - please wait.\r\n\n'
        echo -ne '  Stop Node-RED                       \r\n'
        echo -ne '  Remove old version of Node-RED      \r\n'
        echo -ne '  Remove old version of Node.js       \r\n'
        echo -ne '  Install Node.js                     \r\n'
        echo -ne '  Clean npm cache                     \r\n'
        echo -ne '  Install Node-RED core               \r\n'
        echo -ne '  Move global nodes to local          \r\n'
        echo -ne '  Install extra Pi nodes              \r\n'
        echo -ne '  Npm rebuild existing nodes          \r\n'
        echo -ne '  Add shortcut commands               \r\n'
        echo -ne '  Update systemd script               \r\n'
        echo -ne '                                      \r\n'
        echo -ne '\r\nAny errors will be logged to   /var/log/nodered-install.log\r\n'
        echo -ne '\033[14A'

        # stop any running node-red service
        if sudo service nodered stop 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null ; then CHAR=$TICK; else CHAR=$CROSS; fi
        echo -ne "  Stop Node-RED                       $CHAR\r\n"

        # save any global nodes
        GLOBALNODES=$(find /usr/local/lib/node_modules/node-red-* -maxdepth 0 -type d -printf '%f\n' 2>/dev/null)
        GLOBALNODES="$GLOBALNODES $(find /usr/lib/node_modules/node-red-* -maxdepth 0 -type d -printf '%f\n' 2>/dev/null)"
        echo "Found global nodes: $GLOBALNODES :" | sudo tee -a /var/log/nodered-install.log >>/dev/null

        # remove any old node-red installs or files
        sudo apt remove -y nodered 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
        # sudo apt remove -y node-red-update 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
        sudo rm -rf /usr/local/lib/node_modules/node-red* /usr/local/lib/node_modules/npm /usr/local/bin/node-red* /usr/local/bin/node /usr/local/bin/npm 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
        sudo rm -rf /usr/lib/node_modules/node-red* /usr/bin/node-red* 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
        echo -ne '  Remove old version of Node-RED      \033[1;32m\u2714\033[0m\r\n'

        nv="v0"
        nv2=""
        ndeb=$(apt-cache policy nodejs | grep Installed | awk '{print $2}')
        if [[ -x "$(command -v node)" ]]; then
            nv=`node -v | cut -d "." -f1`
            nv2=`node -v`
            # nv2=`apt list nodejs 2>/dev/null | grep dfsg | cut -d ' ' -f 2 | cut -d '-' -f 1`
            echo "Already have nodejs $nv2" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        fi
        # ensure ~/.config dir is owned by the user
        echo "Now install nodejs" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        sudo chown -Rf $NODERED_USER:$NODERED_GROUP $NODERED_HOME/.config/
        # maybe remove Node.js - or upgrade if nodesoure.list exists
        if [[ "$(uname -m)" =~ "i686" ]]; then
            echo "Using i686" | sudo tee -a /var/log/nodered-install.log >>/dev/null
            curl -sSL -o /tmp/node.tgz https://unofficial-builds.nodejs.org/download/release/v$tgtl/node-v$tgtl-linux-x86.tar.gz 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            # unpack it into the correct places
            hd=$(head -c 9 /tmp/node.tgz)
            if [ "$hd" == "<!DOCTYPE" ]; then
                CHAR="$CROSS File $f not downloaded";
            else
                if sudo tar -zxf /tmp/node.tgz --strip-components=1 -C /usr 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
            fi
            rm /tmp/node.tgz 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            echo -ne "  Install Node.js for i686            $CHAR"
        elif uname -m | grep -q armv6l ; then
            sudo apt remove -y nodejs nodejs-legacy npm 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo rm -rf /etc/apt/sources.d/nodesource.list /usr/lib/node_modules/npm*
            echo -ne "  Remove old version of Node.js       $TICK\r\n"
            echo -ne "  Install Node.js for Armv6           \r"
            # f=$(curl -sL https://nodejs.org/download/release/latest-dubnium/ | grep "armv6l.tar.gz" | cut -d '"' -f 2)
            # curl -sL -o node.tgz https://nodejs.org/download/release/latest-dubnium/$f 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            curl -sSL -o /tmp/node.tgz https://unofficial-builds.nodejs.org/download/release/v$tgta/node-v$tgta-linux-armv6l.tar.gz 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            # unpack it into the correct places
            hd=$(head -c 9 /tmp/node.tgz)
            if [ "$hd" == "<!DOCTYPE" ]; then
                CHAR="$CROSS File $f not downloaded";
            else
                if sudo tar -zxf /tmp/node.tgz --strip-components=1 -C /usr 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
            fi
            # remove the tgz file to save space
            rm /tmp/node.tgz 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            echo -ne "  Install Node.js for Armv6           $CHAR"
        elif [[ -e $HOME/.nvm ]]; then
            echo -ne '  Using NVM to manage Node.js         +   please run   \033[0;36mnvm use lts\033[0m   before running Node-RED\r\n'
            echo -ne '  NOTE: Using nvm is NOT RECOMMENDED.     Node-RED will not run as a service under nvm.\r\n'
            export NVM_DIR=$HOME/.nvm
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
            echo "Using NVM !!! $(nvm current)" 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            nvm install --lts --no-progress --latest-npm >/dev/null 2>&1
            nvm use lts >/dev/null 2>&1
            nvm alias default lts >/dev/null 2>&1
            echo "Now using --- $(nvm current)" 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            GLOBAL="false"
            ln -f -s $HOME/.nvm/versions/node/$(nvm current)/lib/node_modules/node-red/red.js  $NODERED_HOME/node-red
            echo -ne "  Update Node.js LTS                  $CHAR"
        elif [[ $(which n) ]]; then
            echo "Using n" | sudo tee -a /var/log/nodered-install.log >>/dev/null
            echo -ne "  Using N to manage Node.js           +\r\n"
            if sudo n lts 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
            echo -ne "  Update Node.js LTS                  $CHAR"
        elif [ "$nv" = "v0" ] || [ "$nv" = "v1" ] || [ "$nv" = "v3" ] || [ "$nv" = "v4" ] || [ "$nv" = "v5" ] || [ "$nv" = "v6" ] || [ "$nv" = "v7" ] || [ "$nv" = "v8" ] || [ "$nv" = "v9" ] || [ "$nv2" = "v10.23.1" ] || [ "$nv" = "v11" ] || [ "$nv" = "v13" ] || [[ "$ndeb" =~ "dfsg" ]]; then
            echo "Updating nodejs $nv2" | sudo tee -a /var/log/nodered-install.log >>/dev/null
            if [[ -f /etc/apt/sources.list.d/nodesource.list ]]; then
                echo "Using nodesource.list" | sudo tee -a /var/log/nodered-install.log >>/dev/null
                if [ "$nv" = "v0" ] || [ "$nv" = "v1" ] || [ "$nv" = "v3" ] || [ "$nv" = "v4" ] || [ "$nv" = "v5" ] || [ "$nv" = "v6" ] || [ "$nv" = "v7" ] || [ "$nv" = "v8" ] || [ "$nv" = "v9" ] || [ "$nv2" = "v10.23.1" ] || [ "$nv" = "v11" ] || [ "$nv" = "v13" ] || [[ "$ndeb" =~ "dfsg" ]]; then
                    echo "Removing nodejs "$nv | sudo tee -a /var/log/nodered-install.log >>/dev/null
                    sudo apt remove -y nodejs nodejs-legacy npm 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                    sudo rm -rf /etc/apt/sources.d/nodesource.list /usr/lib/node_modules/npm*
                    if curl -sSL https://deb.nodesource.com/setup_12.x | sudo -E bash - 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
                else
                    CHAR="-"
                fi
                echo -ne "  Remove old version of Node.js       $CHAR  $nv\r\n"
                echo -ne "  Update Node.js LTS                  \r"
                if sudo apt install -y nodejs 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
                echo -ne "  Update Node.js LTS                  $CHAR"
            else
                # clean out old nodejs stuff
                echo "Not using nodesource.list" | sudo tee -a /var/log/nodered-install.log >>/dev/null
                npv=$(npm -v 2>/dev/null | head -n 1 | cut -d "." -f1)
                sudo apt remove -y nodejs nodejs-legacy npm 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                sudo dpkg -r nodejs 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                sudo dpkg -r node 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                sudo rm -rf /opt/nodejs 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                sudo rm -f /usr/local/bin/node* 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                sudo rm -rf /usr/local/bin/npm* /usr/local/bin/npx* /usr/lib/node_modules/npm* 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                if [ "$npv" = "1" ]; then
                    sudo rm -rf /usr/local/lib/node_modules/node-red* /usr/lib/node_modules/node-red* 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                fi
                sudo apt -y autoremove 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                echo -ne "  Remove old version of Node.js       \033[1;32m\u2714\033[0m\r\n"
                echo "Grab the LTS bundle" | sudo tee -a /var/log/nodered-install.log >>/dev/null
                echo -ne "  Install Node.js LTS                 \r"
                # use the official script to install for other debian platforms
                sudo apt install -y curl 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                curl -sSL https://deb.nodesource.com/setup_12.x | sudo -E bash - 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                if sudo apt install -y nodejs 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
                echo -ne "  Install Node.js LTS                 $CHAR"
            fi
        else
            CHAR="-"
            echo -ne "  Remove old version of Node.js       $CHAR\n"
            echo -ne "  Leave existing Node.js              $CHAR"
        fi
        NUPG=$CHAR
        hash -r
        rc=""
        if nov=$(node -v 2>/dev/null); then :; else rc="ERR"; fi
        if npv=$(npm -v 2>/dev/null); then :; else rc="ERR"; fi
        echo "Versions: node:$nov npm:$npv" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        if [[ "$rc" == "" ]]; then
            echo -ne "   Node $nov   Npm $npv\r\n"
        else
            echo -ne "\b$CROSS   Failed to install Node.js - Exit\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n"
            exit 2
        fi
        if [ "$EUID" == "0" ]; then npm config set unsafe-perm true &>/dev/null; fi

        # clean up the npm cache and node-gyp
        if [[ "$NUPG" == "$TICK" ]]; then
            if [[ "$GLOBAL" == "true" ]]; then
                sudo npm cache clean --force 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            else
                npm cache clean --force 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            fi
            if sudo rm -rf "$NODERED_HOME/.node-gyp" "$NODERED_HOME/.npm" /root/.node-gyp /root/.npm; then CHAR=$TICK; else CHAR=$CROSS; fi
        fi
        echo -ne "  Clean npm cache                     $CHAR\r\n"

        # and install Node-RED
        echo "Now install Node-RED" | sudo tee -a /var/log/nodered-install.log >>/dev/null

        NODERED_VERSION_SELECTION=""
        if [ -z ${NODERED_VERSION} ]; then
            NODERED_VERSION_SELECTION="latest"
        else
            NODERED_VERSION_SELECTION=${NODERED_VERSION}
        fi

        if [[ "$GLOBAL" == "true" ]]; then
            if sudo npm i -g --unsafe-perm --no-progress --no-update-notifier --no-audit --no-fund node-red@"$NODERED_VERSION_SELECTION" 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
        else
            if npm i -g --unsafe-perm --no-progress --no-update-notifier --no-audit --no-fund node-red@"$NODERED_VERSION_SELECTION" 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
        fi
        nrv=$(npm --no-progress --no-update-notifier --no-audit --no-fund -g ls node-red | grep node-red | cut -d '@' -f 2 | sudo tee -a /var/log/nodered-install.log) >>/dev/null 2>&1
        echo -ne "  Install Node-RED core               $CHAR   $nrv\r\n"

        # install any nodes, that were installed globally, as local instead
        echo "Now create basic package.json for the user and move any global nodes" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        mkdir -p "$NODERED_HOME/.node-red/node_modules"
        sudo chown -Rf $NODERED_USER:$NODERED_GROUP $NODERED_HOME/.node-red/ 2>&1 >>/dev/null
        pushd "$NODERED_HOME/.node-red" 2>&1 >>/dev/null
            npm config set update-notifier false 2>&1 >>/dev/null
            if [ ! -f "package.json" ]; then
                echo '{' > package.json
                echo '  "name": "node-red-project",' >> package.json
                echo '  "description": "initially created for you by Node-RED '$nrv'",' >> package.json
                echo '  "version": "0.0.1",' >> package.json
                echo '  "private": true,' >> package.json
                echo '  "dependencies": {' >> package.json
                echo '  }' >> package.json
                echo '}' >> package.json
            fi
            CHAR="-"
            if [[ $GLOBALNODES != " " ]]; then
                if npm i --unsafe-perm --save --no-progress --no-update-notifier --no-audit --no-fund $GLOBALNODES 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
            fi
            echo -ne "  Move global nodes to local          $CHAR\r\n"

            CHAR="-"
            if [[ ! -z $EXTRANODES ]]; then
                echo "Installing extra nodes: $EXTRANODES :" | sudo tee -a /var/log/nodered-install.log >>/dev/null
                if npm i --unsafe-perm --save --no-progress --no-update-notifier --no-audit --no-fund $EXTRANODES 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
            fi
            echo -ne "  Install extra Pi nodes              $CHAR\r\n"

            # try to rebuild any already installed nodes
            if [[ "$NUPG" == "$TICK" ]]; then
                if npm rebuild --unsafe-perm 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
                echo -ne "  Npm rebuild existing nodes          $CHAR\r\n"
            else
                echo -ne "  Npm rebuild existing nodes          -\r\n"
            fi
        popd 2>&1 >>/dev/null
        sudo chown -Rf $NODERED_USER:$NODERED_GROUP $NODERED_HOME/.npm 2>&1 >>/dev/null

        # add the shortcut and start/stop/log scripts to the menu
        echo "Now add the shortcut and start/stop/log scripts to the menu" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        sudo mkdir -p /usr/bin
        if curl -f https://raw.githubusercontent.com/node-red/linux-installers/master/resources/node-red-icon.svg >/dev/null 2>&1; then
            sudo curl -sL -o /usr/share/icons/hicolor/scalable/apps/node-red-icon.svg https://raw.githubusercontent.com/node-red/linux-installers/master/resources/node-red-icon.svg 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo curl -sL -o /usr/share/applications/Node-RED.desktop https://raw.githubusercontent.com/node-red/linux-installers/master/resources/Node-RED.desktop 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo curl -sL -o /usr/bin/node-red-start https://raw.githubusercontent.com/node-red/linux-installers/master/resources/node-red-start 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo curl -sL -o /usr/bin/node-red-stop https://raw.githubusercontent.com/node-red/linux-installers/master/resources/node-red-stop 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo curl -sL -o /usr/bin/node-red-restart https://raw.githubusercontent.com/node-red/linux-installers/master/resources/node-red-restart 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo curl -sL -o /usr/bin/node-red-reload https://raw.githubusercontent.com/node-red/linux-installers/master/resources/node-red-reload 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo curl -sL -o /usr/bin/node-red-log https://raw.githubusercontent.com/node-red/linux-installers/master/resources/node-red-log 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo curl -sL -o /etc/logrotate.d/nodered https://raw.githubusercontent.com/node-red/linux-installers/master/resources/nodered.rotate 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo chmod +x /usr/bin/node-red-start
            sudo chmod +x /usr/bin/node-red-stop
            sudo chmod +x /usr/bin/node-red-restart
            sudo chmod +x /usr/bin/node-red-reload
            sudo chmod +x /usr/bin/node-red-log
            echo -ne "  Add shortcut commands               $TICK\r\n"
        else
            echo -ne "  Add shortcut commands               $CROSS\r\n"
        fi

        # add systemd script and configure it for $USER
        echo "Now add systemd script and configure it for $USER" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        if sudo curl -sL -o /lib/systemd/system/nodered.service https://raw.githubusercontent.com/node-red/linux-installers/master/resources/nodered.service 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null; then CHAR=$TICK; else CHAR=$CROSS; fi
        # set the memory, User Group and WorkingDirectory in nodered.service
        if [ $(cat /proc/meminfo | grep MemTotal | cut -d ":" -f 2 | cut -d "k" -f 1 | xargs) -lt 894000 ]; then mem="256"; else mem="512"; fi
        if [ $(cat /proc/meminfo | grep MemTotal | cut -d ":" -f 2 | cut -d "k" -f 1 | xargs) -gt 1894000 ]; then mem="1024"; fi
        if [ $(cat /proc/meminfo | grep MemTotal | cut -d ":" -f 2 | cut -d "k" -f 1 | xargs) -gt 3894000 ]; then mem="2048"; fi
        # if [ $(cat /proc/meminfo | grep MemTotal | cut -d ":" -f 2 | cut -d "k" -f 1 | xargs) -gt 7894000 ]; then mem="4096"; fi
        sudo sed -i 's#=512#='$mem'#;' /lib/systemd/system/nodered.service
        sudo sed -i 's#^User=pi#User='$NODERED_USER'#;s#^Group=pi#Group='$NODERED_GROUP'#;s#^WorkingDirectory=/home/pi#WorkingDirectory='$NODERED_HOME'#;' /lib/systemd/system/nodered.service
        sudo systemctl daemon-reload 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
        echo -ne "  Update systemd script               $CHAR\r\n"
        sudo ln -s $(which python3) /usr/bin/python 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null

        # remove unneeded large sentiment library to save space and load time
        sudo rm -f /usr/lib/node_modules/node-red/node_modules/multilang-sentiment/build/output/build-all.json 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
        # on LXDE add launcher to top bar, refresh desktop menu
        file=/home/$NODERED_USER/.config/lxpanel/LXDE-pi/panels/panel
        if [ -e $file ]; then
            if ! grep -q "Node-RED" $file; then
                mat="lxterminal.desktop"
                ins="lxterminal.desktop\n    }\n    Button {\n      id=Node-RED.desktop"
                sudo sed -i "s|$mat|$ins|" $file 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                if xhost >& /dev/null ; then
                    export DISPLAY=:0 && lxpanelctl restart 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
                fi
            fi
        fi

        # on Pi, add launcher to top bar, add cpu temp example, make sure ping works
        echo "Now add launcher to top bar, add cpu temp example, make sure ping works" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        if sudo grep -q BCM2 /proc/cpuinfo; then
            sudo setcap cap_net_raw+eip $(eval readlink -f `which node`) 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo setcap cap_net_raw=ep /bin/ping 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
            sudo adduser $NODERED_USER gpio 2>&1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
        fi

        echo -ne "\r\n\r\n\r\n"
        echo -ne "All done.\r\n"
        if [[ "$GLOBAL" == "true" ]]; then
            echo -ne "  You can now start Node-RED with the command  \033[0;36mnode-red-start\033[0m\r\n"
            echo -ne "  or using the icon under   Menu / Programming / Node-RED\r\n"
        else
            echo -ne "  You can now start Node-RED with the command  \033[0;36m./node-red\033[0m\r\n"
        fi
        echo -ne "  Then point your browser to \033[0;36mlocalhost:1880\033[0m or \033[0;36mhttp://{your_pi_ip-address}:1880\033[0m\r\n"
        echo -ne "\r\nStarted  $time1  -  Finished  $(date)\r\n\r\n"
        echo "Memory : $(free -h -t | grep Total | awk '{print $2}' | cut -d i -f 1)" | sudo tee -a /var/log/nodered-install.log >>/dev/null
        echo "Finished : "$time1 | sudo tee -a /var/log/nodered-install.log >>/dev/null
    ;;
    * )
        echo " "
        exit 1
    ;;
esac
else
echo " "
echo "Sorry - cannot connect to internet - not going to touch anything."
echo "https://www.npmjs.com/package/node-red   is not reachable."
echo "Please ensure you have a working internet connection."
echo "Return code from curl is "$?
echo " "
exit 1
fi
else
echo " "
echo "Sorry - I'm not supposed to be run on a Mac."
echo "Please see the documentation at http://nodered.org/docs/getting-started/upgrading."
echo " "
exit 1
fi
fi
