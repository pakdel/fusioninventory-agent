package FusionInventory::Test::MockSystem;

use strict;
use warnings;

use Hook::LexWrap;
use FusionInventory::Agent::Tools;

sub new {
    my ($class, %params) = @_;

    # compute a list of available executables
    my %executables =
        map { $_ => 1 }
        map { (split (' ', $_))[0] }
        keys %{$params{commands}};

    my $self = {};
    bless $self, $class;

    wrap 'FusionInventory::Agent::Tools::getFileHandle', pre => sub {
        # scan arguments
        foreach my $i (0 .. $#_) {
            next unless $_[$i] && $_[$i + 1];

            if ($_[$i] eq 'command') {
                my $wanted = $_[$i + 1];
                print STDERR "command '$wanted' wanted\n";

                # check if a mock output exists
                my $replacement = $params{commands}->{$wanted};
                next unless $replacement;

                # alter original arguments
                $_[$i] = 'file';
                $_[$i + 1] = $replacement;
                print STDERR
                    "command '$wanted' replaced with file '$replacement'\n";
            }

            if ($_[$i] eq 'file') {
                my $wanted = $_[$i + 1];
                print STDERR "file '$wanted' wanted\n";

                # check if a mock content exists
                my $replacement = $params{files}->{$wanted};
                next unless $replacement;

                # alter original arguments
                $_[$i + 1] = $replacement;
                print STDERR
                    "file '$wanted' replaced with file '$replacement'\n";
            }
        }
    };

    wrap 'FusionInventory::Agent::Tools::can_run', pre => sub {
        my $wanted = $_[0];
        print STDERR "command '$wanted' availability tested\n";

        # short-circuit original function if needed
        return unless $executables{$wanted};
        $_[1] = 1;
        print STDERR "command '$wanted' availability asserted\n";
    };

    return $self;
}

1