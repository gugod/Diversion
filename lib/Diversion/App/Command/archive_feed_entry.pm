package Diversion::App::Command::archive_feed_entry;
use v5.18;
use Diversion::App -command;

use IO::All;
use JSON::PP;
use DateTime::Format::RSS;
use List::UtilsBy qw( rev_nsort_by uniq_by );
use List::Util qw( shuffle );
use Text::Xslate;

use File::ShareDir;
use Log::Any qw($log);

use Diversion::UrlArchiver;
use Diversion::FeedArchiver;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $feed_archiver = Diversion::FeedArchiver->new;
    my $dbh = $feed_archiver->dbh_index;
    my $rows = $dbh->selectall_arrayref('SELECT uri FROM feed_entries WHERE created_at > ?', {Slice=>{}}, (time - $opt->{ago}));
    my $o = Diversion::UrlArchiver->new;
    for my $row (shuffle @$rows) {
        $o->get($row->{uri}) unless $o->get_local($row->{uri});
    }
}

1;
