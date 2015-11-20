package Diversion::App::Command::url_crawl;
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';
use Log::Any qw($log);

use List::Util 'shuffle';
use List::MoreUtils 'uniq';
use Parallel::ForkManager;

sub opt_spec {
    return (
        ["workers=n", "number of worker processes.", { default => 4 }]
    )
}

require Data::Dumper;
sub execute {
    my ($self, $opt, $args) = @_;
    my $url_archiver = Diversion::UrlArchiver->new;

    my @uris;
    my $forkman = Parallel::ForkManager->new( $opt->{workers} );
    $forkman->run_on_finish(
        sub {
            my $data = pop;
            if ($data) {
                push @uris, @$data;
            }
        }
    );

    for my $u (@$args) {
        $forkman->start and next;
        $0 = "diversion - url_crawl - $u";
        my $response = $url_archiver->get_remote($u);
        $log->debug("[$$] CRAWL $response->{status} $u\n");
        my $links = [];
        if ($response && $response->{success}) {
            $links = find_links($response, $u);
        }
        $forkman->finish(0, $links);
    }
    $forkman->wait_all_children;

    for my $u (shuffle uniq @uris) {
        $forkman->start and next;
        $0 = "diversion - url_crawl - $u";
        my $response = $url_archiver->get_remote($u);
        $log->debug("[$$] CRAWL $response->{status} $u\n");
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

sub find_links {
    my ($response, $uri) = @_;
    return [] unless ( ($response->{headers}{"content-type"} //"") =~ m{^ text/html }x );

    my $links = [];

    my $base_uri = URI->new($uri);
    my $dom = Mojo::DOM->new($response->{content});

    my $x = $dom->find("a[href]")->grep(
        sub {
            return defined( $_->attr("href") );
        }
    )->map(
        sub {
            my $v = $_->attr("href");
            $v =~ s/#.*$//;
            return URI->new_abs($v, $base_uri);
        }
    )->grep(
        sub {
            $_->scheme =~ /\A https? \z/x;
        }
    );

    @$links = $x->map(sub { "$_" })->uniq->each;
    return $links;
}

1;
