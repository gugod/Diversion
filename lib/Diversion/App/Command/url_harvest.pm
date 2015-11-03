package Diversion::App::Command::url_harvest;
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Db';

use List::Util qw(shuffle);
use List::MoreUtils qw( uniq );

use Log::Any qw($log);
use URI;
use Mojo::DOM;
use Parallel::ForkManager;

use Diversion::UrlArchiver;
use Diversion::UrlArchiveIterator;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }],
        ["workers=n", "number of worker processes.", { default => 4 }]
    )
}

sub harvest_these_uris {
    my ($forkman, $url_archiver, $uris) = @_;
    my $groups = group_by_host($uris);
    my $orig0 = $0;
    for (values %$groups) {
        $forkman->start and next;
        for my $u (@$_) {
            $0 = "diversion url_harvest - $u";
            next if $url_archiver->get_local($u);
            my $res = $url_archiver->get_remote($u);
            $log->info("[$$] HARVEST $res->{status} $u\n");
            sleep(1);
        }
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $url_archiver = Diversion::UrlArchiver->new;

    my $rows = [];

    my $forkman = Parallel::ForkManager->new( $opt->{workers} );

    my @where_clause = (" created_at > ? ",  (time - $opt->{ago}));
    if (@$args) {
        $where_clause[0] .= " AND (" . join(" OR ", ("instr(uri,?)")x@$args) . ")";
        push @where_clause, @$args;
    }

    my $iter = Diversion::UrlArchiveIterator->new(
        sql_where_clause => \@where_clause,
        sql_order_clause => " created_at DESC"
    );

    my @links;
    while (my $row = $iter->next()) {
        my $uri = $row->{uri};

        my $response = $url_archiver->get_local($uri);
        next unless $response && $response->{success};

        push @links, @{find_links($response, $uri, $args)};
        if (@links > 9999) {
            @links = uniq(@links);
            harvest_these_uris($forkman, $url_archiver, \@links);
            @links = ();
        }
    }

    if (@links) {
        @links = uniq(@links);
        harvest_these_uris($url_archiver, \@links);
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

    if (defined($substr_constraint) && @$substr_constraint) {
        $x = $x->grep(
            sub {
                my $uri = $_;
                (grep { index($uri->host, $_) >= 0 } @$substr_constraint) > 0;
            }
        );
    }

    @$links = $x->map(sub { "$_" })->uniq->each;
    return $links;
}

sub group_by_host {
    my ($uris) = @_;
    my %buckets;
    for (@$uris) {
        my ($host) = $_ =~ m{\A https?:// ([^/]+) (?: /|$ )}x;
        if ($host) {
            push @{ $buckets{$host} }, $_;
        } else {
            say STDERR "Unknown protocal: $_";
        }
    }
    return \%buckets;
}

1;
