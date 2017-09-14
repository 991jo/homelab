#!/bin/bash

if [[ $# -lt 3 ]]
then
	echo "usage: setup_vm.sh <hostname> <oldip> <newip>"
	exit 1
fi

HOSTNAME=$1
OLDIP=$2
NEWIP=$3

echo "expanding partition table"
# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can 
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "defualt" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/vda
	d # delete a partition
	2 # select partition 2
	n # new partition
	p # primary partition
	2 # partition number 2
	  # default, start immediately after preceding partition
	  # default, extend partition to end of disk
	a # make a partition bootable
	2 # bootable partition is partition 2 -- /dev/vda2
	w # write the partition table
	q # and we're done
EOF

echo "rereading partition table"
partprobe /dev/vda
partprobe /dev/vda2

echo "resizing file system"
resize2fs /dev/vda2

echo "setting hostname to $HOSTNAME"
hostname $HOSTNAME					# instant change
echo "$HOSTNAME" > /etc/hostname  	# persistent change

echo "setting up /etc/hosts"
sed -i s/debian/$HOSTNAME/g /etc/hosts
sed -i s/127.0.1.1/$NEWIP/g /etc/hosts

echo "setting up /etc/resolv.conf"
cat << EOF > /etc/resolv.conf
domain swag
search swag
nameserver 192.168.101.20
EOF

echo "setting up /etc/network/interfaces"
sed -i s/$OLDIP/$NEWIP/g /etc/network/interfaces

echo "regenerating ssh keys for openssh server"
rm /etc/ssh/ssh_host_*				# delete all host ssh keys
dpkg-reconfigure openssh-server		# rebuild keys

echo "rebooting"
reboot
