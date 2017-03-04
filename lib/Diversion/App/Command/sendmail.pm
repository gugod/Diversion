package Diversion::App::Command::sendmail;
#ABSTRACT: Send previously built mails.
use v5.18;
use Diversion::App -command;

use IO::All;
use Email::Stuffer;
use Email::Sender::Transport::SMTP;

use Log::Any qw($log);

sub opt_spec {
    return (
        ["text-only", "Only the text format"],
        ["html-only", "Only the html format"],
        ["subject=s", "The subject line."],
        ["to=s", "The target email to send to"],
	["n", "Dry-run"],
    )
}

sub execute {
    my ($self, $opt) = @_;

    my $config = $self->app->config;
    my $output_dir = $self->app->config->{output}{directory} || "/tmp";

    my ($mail_text, $mail_html);
    $mail_html = take_newest_file_by_name( io->dir($output_dir)->glob("diversion-mail-*.html") ) unless $opt->{text_only};
    $mail_text = take_newest_file_by_name( io->dir($output_dir)->glob("diversion-mail-*.txt") ) unless $opt->{html_only};

    my $email = Email::Stuffer->new;
    $email->subject( $opt->{subject} || $config->{email}{subject} || "Some diversion arrives" );
    $email->from( $config->{email}{from} );
    $email->to( $opt->{to} || $config->{email}{to} );

    if ($mail_text) {
	$email->text_body( scalar $mail_text->utf8->all );
    }

    if ($mail_html) {
	$email->html_body( scalar $mail_html->utf8->all );
    }

    $email->transport("SMTP", $config->{smtp});

    if ($opt->{n}) {
	say $email->as_string;

    } else {
	my $successful;
	eval {
	    $successful = $email->send();
	    1;
	} or do {
	    say "Error\n$@";
	};
	unless ($successful) {
	    say "Error: failed to send the mail";
	}
    }

    return 0;
}

sub take_newest_file_by_name {
    my $maximum = $_[0];
    for (@_[1..$#_]) {
	$maximum = $_ if $_ gt $maximum
    }
    return $maximum;
}

1;
