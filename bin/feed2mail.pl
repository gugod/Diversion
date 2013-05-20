#!/usr/bin/env perl

use v5.14;
use strict;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;
use Email::Simple;
use Email::Simple::Creator;
use XML::Feed;
use XML::XPath;
use TOML;
use Getopt::Std qw(getopts);
use IO::All;
use List::Util qw(shuffle);
use Try::Tiny;
use DateTime;
use DateTime::Duration;

my %opts;
getopts("c:", \%opts);
die "-c requise a valid TOML file\n" unless -f "$opts{c}";
my @feeds;
my $config;

sub send_feed_mail {
    my $mail_body = shift;
    my $email = Email::Simple->create(
        header => [
            Subject => "Feed2Email",
            From => $config->{email}{from},
            To => $config->{email}{to},
        ],
        body => $mail_body
    );
    sendmail($email, { transport => Email::Sender::Transport::SMTP->new( $config->{smtp} ) });
}

my $far_past = DateTime->now - DateTime::Duration->new(days => 1);
sub seen {
    my ($entry) = @_;
    if ($entry->issued) {
        if ($entry->issued < $far_past) {
            return 0;
        }
    }
    return 1;
}

$config = from_toml( io($opts{c})->all );

die "Msising config ?\n" unless $config->{feed} && $config->{feed}{opml} && $config->{smtp} && $config->{email} && $config->{email}{from} && $config->{email}{to};

if (-f $config->{feed}{opml}) {
    my $xp = XML::XPath->new(filename => $config->{feed}{opml});
    my $resultset = $xp->find('//outline[@xmlUrl]');
    for my $node ($resultset->get_nodelist) {
        push @feeds, $node->getAttribute("xmlUrl");
    }
}
else {
    die "feeds.opml should point to a file\n"
}


my $body;

for (shuffle @feeds) {
    my $uri = URI->new($_);
    my $_body = "";
    say "Processing $uri";

    try {
        my $feed = XML::Feed->parse( $uri ) or die "Not a feed URI: $uri";

        my @entries = grep { !seen($_) } $feed->entries;

        if (@entries) {
            my $feed_title = $feed->title;
            utf8::is_utf8($feed_title) or utf8::decode($feed_title);

            $_body .= "# $feed_title\n\n";
            for my $entry (@entries) {
                my ($title, $link) = ($entry->title, $entry->link);

                for ($title, $link) {
                    utf8::is_utf8($_) or utf8::decode($_);
                }

                $title =~ s!\n! !g;

                $_body .= " - $title <$link>\n";
            }
            $_body .= "\n----\n";
        }
    }
    catch {
        warn "Failed: $_";
    };

    if ($_body) {
        $body .= $_body
    }
}
send_feed_mail($body);

__END__

feed2mail.pl -c feed2mail.toml http://example.con/feed1 http://example.con/feed2

__ feed2mail.toml __
[email]
to = "..."
from = "..."

[smtp]
host = "..."
ssl = 1
sasl_username = "..."
sasl_password = "..."
