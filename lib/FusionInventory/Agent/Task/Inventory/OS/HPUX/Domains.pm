package FusionInventory::Agent::Task::Inventory::OS::HPUX::Domains;

use strict;
use warnings;

use English qw(-no_match_vars);

use FusionInventory::Agent::Tools;

sub isInventoryEnabled {
    return can_run('domainname');
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};

    my $domain = getSingleLine(command => 'domainname');

    if (!$domain) {
        my %domain;

        if (open my $handle, '<', '/etc/resolv.conf') {
            while(<$handle>) {
                $domain{$2} = 1 if (/^(domain|search)\s+(.+)/);
            }
            close $handle;
        } else {
            warn "Can't open /etc/resolv.conf: $ERRNO";
        }
        $domain = join "/", keys %domain;
    }

    $inventory->setHardware({
        WORKGROUP => $domain
    });
}

1;
