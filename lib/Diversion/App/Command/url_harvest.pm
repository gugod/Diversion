package Diversion::App::Command::url_harvest;
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Db';

use List::Util qw( shuffle );
use List::MoreUtils qw( uniq );

use Log::Any qw($log);
use URI;
use Mojo::DOM;
use Parallel::ForkManager;

use Diversion::UrlArchiver;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }]
    )
}

sub harvest_these_links {
    my ($url_archiver, $links) = @_;

    for my $u (shuffle @$links) {
        next if $url_archiver->get_local($u);
        $0 = "$0 - $u";
        $url_archiver->get_remote($u);
        $log->info("[$$] HARVEST $u\n");
    }
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $url_archiver = Diversion::UrlArchiver->new;

    my $rows = [];
    $self->db_open(
        url => sub {
            my ($dbh) = @_;
            if (@$args) {
                for (@$args) {
                    push @$rows, @{ $dbh->selectall_arrayref('SELECT distinct uri FROM uri_archive WHERE created_at > ? AND uri LIKE ?', {}, (time - $opt->{ago}), '%' . $_ . '%' ) };
                }
            } else {
                $rows = $dbh->selectall_arrayref('SELECT distinct uri FROM uri_archive WHERE created_at > ?', {}, (time - $opt->{ago}));
            }
            return;
        }
    );

    my $forkman = Parallel::ForkManager->new(4);
    my @links;
    for my $row (shuffle @$rows)  {
        my ($uri) = $row->[0];
        my $response = $url_archiver->get_local($uri);
        if ($response->{success}) {
            push @links, @{ find_links($response, $uri, $args) };
        }

        if (@links > 1000) {
            $forkman->start and next;
            harvest_these_links($url_archiver, \@links);
            $forkman->finish;
            @links = ();
        }
    }

    if (@links) {
        unless ($forkman->start) {
            harvest_these_links($url_archiver, \@links);
            $forkman->finish;
        }
        @links = ();
    }

    $forkman->wait_all_children;
}

sub find_links {
    my ($response, $uri, $substr_constraint) = @_;
    return [] unless ( ($response->{headers}{"content-type"} //"") =~ m{^ text/html }x );

    my $links = [];

    my $base_uri = URI->new($uri);
    my $dom = Mojo::DOM->new($response->{content});
    @$links = $dom->find("a[href]")->grep(
        sub {
            my $v = $_->attr("href");
            return defined($v);
        }
    )->map(
        sub {
            my $v = $_->attr("href");
            return URI->new_abs($v, $base_uri);
        }
    )->grep(
        sub {
            $_->scheme =~ /\A https? \z/x;
        }
    )->map(sub { "$_" })->uniq->each;

    if (defined($substr_constraint) && @$substr_constraint) {
        @$links = grep {
            my $u = $_;
            (grep { index($u, $_) >= 0 } @$substr_constraint) > 0;
        } @$links;
    }

    return $links;
}

1;
