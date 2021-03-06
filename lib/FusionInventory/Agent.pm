package FusionInventory::Agent;

use strict;
use warnings;

use English qw(-no_match_vars);

use FusionInventory::Agent::Config;
use FusionInventory::Agent::Logger;
use FusionInventory::Agent::Storage;
use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Job;

# We need to keep a X.X.X revision format
# https://rt.cpan.org/Public/Bug/Display.html?id=61282
our $VERSION = '3.0.0';

our $VERSION_STRING =
    "FusionInventory unified agent for UNIX, Linux and MacOSX ($VERSION)";
our $AGENT_STRING =
    "FusionInventory-Agent_v$VERSION";

sub new {
    my ($class, %params) = @_;

    my $self = {
        confdir => $params{confdir},
        datadir => $params{datadir},
        vardir  => $params{vardir},
    };
    bless $self, $class;

    my $config = FusionInventory::Agent::Config->new(
        directory => $params{confdir},
        file      => $params{conffile},
    );
    $self->{config} = $config;

    my $logger = FusionInventory::Agent::Logger->new(
        $config->getBlockValues('logger'),
        backends => [ $config->getValues('logger.backends') ],
        debug    => $params{debug}
    );
    $self->{logger} = $logger;

    if ($REAL_USER_ID != 0) {
        $logger->info("You should run this program as super-user.");
    }

    $logger->debug("Configuration directory: $self->{confdir}");
    $logger->debug("Data directory: $self->{datadir}");
    $logger->debug("Storage directory: $self->{vardir}");

    # restore state
    my $storage = FusionInventory::Agent::Storage->new(
        logger    => $logger,
        directory => $self->{vardir}
    );
    my $dirty;
    my $data = $storage->restore();

    if ($data->{deviceid}) {
        $self->{deviceid} = $data->{deviceid};
    } else {
        $self->{deviceid} = getDeviceId();
        $dirty = 1;
    }

    if ($data->{token}) {
        $self->{token} = $data->{token};
    } else {
        $self->{token} = getRandomToken();
        $dirty = 1;
    }

    if ($dirty) {
        $storage->save(
            data => {
                deviceid => $self->{deviceid},
                token    => $self->{token}
            }
        );
    }

    $logger->debug("FusionInventory Agent initialised");

    return $self;
}

sub getDeviceId {
    my $hostname = _getHostname();
    my ($year, $month , $day, $hour, $min, $sec) =
        (localtime(time()))[5,4,3,2,1,0];
    return sprintf "%s-%02d-%02d-%02d-%02d-%02d-%02d",
        $hostname, ($year + 1900), ($month + 1), $day, $hour, $min, $sec;
}

sub getRandomToken {
    my @chars = ('A'..'Z');
    return join('', map { $chars[rand @chars] } 1..8);
}

sub createTask {
    my ($self, %params) = @_;

    my %config;

    # start from configuration file if an id was given
    if ($params{id}) {
        %config = $self->{config}->getBlockValues($params{id});
        die "No such task '$params{id}' in configuration" unless %config;
    } else {
        $params{id} = 'anonymous';
    }

    # add additional parameters
    foreach my $key (keys %params) {
        $config{$key} = $params{$key};
    }

    my $type = $config{type};
    die "No type for task '$params{id}'" unless $type;

    my $class = 'FusionInventory::Agent::Task::' . ucfirst($type);
    die "Non-existing type $type for task '$params{id}'"
        unless $class->require();
    die "Invalid type $type for task '$params{id}'"
        unless $class->isa('FusionInventory::Agent::Task');

    return $class->new(id => $params{id}, %config);
}

sub createTarget {
    my ($self, %params) = @_;

    my %config;

    # start from configuration file if an id was given
    if ($params{id}) {
        %config = $self->{config}->getBlockValues($params{id});
        die "No such target '$params{id}' in configuration" unless %config;
    } else {
        $params{id} = 'anonymous';
    }

    # add additional parameters
    foreach my $key (keys %params) {
        $config{$key} = $params{$key};
    }
    
    my $type = $config{type};
    die "No type for target '$params{id}'" unless $type;

    my $class = 'FusionInventory::Agent::Target::' . ucfirst($type);
    die "Non-existing type $type for target '$params{id}'"
        unless $class->require();
    die "Invalid type $type for target '$params{id}'"
        unless $class->isa('FusionInventory::Agent::Target');

    return $class->new(id => $params{id}, %config);
}

