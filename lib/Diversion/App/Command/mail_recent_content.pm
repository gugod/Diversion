package Diversion::App::Command::mail_recent_content;
# ABSTRACT: Iterate through recent content and email them.
use v5.18;
use Diversion::App -command;
use Moo;
with 'Diversion::Service';

use Diversion::ContentIterator;

use Encode;
use JSON;

use List::Util qw(first);
use DateTime;
use DateTime::Format::MySQL;

sub opt_spec {
    return (
        ["to=s", "Send to this email address.", {}],
	["limit=i", "Send this amount of email", { default => 10 }],
    )
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $JSON = JSON->new->utf8->canonical;

    my $count = 0;
    my $iter = Diversion::ContentIterator->new;
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

	my ($text_body) = map { $_->{main_text} } first { $_->{main_text} } @{$res->{extractions}};
	my ($html_body) = map { $_->{main_html} } first { $_->{main_html} } @{$res->{extractions}};

	next unless $text_body && $html_body;
	next unless length($text_body) > 300;
	my $first_nl = index($text_body, "\n");
	next unless $first_nl < 80 && $first_nl > 12;

	my $subject = substr($text_body, 0, $first_nl);

	$text_body = "Link: $row->{uri}\n\n" . $text_body;

	$self->mail_this({
	    subject => "#Diversion: $subject",
	    text_body => $text_body,
	    html_body => $html_body,
	    ($opt->{to} ? ( to => $opt->{to} ):()),
        });

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

1;
