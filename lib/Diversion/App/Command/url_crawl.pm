package Diversion::App::Command::url_crawl;
# ABSTRACT: crawl given urls
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';
use Log::Any qw($log);

use Mojo::DOM;
use List::Util 'shuffle';
use List::MoreUtils 'uniq';
use MCE::Stream;

sub opt_spec {
    return (
        ["workers=n", "number of worker processes.", { default => 4 }],
        ["only-same-host", "Only relative URLs"],
    )
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $url_archiver = Diversion::UrlArchiver->new;

    mce_stream sub {
        $0 = "diversion - url_crawl - $_";
        my $response = $url_archiver->get_remote($_) or return;
        $log->debug("[$$] CRAWL $response->{status} $_\n");
    }, sub {
        my $u = $_;

        my @links;
        $0 = "diversion - url_crawl - $u";
        my $response = $url_archiver->get_remote($u) or return;
        $log->debug("[$$] CRAWL $response->{status} $u\n");
        if ($response && $response->{success}) {
            push @links, @{find_links($response, $u, $opt->{only_same_host})};
        }
        return @links;
    }, $args;
}

sub find_links {
    my ($response, $uri, $only_same_host) = @_;
    return [] unless ( ($response->{headers}{"content-type"} //"") =~ m{^ text/html }x );

    my $links = [];

    my $base_uri = URI->new($uri);
    my $base_host = $base_uri->host;
    my $dom = Mojo::DOM->new($response->{content});

    my $x = $dom->find("a[href]")->grep(
        sub {
            return defined( $_->attr("href") );
        }
    )->map(
        sub {
            my $v = $_->attr("href");
            $v =~ s/#.*$//;
            my $u = URI->new_abs($v, $base_uri);
            return $u if !$only_same_host || ($u->can("host") && ($u->host eq $base_host));
            return ();
        }
    )->grep(
        sub {
            $_->scheme =~ /\A https? \z/x;
        }
    );

    @$links = $x->map(sub { "$_" })->uniq->each;
    return $links;
}

no Moo;
1;
