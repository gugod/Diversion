package Diversion::App::Command::url_archive;
use v5.18;
use Diversion::App -command;
use Diversion::UrlArchiver;

sub execute {
    my ($self, $opt, $args) = @_;

    my $o = Diversion::UrlArchiver->new;
    for my $url (@$args) {
        $o->get_remote($url);
    }
}

1;
