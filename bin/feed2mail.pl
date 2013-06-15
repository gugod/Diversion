#!/usr/bin/env perl

use v5.14;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../local/lib/perl5";
use Diversion::Seen;

use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;

use URI;
use XML::FeedPP;
use TOML;
use Getopt::Std qw(getopts);
use IO::All;
use List::Util qw(shuffle);
use Try::Tiny;
use DateTime;
use DateTime::Duration;
use Encode;
use Digest::SHA1 qw(sha1_hex);

my %opts;
getopts("c:", \%opts);
die "-c requise a valid TOML file\n" unless -f "$opts{c}";
my @feeds;
my $config;

sub send_feed_mail {
    my $mail_body = shift;

    my $email = Email::MIME->create(
        header_str => [
            From    => $config->{email}{from},
            To      => $config->{email}{to},
            Subject => "Feed2Email",
        ],
        parts => [
            Email::MIME->create(
                attributes => {
                    content_type => "text/html",
                    encoding => "base64",
                },
                body => Encode::encode_utf8($mail_body)
            )
        ]
    );

    $email->charset_set("utf-8");

    sendmail($email, { transport => Email::Sender::Transport::SMTP->new( $config->{smtp} ) });
}

sub build_html_mail {
    my $data = shift;
    my $body = "";

    for my $feed (@{$data->{feeds}}) {
        $body .= "<h2>$feed->{title}</h2>\n";
        $body .= "<ul>\n";
        for my $entry (@{$feed->{entries}}) {
            if ($entry->{media_content} && $entry->{media_thumbnail}) {
                my $url = $entry->{link};
                $body .= qq{<li class="image"><a href="$url"><img src="$entry->{media_thumbnail}"/></a></li>};
            }
            else {
                $body .= qq{<li class="text"><a href="$entry->{link}">$entry->{title}</a></li>};
            }
        }
        $body .= "</ul>\n";
    }

    if ($body) {
        my $style = <<STYLE;
<style type="text/css">
img { vertical-align: top }
li.image { display: inline-block; padding: 5px; }
li.text { display: block; padding: 5px; }
body { -webkit-column-width: 20em }
</style>
STYLE

        $body = "<html><head>${style}</head><body>${body}</body></html>";
        return $body;
    }
}

sub seen {
    my ($db, $key) = @_;
    return 1 if $db->get($key);
    $db->add($key);
    return 0;
}

$config = from_toml( io($opts{c})->all );

die "Msising config ?\n" unless $config->{feed} && $config->{feed}{subscription} && $config->{smtp} && $config->{email} && $config->{email}{from} && $config->{email}{to};

if (-f $config->{feed}{subscription}) {
    @feeds = io($config->{feed}{subscription})->chomp->getlines;
}
else {
    die "Should specifiy feed.subscription !\n"
}

my $data = {};

for (shuffle @feeds) {
    my $uri = URI->new($_);
    my $seen_db = Diversion::Seen->new( file => io->catfile($config->{feed}{storage}, sha1_hex("$uri"), "feed.db")->absolute->name );

    my $_body = "";

    try {
        my $feed = XML::FeedPP->new("$uri");
        $feed->xmlns( "xmlns:media" => "http://search.yahoo.com/mrss" );

        my @entries = grep { $_->link && !seen($seen_db, $_->link) } $feed->get_item;

        if (@entries) {
            my $feed_title = $feed->title;
            utf8::is_utf8($feed_title) or utf8::decode($feed_title);

            my @_entries;

            for my $entry (@entries) {
                my ($title, $link) = ($entry->title, $entry->link);

                for ($title, $link) {
                    utf8::is_utf8($_) or utf8::decode($_);
                }

                $title =~ s!\n! !g;

                push @_entries, {
                    title => $title,
                    link  => $link,
                    media_thumbnail => $entry->get('media:thumbnail@url'),
                    media_content => $entry->get('media:content@url'),
                }
            }

            push @{ $data->{feeds} }, {
                title => $feed_title,
                entries => \@_entries
            };
        }
    }
    catch {
        warn "Failed: $_";
    };
}

my $body = build_html_mail($data);

if ($body) {
    io("/tmp/mail.html")->print($body);
    send_feed_mail($body)
}



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
