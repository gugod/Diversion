package Diversion::App::Command::url_archive;
use v5.18;
use Diversion::App -command;
use Diversion::UrlArchiver;
use Parallel::ForkManager;

sub execute {
    my ($self, $opt, $args) = @_;

    my $forkman = Parallel::ForkManager->new(4);
    my $o = Diversion::UrlArchiver->new;
    for my $url (@$args) {
        $forkman->start and next;
        $o->get_remote($url);
        say "[$$] ARCHIVE $url";
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

1;
