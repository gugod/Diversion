package Diversion::App::Command::mail_recent_content;
# ABSTRACT: Iterate through recent content and email them.
use v5.36;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';

use Diversion::ContentIterator;

use Encode;
use JSON;

use DateTime;
use DateTime::Format::MySQL;

sub opt_spec {
    return (
        ["to=s", "Send to this email address.", {}],
	["limit=i", "Send this amount of email", { default => 10 }],
	["ago=i", "Only include contents from this number of seconds ago.", { default => 60 }],
	["n", "Dry-run"]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $JSON = JSON->new->utf8->canonical;

    my $count = 0;
    my $x = DateTime::Format::MySQL->format_datetime( DateTime->from_epoch( epoch => ( time - $opt->{ago} ) ) );
    my $iter = Diversion::ContentIterator->new( sql_where_clause => ['created_at > ?', $x ] );

    while (my $row = $iter->next) {
	next if $row->{uri} =~ m{/$};

        my $blob = $self->blob_store->get($row->{sha1_digest}) or next;
        my $res;
        eval {
            $res = $JSON->decode($blob);
            1;
        } or do {
            warn "Fail to decode json for of blob $row->{sha1_digest}\n";
            next;
        };

	my ($text_body, $html_body);
	for (@{$res->{extractions}}) {
	    $text_body //= $_->{main_text};
	    $html_body //= $_->{main_html};
	}

	next unless $text_body && $html_body;
	next unless length($text_body) > 300;
	my $first_nl = index($text_body, "\n");
	next unless $first_nl < 80 && $first_nl > 12;

	my $subject = substr($text_body, 0, $first_nl);
	if (defined($opt->{subject_prefix})) {
	    $subject = $opt->{subject_prefix} . " " . $subject;
	}

	$text_body = "Link: $row->{uri}\n\n" . $text_body;
	$html_body = "Link: <a href=\"$row->{uri}\">$row->{uri}</a><br>" . $html_body;

	if ($opt->{n}) {
	    say Encode::encode_utf8("DRY RUN: Sending: $subject");
	} else {

	    say Encode::encode_utf8("Sending: $subject");
	    $self->mail_this({
		subject => $subject,
		text_body => $text_body,
		html_body => $html_body,
		($opt->{to} ? ( to => $opt->{to} ):()),
	    });
	}

        last if ($count++ > $opt->{limit});

    }
}

sub mail_this {
    my ($self, $mail_params) = @_;

    my $config = $self->app->config;

    my $email = Email::Stuffer->new($mail_params);
    $email->transport("SMTP", $config->{smtp});
    $email->from( $config->{email}{from} );

    unless ($email->send()) {
        say "Error sending this mail: " . $mail_params->{subject};
    }
}

no Moo;
1;
