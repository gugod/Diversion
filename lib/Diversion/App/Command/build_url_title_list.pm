package Diversion::App::Command::build_url_title_list;
#ABSTRACT: Render a list of URLs to html.

use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';

use autodie;
use Log::Any qw($log);

use JSON;
use Encode ('encode_utf8', 'decode');

use Diversion::DistinctUrlIterator;

sub opt_spec {
    return (
        ["ago=n", "Scan back from this second ago.", { default => 3600 }],
        ["output=s", "Output file name", { default => "output.html" }],
    )
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $out_fh;
    open $out_fh, ">:utf8", $opt->{output};
    say $out_fh q{<html><head><meta charset="utf8"></head><body>};
    $self->for_each_url_with_content(
        $opt, $args,
        sub {
            my ($o) = @_;
            say $out_fh qq{<p>$o->{main_text}</p>};
            say $out_fh qq{<a href="$o->{uri}">(Read More)</a>};
            say $out_fh qq{<hr>};
        }
    );
    say $out_fh q{ </body></html> };
}

sub for_each_url_with_content {
    my ($self, $opt, $args, $cb) = @_;
    my $iter = Diversion::DistinctUrlIterator->new(
        sql_where_clause => ["created_at > ?", time - $opt->{ago}],
    );

    my $JSON = JSON->new;
    my @list;
    while (my $row = $iter->next) {
        next unless $row->{uri} =~ /^https?:/;
        unless ($self->blob_store->exists($row->{sha1_digest})) {
            warn "Blob is missing: $row->{sha1_digest} $row->{uri}";
        }
        
        my $blob = $self->blob_store->get($row->{sha1_digest});
        my $res;

        eval {
            $res = $JSON->decode($blob);
            1;
        } or do {
            warn "JSON Decode failed. blob = $row->{sha1_digest}: $@";
            next;
        };

        next unless $res->{status} eq '200';

        my $o = HTML::Content::Extractor->new;
        my $content = decode("utf8", $res->{content});
        $o->analyze($content);
        my $main_text = $o->get_main_text;

        if ($main_text && $main_text ne "") {
            $cb->({
                uri       => $row->{uri},
                main_text => $main_text,
            });
        }
    }
}

1;
