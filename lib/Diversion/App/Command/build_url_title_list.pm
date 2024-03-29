package Diversion::App::Command::build_url_title_list;
#ABSTRACT: Render a list of URLs to html.

use v5.36;
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
    say $out_fh q{<html><head><meta charset="utf-8"></head><body>};
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

    my $x = DateTime::Format::MySQL->format_datetime( DateTime->from_epoch( epoch => (time - $opt->{ago}) ) );
    my $iter = Diversion::DistinctUrlIterator->new(
        sql_where_clause => ["created_at > ?", $x],
    );

    my $JSON = JSON->new;
    
    while (my $row = $iter->next) {
        next unless $row->{uri} =~ /^https?:/;
        unless ($self->blob_store->exists($row->{response_sha1_digest})) {
            warn "Blob is missing: $row->{response_sha1_digest} $row->{uri}";
        }

        my $blob = $self->blob_store->get($row->{response_sha1_digest});

        my $res;
        eval {
            $res = $JSON->decode($blob);
            1;
        } or do {
            warn "JSON Decode failed. blob = $row->{response_sha1_digest}: $@";
            next;
        };

        next unless (($res->{status} eq '200') && ( ($res->{headers}{"content-type"} //"") =~ m{^ text/html }x ));

        my $res_content;
        eval {
            $res_content = $self->blob_store->get($row->{content_sha1_digest});
            1;
        } or do {
            warn "JSON Decode failed. blob = $row->{content_sha1_digest}: $@";
            next;
        };
        next unless defined($res_content);

        my $o = HTML::Content::Extractor->new;
        my $content = decode("utf8", $res_content);
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

no Moo;
1;
