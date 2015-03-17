package Diversion::App::Command::refresh;
use v5.18;
use Diversion::App -command;

use IO::All;
use List::Util qw(shuffle);

use Diversion::FeedArchiver;

sub execute {
    my ($self, $opt, $args) = @_;

    my $feed_url = $args->[0] or die "Missing URL in arg";

    my @feeds;
    if (-f $feed_url) {
        @feeds = grep { s/\s//g; $_ } io($feed_url)->chomp->getlines;
    } else {
        push @feeds, $feed_url;
    }

    my $feed_archiver = Diversion::FeedArchiver->new;
    for (shuffle @feeds) {
        say "Processing $_";
        eval {
            $feed_archiver->fetch_then_archive( $_ );
            1;
        } or do {
            say STDERR $@;
        };
    }

}

1;
