package Diversion::App::Command::feed;
use v5.18;
use Moo;
with 'Diversion::AppRole';
use Diversion::App -command;

use Diversion::FeedUrlIterator;
use JSON::XS;
use URI::Split qw(uri_split);

sub opt_spec {
    return (
    )
}

sub execute {
    my ($self, $opt) = @_;
    my $JSON = JSON::XS->new;
    my $should_load_res = keys %$opt > 0;
    my $last = "";
    my $iter = Diversion::FeedUrlIterator->new();
    my %aggs;

    while (my $row = $iter->next) {
        say $row->{uri};
    }
}

1;
