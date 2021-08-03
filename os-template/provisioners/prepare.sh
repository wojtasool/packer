#!/bin/sh
# Clean image
#########################################################

find /etc/sysconfig/network-scripts/ifcfg-* \
  -maxdepth 0 -type f -not -name ifcfg-lo \
    -exec sed -i -e '/^UUID/d' -e '/^HWADDR/d' {} \;

yum update -y
#curl https://releases.rancher.com/install-docker/19.03.sh | sh
# Blank all log files
find /var/log -type f | while read f; do echo -n '' > $f; done

echo "Installing docker packages"
CHANNEL="stable"
DOWNLOAD_URL="https://download.docker.com"
REPO_FILE="docker-ce.repo"
VERSION=20.10.5
releasever=7
lsb_dist="ol"
dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"

pkg_manager="yum"
config_manager="yum-config-manager"
enable_channel_flag="--enable"
disable_channel_flag="--disable"
pre_reqs="yum-utils"
pkg_suffix="el"

for channel in "stable" "test" "nightly"; do
        yum-config-manager --setopt=docker-ce-${channel}.baseurl=${DOWNLOAD_URL}/linux/centos/${releasever}/\\$basearch/${channel} --save
        yum-config-manager --setopt=docker-ce-${channel}-debuginfo.baseurl=${DOWNLOAD_URL}/linux/centos/${releasever}/debug-\\$basearch/${channel} --save
        yum-config-manager --setopt=docker-ce-${channel}-source.baseurl=${DOWNLOAD_URL}/linux/centos/${releasever}/source/${channel} --save
done



yum_repo="$DOWNLOAD_URL/linux/centos/$REPO_FILE"
if ! curl -Ifs "$yum_repo" > /dev/null; then
        echo "Error: Unable to curl repository file $yum_repo, is it valid?"
        exit 1
fi

yum install -y -q $pre_reqs
$config_manager --add-repo $yum_repo
$config_manager $disable_channel_flag docker-ce-*
$config_manager $enable_channel_flag docker-ce-$CHANNEL
$config_manager $enable_channel_flag rhui-REGION-rhel-server-extras
$config_manager $enable_channel_flag rhui-rhel-7-server-rhui-extras-rpms
$config_manager $enable_channel_flag rhui-rhel-7-for-arm-64-extras-rhui-rpms
$config_manager $enable_channel_flag rhel-7-server-rhui-extras-rpms
$config_manager $enable_channel_flag rhel-7-server-extras-rpms
$config_manager $enable_channel_flag ol7_addons
$config_manager --add-repo https://yum.oracle.com/repo/OracleLinux/OL7/developer/x86_64

$pkg_manager makecache
pkg_pattern="$(echo "$VERSION" | sed "s/-ce-/\\\\.ce.*/g" | sed "s/-/.*/g").*$pkg_suffix"
pkg_version="$(yum list --showduplicates 'docker-ce' | grep $pkg_pattern | tail -1 | awk '{print $2}' | cut -d':' -f 2)"
cli_pkg_version="$(yum list --showduplicates 'docker-ce-cli' | grep $pkg_pattern | tail -1 | awk '{print $2}' | cut -d':' -f 2)"
$pkg_manager install -y docker-ce-cli-$cli_pkg_version
$pkg_manager install -y docker-ce-$pkg_version
$pkg_manager install -y iptables

rm -rf /tmp/* /var/tmp/*
yum clean all

# Removing all eth* devices from udev 
echo > /etc/udev/rules.d/70-persistent-net.rules
mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
cat /root/hostkey.pub >> /root/.ssh/authorized_keys
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install epel-release-latest-7.noarch.rpm -y
yum install cloud-init -y
systemctl enable cloud-init

sync

