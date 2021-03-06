package FusionInventory::Agent::Task::Inventory::Virtualization::Xen;

use strict;
use warnings;

use FusionInventory::Agent::Tools;

our $runMeIfTheseChecksFailed = ["FusionInventory::Agent::Task::Inventory::Virtualization::Libvirt"];

sub isInventoryEnabled {
    return can_run('xm');
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{inventory};

    my $command = 'xm list';
    foreach my $machine (_getVirtualMachines(command => $command, logger => $logger)) {
        my $uuid = getFirstMatch(
            command => "xm list -l $machine->{NAME}",
            pattern => qr/\s+.*uuid\s+(.*)/,
            logger  => $logger
        );
        $machine->{UUID} = $uuid;
        $inventory->addVirtualMachine($machine);
    }
}

sub  _getVirtualMachines {

    my $handle = getFileHandle(@_);

    return unless $handle;

    # xm status
    my %status_list = (
        'r' => 'running',
        'b' => 'blocked',
        'p' => 'paused',
        's' => 'shutdown',
        'c' => 'crashed',
        'd' => 'dying',
    );

    # drop headers
    my $line  = <$handle>;

    my @machines;
    while (my $line = <$handle>) {
        chomp $line;
        my ($name, $vmid, $memory, $vcpu, $status, $time) = split(' ', $line);
        next if $name eq 'Domain-0';

        $status =~ s/-//g;
        $status = $status ? $status_list{$status} : 'off';

        my $machine = {
            MEMORY    => $memory,
            NAME      => $name,
            STATUS    => $status,
            SUBSYSTEM => 'xm',
            VMTYPE    => 'xen',
            VCPU      => $vcpu,
            VMID      => $vmid,
        };

        push @machines, $machine;

    }
    close $handle;

    return @machines;
}

1;
