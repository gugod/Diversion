package Diversion::App::Command::archive_feed_entry;
use v5.18;
use Diversion::App -command;

use Moo;
with 'Diversion::Db';

use List::Util qw( shuffle );

use Log::Any qw($log);

use Parallel::ForkManager;
use Diversion::UrlArchiver;
use Diversion::FeedArchiver;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $rows = $self->db_open(
        feed => sub {
            my ($dbh) = @_;
            return $dbh->selectall_arrayref('SELECT uri FROM feed_entries WHERE uri LIKE "http%" AND created_at > ?', {Slice=>{}}, (time - $opt->{ago}));
        }
    );

    my $forkman = Parallel::ForkManager->new(4);
    my $o = Diversion::UrlArchiver->new;
    for my $row (shuffle @$rows) {
        unless ($o->get_local($row->{uri})) {
            $forkman->start and next;
            $o->get($row->{uri});
            $log->info("[$$] STORE $row->{uri}\n");
            $forkman->finish;
        }
    }
    $forkman->wait_all_children;
}

1;
