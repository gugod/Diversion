package Diversion::App::Command::url_refresh;
# ABSTRACT: re-download content of urls.
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';

use Diversion::UrlArchiver;
use Diversion::UrlArchiveIterator;

use Parallel::ForkManager;

sub execute {
    my ($self, $opt, $args) = @_;

    my $uri = "";
    my $url_archiver = Diversion::UrlArchiver->new();
    my $iter = Diversion::UrlArchiveIterator->new( sql_order_clause => " uri " );

    my $re;
    if (@$args) {
        $re = "(" . join("|", map { qr{\Q$_\E} } @$args) . ")";
    }

    my $forkman = Parallel::ForkManager->new( 4 );

    while (my $row = $iter->next) {
        next unless $uri ne $row->{uri};
        $uri = $row->{uri};
        next unless !$re || $uri =~ m{$re};

        $forkman->start and next;
        if (my $res = $url_archiver->get_remote($uri)) {
            say "[$$] $res->{status} $uri";
        }
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

no Moo;
1;
