package Diversion::App::Command::archive_opml_links;
use v5.18;
use Diversion::App -command;
use Diversion::FeedArchiver;

use Parallel::ForkManager;
use Log::Any qw($log);
use XML::XPath;
use List::MoreUtils 'uniq';

sub opt_spec {
    return (
        ["workers=n", "number of worker processes.", { default => 4 }]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;

    my @feeds;
    for my $opml_file (@$args) {
        my $xp = XML::XPath->new(filename => $opml_file);
        my $resultset = $xp->find('//outline[@xmlUrl]');
        for my $node ($resultset->get_nodelist) {
            push @feeds, $node->getAttribute("xmlUrl");
        }
    }

    my $forkman = Parallel::ForkManager->new($opt->{workers});
    for (uniq grep { /^https?:/ } @feeds) {
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
