package FusionInventory::Agent::Task::Inventory::OS::Win32::Networks;


use strict;
use Win32::OLE qw(in CP_UTF8);
use Win32::OLE::Const;
use Win32::OLE::Enum;
 
use FusionInventory::Agent::Tools::Win32;
use FusionInventory::Agent::Tools;

Win32::OLE->Option(CP=>CP_UTF8);

# http://techtasks.com/code/viewbookcode/1417
sub isInventoryEnabled {
    return 1;
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};

    my $strComputer = '.';
    my $objWMIService = Win32::OLE->GetObject('winmgmts:' . '{impersonationLevel=impersonate}!\\\\' . $strComputer . '\\root\\cimv2');

    my $nics = $objWMIService->ExecQuery('SELECT * FROM Win32_NetworkAdapterConfiguration');

    my $defaultGw;
    my @ips;
    my @ip6s;
    my @netifs;
    my %defaultgateways;
    my %dns;
    foreach my $nic (in $nics) {
        my $idx = $nic->Index;
        $netifs[$idx]{description} =  encodeFromWmi($nic->Description);

        foreach (@{$nic->DefaultIPGateway || []}) {
            $defaultgateways{$_} = 1;
        }

        foreach (@{$nic->DNSServerSearchOrder || []}) {
            $dns{$_} = 1;
        }

        if ($nic->IPAddress) {
            while (@{$nic->IPAddress}) {
                my $address = shift @{$nic->IPAddress};
                my $mask = shift @{$nic->IPSubnet};
                if ($address =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
                    push @ips, $address;
                    push @{$netifs[$idx]{ipaddress}}, $address;
                    push @{$netifs[$idx]{ipmask}}, $mask;
                    push @{$netifs[$idx]{ipsubnet}}, getSubnetAddress($address, $mask);
                } elsif ($address =~ /\S+/) {
                    push @ip6s, $address;
                    push @{$netifs[$idx]{ipaddress6}}, $address;
                    push @{$netifs[$idx]{ipmask6}}, $mask;
                    push @{$netifs[$idx]{ipsubnet6}}, getSubnetAddressIPv6($address, $mask);
                }
            }
        }

        if ($nic->DefaultIPGateway) {
            $netifs[$idx]{ipgateway} = $nic->DefaultIPGateway()->[0];
        }

        $netifs[$idx]{status} = $nic->IPEnabled?"Up":"Down";
        $netifs[$idx]{name} = $nic->Name;
        $netifs[$idx]{ipdhcp} = $nic->DHCPServer;
        $netifs[$idx]{macaddr} = $nic->MACAddress;
        $netifs[$idx]{mtu} = $nic->MTU;
    }

    $nics = $objWMIService->ExecQuery('SELECT * FROM Win32_NetworkAdapter');
    foreach my $nic (in $nics) {
        my $idx = $nic->Index;
        $netifs[$idx]{virtualdev} = $nic->PhysicalAdapter?0:1;
        $netifs[$idx]{name} = $nic->Name;
        $netifs[$idx]{macaddr} = $nic->MACAddress;
        $netifs[$idx]{speed} = $nic->Speed;
        $netifs[$idx]{pnpdeviceid} = $nic->PNPDeviceID;
    }

    foreach my $netif (@netifs) {

        # http://comments.gmane.org/gmane.comp.monitoring.fusion-inventory.devel/34
        next unless $netif->{pnpdeviceid};

        next if
            !$netif->{ipaddress} &&
            !$netif->{ipaddress6} &&
            !$netif->{macaddr}

        my $ipaddress  = $netif->{ipaddress}  ? join('/', @{$netif->{ipaddress})  : undef;
        my $ipmask     = $netif->{ipmask}     ? join('/', @{$netif->{ipmask})     : undef;
        my $ipsubnet   = $netif->{ipsubnet}   ? join('/', @{$netif->{ipsubnet})   : undef;
        my $ipaddress6 = $netif->{ipaddress6} ? join('/', @{$netif->{ipaddress6}) : undef;

        $inventory->addNetwork({
            DESCRIPTION => $netif->{description},
            IPADDRESS => $ipaddress,
            IPDHCP => $netif->{ipdhcp},
            IPGATEWAY => $netif->{ipgateway},
            IPMASK => $ipmask,
            IPSUBNET => $ipsubnet,
            IPADDRESS6 => $ipaddress6,
            MACADDR => $netif->{macaddr},
            MTU => $netif->{mtu},
            STATUS => $netif->{status},
            TYPE => $netif->{type},
            VIRTUALDEV => $netif->{virtualdev}
        });

    }


    $inventory->setHardware(
        DEFAULTGATEWAY => join('/', keys %defaultgateways),
        DNS            => join('/', keys %dns),
        IPADDR         => join('/', @ips),
    );

}

1;
