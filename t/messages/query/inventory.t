#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Config;
use XML::TreePP;

use FusionInventory::Agent;
use FusionInventory::Agent::XML::Query::Inventory;

plan tests => 9;

my $inventory;
throws_ok {
    $inventory = FusionInventory::Agent::XML::Query::Inventory->new();
} qr/^no deviceid/, 'no device id';

lives_ok {
    $inventory = FusionInventory::Agent::XML::Query::Inventory->new(
        deviceid => 'foo',
    );
} 'everything OK';

isa_ok($inventory, 'FusionInventory::Agent::XML::Query::Inventory');

my $tpp = XML::TreePP->new(force_array => [ qw/SOFTWARES CPUS DRIVES/ ]);
my $content;

$content = {
    REQUEST => {
        CONTENT => {
            BIOS => undef,
            HARDWARE => {
                ARCHNAME => $Config{archname},
                CHECKSUM => 262143,
                VMSYSTEM => 'Physical'
            },
            NETWORKS => undef,
            VERSIONCLIENT => $FusionInventory::Agent::AGENT_STRING
        },
        DEVICEID => 'foo',
        QUERY => 'INVENTORY'
    }
};
is_deeply(
    scalar $tpp->parse($inventory->getContent()),
    $content,
    'creation content'
);

$inventory = FusionInventory::Agent::XML::Query::Inventory->new(
    deviceid => 'foo',
);

$inventory->addCPU({
    NAME => 'void CPU',
    SPEED => 1456,
    MANUFACTURER => 'FusionInventory Developers',
    SERIAL => 'AEZVRV',
    THREAD => 3,
    CORE => 1
});

$content = {
    REQUEST => {
        CONTENT => {
            BIOS => undef,
            HARDWARE => {
                ARCHNAME => $Config{archname},
                CHECKSUM => 262143,
                PROCESSORN => 1,
                PROCESSORS => 1456,
                PROCESSORT => 'void CPU',
                VMSYSTEM => 'Physical'
            },
            NETWORKS => undef,
            VERSIONCLIENT => $FusionInventory::Agent::AGENT_STRING,
            CPUS => [
                {
                    CORE => 1,
                    MANUFACTURER => 'FusionInventory Developers',
                    NAME => 'void CPU',
                    SERIAL => 'AEZVRV',
                    SPEED => 1456,
                    THREAD => 3,
                }
            ]
        },
        DEVICEID => 'foo',
        QUERY => 'INVENTORY'
    }
};
is_deeply(
    scalar $tpp->parse($inventory->getContent()),
    $content,
    'CPU added'
);

$inventory = FusionInventory::Agent::XML::Query::Inventory->new(
    deviceid => 'foo',
);

$inventory->addDrive({
    FILESYSTEM => 'ext3',
    FREE => 9120,
    SERIAL => '7f8d8f98-15d7-4bdb-b402-46cbed25432b',
    TOTAL => 18777,
    TYPE => '/',
    VOLUMN => '/dev/sda2',
});

$content = {
    REQUEST => {
        CONTENT => {
            BIOS => undef,
            HARDWARE => {
                ARCHNAME => $Config{archname},
                CHECKSUM => 262143,
                VMSYSTEM => 'Physical'
            },
            NETWORKS => undef,
            VERSIONCLIENT => $FusionInventory::Agent::AGENT_STRING,
            DRIVES => [
                {
                    FILESYSTEM => 'ext3',
                    FREE => 9120,
                    SERIAL => '7f8d8f98-15d7-4bdb-b402-46cbed25432b',
                    TOTAL => 18777,
                    TYPE => '/',
                    VOLUMN => '/dev/sda2'
                }
            ]
        },
        DEVICEID => 'foo',
        QUERY => 'INVENTORY'
    }
};
is_deeply(
    scalar $tpp->parse($inventory->getContent()),
    $content,
    'drive added'
);

$inventory = FusionInventory::Agent::XML::Query::Inventory->new(
    deviceid => 'foo',
);

$inventory->addSoftwareDeploymentPackage({ ORDERID => '1234567891' });

$content = {
    REQUEST => {
        CONTENT => {
            BIOS => undef,
            HARDWARE => {
                ARCHNAME => $Config{archname},
                CHECKSUM => 262143,
                VMSYSTEM => 'Physical'
            },
            NETWORKS => undef,
            VERSIONCLIENT => $FusionInventory::Agent::AGENT_STRING,
            DOWNLOAD => {
                HISTORY => {
                    PACKAGE => {
                        ID => 1234567891
                    }
                }
            }
        },
        DEVICEID => 'foo',
        QUERY => 'INVENTORY'
    }
};
is_deeply(
    scalar $tpp->parse($inventory->getContent()),
    $content,
    'software deployment added'
);

$inventory = FusionInventory::Agent::XML::Query::Inventory->new(
    deviceid => 'foo',
);

$inventory->addSoftware({
    NAME        => 'glibc',
    VERSION     => '2.12.1',
    INSTALLDATE => 'Wed Nov 24 22:48:21 2010',
    FILESIZE    => '25020674',
    COMMENTS    => 'The GNU libc libraries',
    FROM        => 'rpm'
});

$content = {
    REQUEST => {
        CONTENT => {
            BIOS => undef,
            HARDWARE => {
                ARCHNAME => $Config{archname},
                CHECKSUM => 262143,
                VMSYSTEM => 'Physical'
            },
            NETWORKS => undef,
            VERSIONCLIENT => $FusionInventory::Agent::AGENT_STRING,
            SOFTWARES => [
                {
                    NAME        => 'glibc',
                    VERSION     => '2.12.1',
                    INSTALLDATE => 'Wed Nov 24 22:48:21 2010',
                    FILESIZE    => '25020674',
                    COMMENTS    => 'The GNU libc libraries',
                    FROM        => 'rpm'
                }
            ]
        },
        DEVICEID => 'foo',
        QUERY => 'INVENTORY'
    }
};
is_deeply(
    scalar $tpp->parse($inventory->getContent()),
    $content,
    'software added'
);

$inventory = FusionInventory::Agent::XML::Query::Inventory->new(
    deviceid => 'foo',
);

$inventory->addSoftware({
    NAME        => 'glibc',
    VERSION     => '2.12.1',
    INSTALLDATE => 'Wed Nov 24 22:48:21 2010',
    FILESIZE    => '25020674',
    COMMENTS    => 'The GNU libc libraries',
    FROM        => 'rpm'
});

$inventory->addSoftware({
    NAME        => 'glibc',
    VERSION     => '2.12.1',
    INSTALLDATE => 'Wed Nov 24 22:48:21 2010',
    FILESIZE    => '25020674',
    COMMENTS    => 'The GNU libc libraries',
    FROM        => 'rpm'
});

is_deeply(
    scalar $tpp->parse($inventory->getContent()),
    $content,
    'duplicated software added'
);
