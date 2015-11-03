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
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }]
    )
}

sub harvest_these_links {
    my ($forkman, $url_archiver, $links) = @_;

    $links = order_by_round_robin_host($links);
    my $orig0 = $0;
    for my $u (@$links) {
        next if $url_archiver->get_local($u);
        $forkman->start and next;
        $0 = "diversion url_harvest - $u";
        my $res = $url_archiver->get_remote($u);
        $log->info("[$$] HARVEST $res->{status} $u\n");
        $forkman->finish;
    }
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $url_archiver = Diversion::UrlArchiver->new;

    my $rows = [];

    my $forkman = Parallel::ForkManager->new(4);

    my @where_clause = (" created_at > ? ",  (time - $opt->{ago}));
    if (@$args) {
        $where_clause[0] .= " AND (" . join(" OR ", ("instr(uri,?)")x@$args) . ")";
        push @where_clause, @$args;
    }

    my $iter = Diversion::UrlArchiveIterator->new(
        sql_where_clause => \@where_clause,
        sql_order_clause => " created_at DESC, uri DESC "
    );

    my @links;
    while (my $row = $iter->next()) {
        my $uri = $row->{uri};

        my $response = $url_archiver->get_local($uri);
        if ($response->{success}) {
            push @links, grep { ! $url_archiver->get_local($_) } @{find_links($response, $uri, $args)};
        }

        if (@links > 999) {
            @links = uniq(@links);
            harvest_these_links($forkman, $url_archiver, order_by_round_robin_host(\@links));
            @links = ();
        }
    }

    if (@links) {
        unless ($forkman->start) {
            harvest_these_links($url_archiver, order_by_round_robin_host(\@links));
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

sub order_by_round_robin_host {
    my ($uris) = @_;
    my $ret = [];
    my %buckets;
    for (@$uris) {
        my ($host) = $_ =~ m{\A https?:///? ([^/]+) (?: /|$ )}x;
        if ($host) {
            push @{ $buckets{$host} }, $_;
        } else {
            say STDERR "Unknown protocal: $_";
        }
    }
    my @hosts = keys %buckets;
    while (keys %buckets > 0) {
        for my $host (@hosts) {
            next unless exists($buckets{$host});
            push(@$ret, pop(@{$buckets{$host}}));
            delete $buckets{$host} unless @{$buckets{$host}};
        }
    }
    return $ret;
}

1;
