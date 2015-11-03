package Diversion::App::Command::url_archive;
use v5.18;
use Diversion::App -command;
use Diversion::UrlArchiver;
use Parallel::ForkManager;
use Log::Any qw($log);

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
        $log->info("[$$] ARCHIVE $res->{status} $url\n");
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

1;
