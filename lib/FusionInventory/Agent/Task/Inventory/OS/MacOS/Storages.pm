package FusionInventory::Agent::Task::Inventory::OS::MacOS::Storages;

use strict;
use warnings;

use FusionInventory::Agent::Tools;

sub isInventoryEnabled {
    return 1;
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    my $devices = {};

    # Get SATA Drives
    my $sata = _getDiskInfo();

    foreach my $device ( @$sata ) {
        my $description;
        if (!$device->{'Protocol'}) {
            $description = 'Disk drive';
        } elsif ( ($device->{'Protocol'} eq 'ATAPI')
                ||
                ($device->{'Drive Type'}) ) {
            $description = 'CD-ROM Drive';
        }

        my $size = $device->{'Capacity'};
        if ($size) {
            #e.g: Capacity: 320,07 GB (320 072 933 376 bytes)
            $size =~ s/\s*\(.*//;
            $size =~ s/ GB//;
            $size =~ s/,/./;
            $size = int($size * 1024);
        }

        my $manufacturer = getCanonicalManufacturer($device->{'Name'});

        my $model = $device->{'Model'};
        if ($model) {
            $model =~ s/\s*$manufacturer\s*//i;
        }

        $inventory->addStorage({
            NAME => $device->{'Name'},
            SERIAL => $device->{'Serial Number'},
            DISKSIZE => $size,
            FIRMWARE => $device->{'Revision'},
            MANUFACTURER => $manufacturer,
            DESCRIPTION => $description,
            MODEL => $model,
            TYPE => $device->{'Type'}
        });
    }


}

sub _getDiskInfo {
    my ($section) = @_;

    my $wasEmpty;
    my $revIndent = '';
    my @infos;
    my $info;
    my $name;
    my $type;
    foreach (`/usr/sbin/system_profiler SPSerialATADataType`,
        `/usr/sbin/system_profiler SPParallelATADataType`,
        `/usr/sbin/system_profiler SPUSBDataType`,
        `/usr/sbin/system_profiler SPFireWireDataType`) {
        if (/^\s*$/) {
            $wasEmpty=1;
            next;
        }

        next unless /^(\s*)/;
        if ($1 ne $revIndent) {
            $name = $1 if (/^\s+(\S+.*\S+):\s*$/ && $wasEmpty);
            $revIndent = $1;

# We use the Protocol key to know if it a storage section or not
            if (
                # disk
                ($info->{'BSD Name'} && $info->{'BSD Name'} =~ /^disk\d+$/)
                ||
                # USB Disk
#                ($info->{'BSD Name'} && $info->{'Product ID'})
#                ||
                # CDROM
                ($info->{'Protocol'} && $info->{'Socket Type'})
            ) {
                $info->{Type} = $type;
                push @infos, $info;
                $name = '';
            }
            $info = {};
        }
        if (/^\s+(\S+.*?):\s+(\S.*)/) {
            $info->{$1}=$2;
            $info->{Name} = $name;
        }

        $type = '' if /^(\S+)/;
        if (/^(\S+):$/) {
            $type=$1;
            if ($type eq 'FireWire') {
                $type = '1394';
            }
        }


        $wasEmpty=0;
    }
# The last one
    if ($info->{Protocol}) {
        push @infos, $info;
    }
    return \@infos;
}

1;
