package Diversion::App::Command::content_extract;
# ABSTRACT: Extract the content part of downloaded URLs.
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';

use Encode;
use JSON;

use Diversion::UrlArchiveIterator;

use DateTime;
use DateTime::Format::MySQL;
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

    my $x = DateTime::Format::MySQL->format_datetime( DateTime->from_epoch( epoch => (time - $opt->{ago}) ) );
    my $dbh_content = $self->db_open("content");
    my $iter = Diversion::UrlArchiveIterator->new(
        sql_where_clause => ["created_at >= ?", $x ],
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
        next unless $res->{status} && $res->{status} eq '200';
        next unless $res->{headers} && $res->{headers}{"content-type"} && index($res->{headers}{"content-type"}, "text/html") >= 0;
        next if $dbh_content->selectrow_arrayref(q{ SELECT 1 FROM content WHERE uri_content_sha1_digest = ? }, {}, $row->{content_sha1_digest});
        my $res_content = $self->blob_store->get($row->{content_sha1_digest}) or next;
	$res_content = Encode::decode_utf8($res_content) unless Encode::is_utf8($res_content);

	my @extractions;

	eval {
	    my $o = HTML::Content::Extractor->new;
	    $o->analyze($res_content);
	    if (my $main_text = $o->get_main_text) {
		push @extractions, {
		    extractor => "HTML::Content::Extractor",
		    main_text => $main_text,
		} unless length($o) < 60;
	    }

	    if ($o = HTML::ExtractMain::extract_main_html($res_content)) {
		push @extractions, {
		    extractor => 'HTML::ExtractMain',
		    main_html => $o,
		} unless length($o) < 140;
	    }
	    1;
	} or do {
	    # nothing. Ignore all failures.
	    my $error = $@ // '(zombie error)';
	    warn $error;
	};

	next unless @extractions;

        $blob = undef;
        eval {
            $blob = $JSON->encode({
		extractions => \@extractions
            });
            1;
        } or do {
            my $error = $@ || "(zombie error)";
            say STDERR "content_extract: ERROR delaing with $row->{uri}: $error";
        };
        next unless defined($blob);

        my $digest = $self->blob_store->put($blob);

	my $x = DateTime::Format::MySQL->format_datetime( DateTime->from_epoch( epoch => scalar(time) ) );
        $dbh_content->do(
            q{ INSERT INTO content (`uri`, `uri_content_sha1_digest`, `sha1_digest`,`created_at`) VALUES (?,?,?,?) },
            {},
            $row->{uri}, $row->{content_sha1_digest}, $digest, $x
        );
        say "content_extract DONE: $row->{uri}";
    }
    $dbh_content->disconnect;
}

no Moo;
1;
