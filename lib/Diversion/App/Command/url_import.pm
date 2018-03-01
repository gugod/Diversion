package Diversion::App::Command::url_import;
# ABSTRACT: Import URLs and relate them to tags
use v5.18;
use Moo;
with 'Diversion::Service';
use Diversion::App -command;

use Diversion::Lookup;

sub opt_spec {
    return (
        ["i=s", "The input text file with one URL per line."],
        ["tag=s@", "The tags"]
    )
}

sub execute {
    my ($self, $opt) = @_;

    my (@tags, @urls);
    my $lookup_tag = Diversion::Lookup->new( what => "tag" );
    my $lookup_uri = Diversion::Lookup->new( what => "uri" );

    for my $tag (@{ $opt->{tag} }) {
        utf8::decode($tag) unless utf8::is_utf8($tag);
        my $id = $lookup_tag->lookup($tag);
        push @tags, $id;
    }

    open my $fh, "<", $opt->{i};
    while(<$fh>) {
        chomp;
        my $uri = $_;
        my $id = $lookup_uri->lookup($uri);
        push @urls, $id;
    }
    close($fh);


    if (@tags && @urls) {
        my @bulk;
        for my $u (@urls) {
            for my $t (@tags) {
                push @bulk, [ $u, $t ];
            }
            if (@bulk > 1000) {
                $self->bulk_insert(\@bulk);
            }
        }
        $self->bulk_insert(\@bulk) if @bulk;
    }
}

sub bulk_insert {
    my ($self, $rows) = @_;
    my $sql = q{INSERT INTO rel_uri_tag(`uri_id`, `tag_id`) VALUES } . join(',', map { '(?,?)' } @$rows) . ' ON DUPLICATE KEY UPDATE uri_id=uri_id';
    $self->db_open('lookup')->do($sql, {}, map { (@$_) } @$rows);
}

1;
