package Diversion::App::Command::url_refresh;
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::AppRole';

use Diversion::UrlArchiver;
use Diversion::UrlArchiveIterator;

use Parallel::ForkManager;

sub execute {
    my ($self, $opt, $args) = @_;

    my $uri = "";
    my $url_archiver = Diversion::UrlArchiver->new;
    my $iter = Diversion::UrlArchiveIterator->new();
    while (my $row = $iter->next) {
        if ($uri ne $row->{uri}) {
            $uri = $row->{uri};
            if (@$args) {
                my $matched = 0;
                my $re = "(" . join("|", map { qr{\Q$_\E} } @$args) . ")";
                next unless $uri =~ m{$re};
            }

            say $uri;
            $url_archiver->get_remote($uri);
        }
    }
}

1;
