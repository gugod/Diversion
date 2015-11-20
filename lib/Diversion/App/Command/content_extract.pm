package Diversion::App::Command::content_extract;
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::AppRole';

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
    my $JSON = JSON->new;

    my $dbh_content = $self->db_open("content");
    my $iter = Diversion::UrlArchiveIterator->new;
    while (my $row = $iter->next) {
        my $blob = $self->blob_store->get($row->{sha1_digest}) or next;
        my $res;
        eval {
            $res = $JSON->decode( $blob );
            1;
        } or do {
            warn "Fail to decode json for of blob $row->{sha1_digest}\n";
            next;
        };

        next unless $res->{headers} && $res->{headers}{"content-type"};
        next unless !ref($res->{content}) && index($res->{headers}{"content-type"}, "text/html") >= 0;

        next if $dbh_content->selectrow_arrayref(q{ SELECT 1 FROM content WHERE uri_response_sha1_digest = ? }, {}, $row->{sha1_digest});

        my $o = HTML::Content::Extractor->new;
        $o->analyze($res->{content});
        my $main_text = $o->get_main_text;

        my $digest = $self->blob_store->put($JSON->utf8->encode({
            main_text => $main_text,
            extractor => "HTML::Content::Extractor"
        }));

        $dbh_content->do(q{ INSERT INTO content (`uri`, `uri_response_sha1_digest`, `sha1_digest`,`created_at`) VALUES (?,?,?,?) }, {}, $row->{uri}, $row->{sha1_digest}, $digest, scalar(time));
    }
    $dbh_content->disconnect;
}

1;
