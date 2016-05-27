#!/bin/bash
set -e

# set defaults
default_hostname="$(hostname)"
default_domain="acro.local"
default_puppetmaster="foreman.netson.nl"
tmp="/root/"

clear

# check for root privilege
if [ "$(id -u)" != "0" ]; then
   echo " this script must be run as root" 1>&2
   echo
   exit 1
fi

# define download function
# courtesy of http://fitnr.com/showing-file-download-progress-using-wget.html
download()
{
    local url=$1
    echo -n "    "
    wget --progress=dot $url 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    echo -ne "\b\b\b\b"
    echo " DONE"
}

# determine ubuntu version
ubuntu_version=$(lsb_release -cs)

# check for interactive shell
if ! grep -q "noninteractive" /proc/cmdline ; then
    stty sane

    # ask questions
    read -ep " please enter your preferred hostname: " -i "$default_hostname" hostname
    read -ep " please enter your preferred domain: " -i "$default_domain" domain
    read -ep " URL of public key(s) to initialze SSH access with: " -i "https://github.com/dale-c-anderson.keys" ssh_pubkey_url

fi

# print status message
echo " preparing your server; this may take a few minutes ..."

# Put public key(s) in place so user can log in.
(umask 077 && mkdir .ssh && wget -O .ssh/authorized_keys $ssh_pubkey_url)
chown -r 1000:1000 .ssh

# set fqdn
fqdn="$hostname.$domain"

# update hostname
echo "$hostname" > /etc/hostname
sed -i "s@ubuntu.ubuntu@$fqdn@g" /etc/hosts
sed -i "s@ubuntu@$hostname@g" /etc/hosts
hostname "$hostname"


# apply passwordless sudo
export SUDOERS="/etc/sudoers.d/90-passwordless-sudoers"
echo "## ALWAYS USE visudo TO EDIT SUDOERS FILES" | (EDITOR="tee -a" visudo -f "$SUDOERS")
echo '%sudo ALL = (ALL) NOPASSWD: ALL' | (EDITOR="tee -a" visudo -f "$SUDOERS")


# update repos
apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove
apt-get -y purge


# Install SSH server and remove password logins
apt-get -y install openssh-server
sed -i "s@#PasswordAuthentication yes@PasswordAuthentication no@g" /etc/ssh/sshd_config


# remove myself to prevent any unintended changes at a later stage
chmod -x "$0"
mv "$0" "$0.finished"

# finish
echo " DONE; rebooting ... "

# reboot
reboot
