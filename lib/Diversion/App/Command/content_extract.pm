package Diversion::App::Command::content_extract;
# ABSTRACT: Extract the content part of downloaded URLs.
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';

use Encode;
use JSON;

use Diversion::UrlArchiveIterator;

use HTML::Content::Extractor;
use HTML::ExtractMain;
use Mojo::DOM;

sub opt_spec {
    return (
        ["limit=i", "Harvest upto to this many amount of URLs", { default => 3600 }],
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }],
        ["workers=n", "number of worker processes.", { default => 4 }]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $JSON = JSON->new->utf8->canonical;

    my $dbh_content = $self->db_open("content");
    my $iter = Diversion::UrlArchiveIterator->new(
        sql_where_clause => ["created_at >= ?", time - $opt->{ago} ],
    );
    while (my $row = $iter->next) {
        my $blob = $self->blob_store->get($row->{response_sha1_digest}) or next;
        my $res;
        eval {
            $res = $JSON->decode( $blob );
            1;
        } or do {
            warn "Fail to decode json for of blob $row->{response_sha1_digest}\n";
            next;
        };
        next unless $res->{headers} && $res->{headers}{"content-type"} && index($res->{headers}{"content-type"}, "text/html") >= 0;
        next if $dbh_content->selectrow_arrayref(q{ SELECT 1 FROM content WHERE uri_content_sha1_digest = ? }, {}, $row->{content_sha1_digest});
        my $res_content = $self->blob_store->get($row->{content_sha1_digest}) or next;
        my $o = HTML::Content::Extractor->new;
        $o->analyze($res_content);
        my $main_text = $o->get_main_text;

        $blob = undef;
        eval {
            $blob = $JSON->encode({
                main_text => $main_text,
                extractor => "HTML::Content::Extractor"
            });
            1;
        } or do {
            my $error = $@ || "(zombie error)";
            say STDERR "content_extract: ERROR delaing with $row->{uri}: $error";
        };
        next unless defined($blob);

        my $digest = $self->blob_store->put($blob);
        $dbh_content->do(
            q{ INSERT INTO content (`uri`, `uri_content_sha1_digest`, `sha1_digest`,`created_at`) VALUES (?,?,?,?) },
            {},
            $row->{uri}, $row->{content_sha1_digest}, $digest, scalar(time)
        );
        say "content_extract DONE: $row->{uri}";
    }
    $dbh_content->disconnect;
}

1;
