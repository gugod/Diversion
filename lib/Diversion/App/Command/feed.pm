package Diversion::App::Command::feed;
# ABSTRACT: List feed URLs
use v5.36;
use Moo;
with 'Diversion::Service';
use Diversion::App -command;

use Diversion::FeedUrlIterator;
use JSON::XS;

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
    

    while (my $row = $iter->next) {
        say $row->{uri};
    }
}

no Moo;
1;
