package Diversion::App::Command::sendmail;
#ABSTRACT: Send previously built mails.
use v5.18;
use Diversion::App -command;

use IO::All;
use Email::Stuffer;
use Email::Sender::Transport::SMTP;

use Log::Any qw($log);

sub execute {
    my ($self) = @_;

    my $output_dir = $self->app->config->{output}{directory} || "/tmp";
    my @emails = io->dir($output_dir)->glob("diversion-mail-*.html");

    return 0 unless @emails;

    my @latest = ($emails[0]->mtime, $emails[0]);

    for (my $i = 1; $i < $#emails; $i++) {
        my $t = $emails[$i]->mtime;
        if ($t > $latest[0]) {
            $latest[0] = $t;
            $latest[1] = $emails[$i];
        }
    }

    send_feed_mail($self->app->config, scalar $latest[1]->utf8->slurp);
}

sub send_feed_mail {
    my ($config, $mail_body) = @_;

    my $email = Email::Stuffer->new;
    $email->transport("SMTP", $config->{smtp}) if exists $config->{smtp};
    $email->subject( $config->{email}{subject} || "feed updates" );
    $email->from( $config->{email}{from} );
    $email->to( $config->{email}{to} );

    $email->html_body( $mail_body );

    $email->send();
}

1;
