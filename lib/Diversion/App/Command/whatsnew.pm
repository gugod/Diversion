package Diversion::App::Command::whatsnew;
#ABSTRACT: List new URLs in the archive
use v5.36;
use Diversion::App -command;

use Moo;
use DateTime;
use DateTime::Format::MySQL;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }],
    )
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $x = DateTime::Format::MySQL->format_datetime( DateTime->from_epoch( epoch => (time - $opt->{ago}) ) );
    my $iter = Diversion::UrlArchiveIterator->new(
	sql_where_clause => [
	    "created_at = updated_at AND created_at > ?", $x
	]
    );
    while (my $row = $iter->next) {
	say $row->{uri};
    }
}

no Moo;
1;
