package Diversion::App::Command::url_archive;
use v5.18;
use Diversion::App -command;
use Diversion::UrlArchiver;
use Parallel::ForkManager;

sub opt_spec {
    return (
        ["workers=n", "number of worker processes.", { default => 4 }]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $forkman = Parallel::ForkManager->new($opt->{workers});
    my $o = Diversion::UrlArchiver->new;
    for my $url (@$args) {
        $forkman->start and next;
        my $res = $o->get_remote($url);
        say "[$$] ARCHIVE $res->{status} $url";
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

1;
