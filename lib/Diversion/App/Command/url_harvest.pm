package Diversion::App::Command::url_harvest;
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Db';

use List::Util qw(shuffle);
use List::MoreUtils qw( uniq );
use IO::Handle;
use Digest::MD4 qw( md4 );

use Log::Any qw($log);
use URI;
use Mojo::DOM;

use Diversion::UrlArchiver;
use Diversion::UrlArchiveIterator;

sub opt_spec {
    return (
        ["limit=i", "Harvest upto to this many amount of URLs", { default => 3600 }],
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }],
        ["workers=n", "number of worker processes.", { default => 4 }]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;
    if (@$args) {
        return $self->execute_one_worker_per_constraint($opt, $args);
    } else {
        return $self->execute_balance($opt, []);
    }
}

sub execute_one_worker_per_constraint {
    my ($self, $opt, $args) = @_;

    my @kids;
    for (@$args) {
        if (@kids >= $opt->{workers}) {
            my $pid = waitpid(-1,0);
            @kids = grep { $_ != $pid } @kids;
        }
        if (my $kidpid = fork()) {
            push @kids, $kidpid;
        } else {
            $self->process_one_host_constraint($opt->{ago}, $_);
            exit;
        }
    }
    waitpid(-1,0) for @kids;
}

sub execute_balance {
    my ($self, $opt, $args) = @_;
    my $url_archiver = Diversion::UrlArchiver->new;

    my $worker_sub = sub {
        my $io = shift;
        $0 = "diversion url_harvest - WORKER";
        while (my $u = <$io>) {
            chomp($u);
            next if $url_archiver->get_local($u);
            $0 = "diversion url_harvest - $u";
            my $begin_time = time;
            my $res = $url_archiver->get_remote($u);
            my $spent_time = time - $begin_time;
            $log->info("[$$] HARVEST $res->{status} (${spent_time}s) $u\n");
            sleep(1);
            $0 = "diversion url_harvest - (IDLE)";
        }
        return 1;
    };
    my @workers = map { fork_worker($worker_sub) } 1 .. $opt->{workers};

    my @where_clause = (" created_at > ? ",  (time - $opt->{ago}));

    my $iter = Diversion::UrlArchiveIterator->new(
        sql_where_clause => \@where_clause,
        sql_order_clause => "sha1_digest ASC",
    );

    my $harvested_count = 0;
    my @links;
    while ((my $row = $iter->next()) && ($harvested_count < $opt->{limit}) ) {
        my $uri = $row->{uri};

        my $response = $url_archiver->get_local($uri);
        next unless $response && $response->{success};

        my @uris = @{find_links($response, $uri, $args)};
        for my $u (@uris) {
            next if $url_archiver->get_local($u);
            my ($host) = $u =~ m{\A https?:// ([^/]+) (?: /|$ )}x;
            if (!$host) {
                say STDERR "Weird URI: $u";
                next;
            }
            my $i = unpack("I*",md4($host)) % $opt->{workers};
            my $worker_fh = $workers[$i][1];
            print $worker_fh "$u\n";
            $harvested_count += 1;
        }
    }

    close($_->[1]) for @workers;
    waitpid(-1,0) for 0..$#workers;
}

sub process_one_host_constraint {
    my ($self, $ago, $substr_constraint) = @_;
    my $url_archiver = Diversion::UrlArchiver->new;

    my @where_clause = (" created_at > ? AND instr(uri,?) ", $ago, $substr_constraint);

    my $iter = Diversion::UrlArchiveIterator->new(
        sql_where_clause => \@where_clause,
        sql_order_clause => "sha1_digest ASC",
    );

    my @links;
    while (my $row = $iter->next()) {
        my $uri = $row->{uri};

        my $response = $url_archiver->get_local($uri);
        next unless $response && $response->{success};

        my @uris = @{find_links($response, $uri, [$substr_constraint])};
        for my $u (@uris) {
            my ($host) = $u =~ m{\A https?:// ([^/]+) (?: /|$ )}x;
            if (!$host) {
                say STDERR "Weird URI: $u";
                next;
            }
            next if $url_archiver->get_local($u);

            $0 = "diversion url_harvest - $u";
            my $begin_time = time;
            my $res = $url_archiver->get_remote($u);
            my $spent_time = time - $begin_time;
            $log->info("[$$] HARVEST $res->{status} (${spent_time}s) $u\n");
            sleep(1);
            $0 = "diversion url_harvest - (IDLE)";
        }
    }
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
                $uri->host && ((grep { index($uri->host, $_) >= 0 } @$substr_constraint) > 0);
            }
        );
    }

    @$links = $x->map(sub { "$_" })->uniq->each;
    return $links;
}

sub fork_worker {
    my ($cb) = @_;
    my ($pr,$pw);
    pipe($pr, $pw);

    $pr->autoflush();
    $pw->autoflush();

    if (my $kidpid = fork()) {
        close($pr);
        return [$kidpid, $pw];
    } else {
        close($pw);
        exit $cb->($pr);
    }
}

1;
