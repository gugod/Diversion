package Diversion::App::Command::archive_feed_entry;
#ABSTRACT: Archive all entries from all discovered feeds.
use v5.18;
use Diversion::App -command;

use Moo;
with 'Diversion::Service';

use List::Util qw( shuffle );

use Log::Any qw($log);

use Parallel::ForkManager;
use Diversion::UrlArchiver;
use Diversion::FeedArchiver;
use JSON;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }],
        ["workers=n", "number of worker processes.", { default => 4 }],
   )
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $rows = $self->db_open(
        feed => sub {
            my ($dbh) = @_;
            return $dbh->selectall_arrayref('SELECT uri,sha1_digest FROM feed_archive WHERE uri LIKE "http%" AND created_at > ?', {Slice=>{}}, (time - $opt->{ago}));
        }
    );

    my $JSON = JSON->new->utf8;
    my $forkman = Parallel::ForkManager->new( $opt->{workers} );
    my $o = Diversion::UrlArchiver->new;
    my %urls;
    for my $row (shuffle @$rows) {
        my $feed = $JSON->decode( $self->blob_store->get( $row->{sha1_digest} ) );
        for my $entry (@{$feed->{entry}}) {
            my $uri = $entry->{link};
            next unless $uri && $uri =~ /^https?:/;
            $urls{$uri} = 1;
        }
    }
    for my $uri (keys %urls) {
        $log->info("[$$] STORE $uri\n");
        unless ($o->get_local($uri)) {
            $forkman->start and next;
            $o->get($uri);
            $log->info("[$$] STORE $uri\n");
            $forkman->finish;
        }
    }
    $forkman->wait_all_children;
}

no Moo;
1;
