package FusionInventory::Agent::Logger;

use strict;
use warnings;

use Carp;
use Config;
use English qw(-no_match_vars);
use UNIVERSAL::require;

BEGIN {
    # threads and threads::shared must be load before
    # $lock is initialized
    if ($Config{usethreads}) {
        eval {
            require threads;
            require threads::shared;
        };
        if ($EVAL_ERROR) {
            print "[error]Failed to use threads!\n"; 
        }
    }
}

my $lock :shared;

sub new {
    my ($class, $params) = @_;

    my $self = {
        debug => $params->{debug},
    };
    bless $self, $class;

    my %backends;
    foreach my $backend (split(/,/, $params->{config}->{logger})) {
	next if $backends{$backend};
        my $package = "FusionInventory::Agent::Logger::$backend";
        $package->require();
        if ($EVAL_ERROR) {
            print STDERR
                "Failed to load Logger backend $backend: ($EVAL_ERROR)\n";
            next;
        }
	$backends{$backend} = 1;

        $self->debug("Logger backend $backend initialised");
        push
            @{$self->{backends}},
            $package->new($params);
    }

    $self->debug($FusionInventory::Agent::VERSION_STRING);

    return $self;
}

sub log {
    my ($self, $args) = @_;

    # levels: info, debug, warn, fault
    my $level = $args->{level};
    my $message = $args->{message};

    return if ($level =~ /^debug$/ && !($self->{debug}));

    chomp($message);
    $level = 'info' unless $level;

    foreach (@{$self->{backends}}) {
        $_->addMsg ({
            level => $level,
            message => $message
        });
    }
    confess if $level =~ /^fault$/; # Die with a backtace 
}

sub debug {
    my ($self, $msg) = @_;

    lock($lock);
    $self->log({ level => 'debug', message => $msg});
}

sub info {
    my ($self, $msg) = @_;

    lock($lock);
    $self->log({ level => 'info', message => $msg});
}

sub error {
    my ($self, $msg) = @_;

    lock($lock);
    $self->log({ level => 'error', message => $msg});
}

sub fault {
    my ($self, $msg) = @_;

    lock($lock);
    $self->log({ level => 'fault', message => $msg});
}

sub user {
    my ($self, $msg) = @_;

    lock($lock);
    $self->log({ level => 'user', message => $msg});
}

1;