sub createAllJobs {
    my ($self) = @_;

    return
        map { $self->createJob(id => $_) }
        $self->{config}->getValues('global.jobs');
}

sub createJob {
    my ($self, %params) = @_;

    my %config;

    if ($params{id}) {
        %config = $self->{config}->getBlockValues($params{id});
        die "No such job '$params{id}' in configuration" unless %config;
    } else {
        $params{id} = 'anonymous';
        %config = (
            task   => 'anonymous',
            target => 'anonymous',
        );
    }

    return FusionInventory::Agent::Job->new(
        id     => $params{id},
        logger => $self->{logger},
        vardir => $self->{vardir},
        %config
    );
}

sub getToken {
    my ($self) = @_;
    return $self->{token};
}

sub getJobs {
    my ($self) = @_;
    return @{$self->{jobs}};
}

sub addJob {
    my ($self, $job) = @_;
    push @{$self->{jobs}}, $job;
}

sub resetToken {
    my ($self) = @_;
    $self->{token} = _computeNewToken();
}

sub runAllJobs {
    my ($self) = @_;

    $self->runJob($_) foreach (@{$self->{jobs}});
}

sub runJob {
    my ($self, $job) = @_;

    my $logger = $self->{logger};

    my $task    = $self->getTaskFromConfiguration($job->{task});
    my $target  = $self->getTargetFromConfiguration($job->{target});
    my $storage = $job->getStorage();

    return unless $task and $target;

    $logger->info(
        sprintf(
            "Running task '%s' for target '%s' as job '%s'",
            $task->{id}, $target->{id}, $job->{id}
        )
    );

    $self->runTask(task => $task, target => $target, storage => $storage);
}

sub runTask {
    my ($self, %params) = @_;

    $params{task}->run(
        target   => $params{target},
        storage  => $params{storage},
        logger   => $self->{logger},
        confdir  => $self->{confdir},
        datadir  => $self->{datadir},
        deviceid => $self->{deviceid},
        token    => $self->{token},
    );
}

sub getHostname {

    # use hostname directly under Unix
    return hostname() if $OSNAME ne 'MSWin32';

    # otherwise, use Win32 API
    eval {
        require Encode;
        require Win32::API;
        Encode->import();

        my $getComputerName = Win32::API->new(
            "kernel32", "GetComputerNameExW", ["I", "P", "P"], "N"
        );
        my $lpBuffer = "\x00" x 1024;
        my $N = 1024; #pack ("c4", 160,0,0,0);

        $getComputerName->Call(3, $lpBuffer, $N);

        # GetComputerNameExW returns the string in UTF16, we have to change
        # it to UTF8
        return encode(
            "UTF-8", substr(decode("UCS-2le", $lpBuffer), 0, ord $N)
        );
    };
}

1;
__END__

=head1 NAME

FusionInventory::Agent - Fusion Inventory agent

=head1 DESCRIPTION

This is Fusion Inventory Agent, a generic and multi-platform agent.

=head1 CONCEPTS

A B<task> is a specific work to execute. Each task type is implemented as an
agent plugin, making it versatile and easily extensible. Two task types
are available by default, local inventory and wake on lan, and others are
available as distinct software release.

A B<target> is the destination for the result of a B<task> execution. They are
different types of targets available, some of them local to the machine
running the agent (directory, stdout), some of them remote (GLPI or OCS
servers).

A B<job> is the combination of a given B<task> and a given B<target>, with
a period attribute determining how often it has to be executed.

Each of these object is defined in the configuration file as a section, with
the name of the section being the identifier of the object. For instance, the 
following configuration part defines a task called I<my_inventory>, of type
inventory, with all optional items list configured:

    [my_inventory]
    type = inventory
    software = 1
    printers = 1
    environment = 1

=head1 CHANGES

FusionInventory 3.0 introduces quite a lot of changes in program architecture
and usage. Here is a short resume.

There is no more 'fusioninventory' monolithic executable, but two distinct ones: 

=over

=item * B<fusioninventory-worker>

A programm executing a single job and termining immediatly

=item * B<fusioninventory-server>

A program running in background, executing jobs according to its schedule or
to external sollicitations.

=back

There is no more a complete equivalence between configuration file and command
line options, but different sets of options for configuration file and command
line for both executables.

There is no more task-specific or target-specific parameters available as
command line options, they have to be passed using respectively B<--task-param>
and B<--target-param> options.

The configuration file uses a structured INI-style format, with sections delimited
by bracketed headers ([section]).
