package Diversion::App::Command::harvest_links;
use v5.18;
use Diversion::App -command;

use List::Util qw( shuffle );
use List::MoreUtils qw( uniq );

use Log::Any qw($log);
use Mojo::DOM;
use Parallel::ForkManager;

use Diversion::UrlArchiver;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }]
    )
}

sub harvest_these_links {
    my ($forkman, $url_archiver, $links, $substr_constraint) = @_;

    my @todo = shuffle uniq grep {
        my $u = $_;
        (grep { index($u, $_) > 0 } @$substr_constraint) > 0;
    } @$links;

    for my $u (@todo) {
        next if $url_archiver->get_local($u);
        $forkman->start and next;
        $0 = "$0 - $u";
        $url_archiver->get_remote($u);
        $log->info("[$$] HARVEST $u\n");
        $forkman->finish;
    }
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $url_archiver = Diversion::UrlArchiver->new;

    my $rows = [];
    my $dbh = $url_archiver->dbh_index;
    if (@$args) {
        for (@$args) {
            push @$rows, @{ $dbh->selectall_arrayref('SELECT distinct uri FROM uri_archive WHERE created_at > ? AND uri LIKE ?', {}, (time - $opt->{ago}), '%' . $_ . '%' ) };
        }
    } else {
        $rows = $dbh->selectall_arrayref('SELECT distinct uri FROM uri_archive WHERE created_at > ?', {}, (time - $opt->{ago}));
    }
    $dbh->disconnect;

    my $forkman = Parallel::ForkManager->new(4);
    my @links;
    for my $row (shuffle @$rows) {
        my ($uri) = $row->[0];
        my $response = $url_archiver->get_local($uri);
        if ($response->{success}) {
            push @links, @{ find_links($response) };
        }

        if (@links > 1000) {
            harvest_these_links($forkman, $url_archiver, \@links, $args);
            @links = ();
        }
    }

    harvest_these_links($forkman, $url_archiver, \@links, $args);
    @links = ();
    $forkman->wait_all_children;
}

sub find_links {
    my ($response) = @_;
    return [] unless ( $response->{headers}{"content-type"} =~ m{^ text/html }x );

    my $links = [];

    my $dom = Mojo::DOM->new($response->{content});
    @$links = $dom->find("a[href^=http]")->map(
        sub {
            $_->attr("href");
        }
    )->uniq->each;

    return $links;
}

1;
