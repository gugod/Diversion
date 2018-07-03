package Diversion::App::Command::feed_refresh;
# ABSTRACT: Refresh (re-download) feed URLs
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';

use IO::All;

use Diversion::FeedArchiver;
use Diversion::FeedUrlIterator;
use Diversion::FeedArchiveIterator;

use Parallel::ForkManager;

sub opt_spec {
    return (
        ["workers=n", "number of worker processes.", { default => 4 }],
        ["harvest", "Harvest new feed URLs from URL Archive"]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $iter = $opt->{harvest} ? Diversion::FeedUrlIterator->new : Diversion::FeedArchiveIterator->new;

    my $forkman = Parallel::ForkManager->new($opt->{workers});

    while (my $row = $iter->next) {
        my $u = $row->{uri};
        $forkman->start and next;
        my $feed_archiver = Diversion::FeedArchiver->new;
        say "[pid=$$] Processing $u";
        eval {
            $feed_archiver->fetch_then_archive( $u );
            1;
        } or do {
            say STDERR $@;
        };
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

no Moo;
1;
