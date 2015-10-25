package Diversion::App::Command::feed_refresh;
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::AppRole';

use IO::All;
use List::Util qw(shuffle);
use List::MoreUtils qw(uniq);

use Diversion::FeedArchiver;
use Diversion::UrlArchiveIterator;

use Parallel::ForkManager;

sub execute {
    my ($self, $opt, $args) = @_;

    my $feeds = $self->find_feeds();

    my $forkman = Parallel::ForkManager->new(4);
    for (shuffle @$feeds) {
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

sub find_feeds {
    my ($self) = @_;
    my $feeds = [];

    my $last = "";
    my $JSON = JSON->new;
    my $iter = Diversion::UrlArchiveIterator->new();
    while (my $row = $iter->next) {
        my $blob = $self->blob_store->get($row->{sha1_digest});
        my $res = $JSON->decode( $blob );

        next unless $row->{uri} =~ /^https?:/ && defined($res->{headers}{"content-type"}) && $res->{headers}{"content-type"} =~ /atom|rss/;
        if ($last ne $row->{uri}) {
            $last = $row->{uri};
            push @$feeds, $last;
            say $last;
        }
    }
    push @$feeds, $last;
    @$feeds = uniq(@$feeds);
    return $feeds;
}

1;
