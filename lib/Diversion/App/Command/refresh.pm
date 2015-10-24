package Diversion::App::Command::refresh;
use v5.18;
use Diversion::App -command;

use IO::All;
use List::Util qw(shuffle);

use Diversion::FeedArchiver;
use Parallel::ForkManager;

sub execute {
    my ($self, $opt, $args) = @_;

    my $feed_list_file = $args->[0] or die "Missing a filename in ard";

    my @feeds = io($feed_list_file)->chomp->getlines;

    my $forkman = Parallel::ForkManager->new(4);
    for (shuffle grep { /^https?:/ } @feeds) {
        $forkman->start and next;
        my $feed_archiver = Diversion::FeedArchiver->new;
        say "[pid=$$] Processing $_";
        eval {
            $feed_archiver->fetch_then_archive( $_ );
            1;
        } or do {
            say STDERR $@;
        };
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

1;
