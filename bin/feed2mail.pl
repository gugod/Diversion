#!/usr/bin/env perl

use v5.14;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../local/lib/perl5";
use Diversion::Seen;
use Diversion::FeedFetcher;

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
use List::MoreUtils qw(part);
use HTML::Escape qw(escape_html);
use Web::Query;

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
                $body .= qq{<li class="image"><a title="$entry->{description}" href="$url"><img alt="$entry->{description}" src="$entry->{media_thumbnail}"/></a></li>};
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
</style>
STYLE

        $body = "<html><head>${style}</head><body>${body}</body></html>";
        return $body;
    }
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

    my $fetcher = Diversion::FeedFetcher->new( url => "$uri" );
    my $seen_db = Diversion::Seen->new( file => io->catfile($config->{feed}{storage}, sha1_hex("$uri"), "feed.db")->absolute->name );

    my $_body = "";

    try {
        my $feed = $fetcher->feed;
        my @_entries;

        $fetcher->each_entry(
            sub {
                my ($entry) = @_;

                my $last_seen = $seen_db->get($entry->link);
                $seen_db->add($entry->link) unless $last_seen;

                if ($last_seen) {
                    my ($title, $link) = map { decode(utf8 => $_) } ($entry->title, $entry->link);
                    $seen_db->add($link);
                    # return;
                }

                my ($title, $link) = map { decode(utf8 => $_) } ($entry->title, $entry->link);

                $title =~ s!\n! !g;

                my $_entry = {
                    title => $title,
                    link  => $link,
                    description     => escape_html( decode(utf8 => $entry->description) ),
                    media_thumbnail => $entry->get('media:thumbnail@url'),
                    media_content   => $entry->get('media:content@url'),
                };

                unless ($_entry->{media_thumbanil} && $_entry->{media_content}) {
                    my $wq = Web::Query->new_from_html("<html><body>". $entry->description ."</body></html>");
                    my $images_in_description = $wq->find("img");
                    if ($images_in_description->size == 1) {
                        $_entry->{media_content} = $_entry->{media_thumbnail} = $images_in_description->first->attr("src");
                        $_entry->{description} = escape_html( decode(utf8 => $images_in_description->first->attr("alt")) );
                    }
                }


                push @_entries, $_entry;
            }
        );

        if (@_entries) {
            my $feed_title = $feed->title;
            utf8::is_utf8($feed_title) or utf8::decode($feed_title);

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
    io("/tmp/mail.html")->utf8->print($body);
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
