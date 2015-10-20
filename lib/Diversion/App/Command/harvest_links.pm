package Diversion::App::Command::harvest_links;
use v5.18;
use Diversion::App -command;

use List::Util qw( shuffle );

use Log::Any qw($log);
use Mojo::DOM;

use Diversion::UrlArchiver;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $url_archiver = Diversion::UrlArchiver->new;
    my $dbh = $url_archiver->dbh_index;
    my $rows = $dbh->selectall_arrayref('SELECT distinct uri,sha1_digest FROM uri_archive WHERE created_at > ?', {}, (time - $opt->{ago}));
    for my $row (shuffle @$rows) {
        my ($uri, $sha1_digest) = @$row[0,1];
        my $response = $url_archiver->get_local($uri);
        if ($response->{success}) {
            my $links = find_links($response);
            for my $u (@$links) {
                unless ($url_archiver->get_local($u)) {
                    $url_archiver->get_remote($u);
                    $log->info("HARVEST $u\n");
                }
            }
        }
    }
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
