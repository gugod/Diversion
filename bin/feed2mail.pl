#!/usr/bin/env perl

use v5.14;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../local/lib/perl5";
use Diversion::Seen;
use Diversion::FeedFetcher;

use Email::Stuffer;
use Email::Sender::Transport::SMTP;

use URI;
use XML::FeedPP;
use TOML;
use Getopt::Std qw(getopts);
use IO::All;
use List::Util qw(shuffle);
use List::UtilsBy qw(sort_by nsort_by);
use Try::Tiny;
use DateTime;
use DateTime::Duration;
use Encode ();
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
    my $mail_body = $_[0];

    my $email = Email::Stuffer->new;
    $email->transport("SMTP", $config->{smtp}) if exists $config->{smtp};
    $email->subject( $config->{email}{subject} || "feed updates" );
    $email->from( $config->{email}{from} );
    $email->to( $config->{email}{to} );

    $email->html_body( $mail_body );

    $email->send();
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
li.image { display: inline-block; padding: 5px; max-width: 600px; }
li.image img { width: 100% }
li.text { display: block; padding: 5px; }
</style>
STYLE

        $body = <<"BODY";
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<title>Subscription updates</title>
${style}
</head>
<body>${body}</body>
</html>
BODY

        return $body;
    }
}

sub decode_utf8 {
    return $_[0] if Encode::is_utf8($_[0]);
    return Encode::decode("UTF-8" => $_[0]);
}

$config = from_toml( io($opts{c})->all );

die "Msising config ?\n" unless $config->{feed} && $config->{feed}{subscription} && $config->{smtp} && $config->{email} && $config->{email}{from} && $config->{email}{to};

if (-f $config->{feed}{subscription}) {
    @feeds = grep { s/\s//g; $_ } io($config->{feed}{subscription})->chomp->getlines;
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

                my $last_seen = $seen_db->get($entry->{link});
                $seen_db->add($entry->{link}) unless $last_seen;

                if ($last_seen) {
                    $seen_db->add($entry->{link});
                    return;
                }

                unless ($entry->{media_thumbanil} && $entry->{media_content}) {
                    my $wq = Web::Query->new_from_html("<html><body>". $entry->{description} ."</body></html>");
                    my $images_in_description = $wq->find("img")->filter(
                        sub {
                            my ($i, $elem) = @_;
                            if ($elem->attr("width") && $elem->attr("width") == 1 && $elem->attr("height") && $elem->attr("height") == 1) {
                                return 0;
                            }
                            return 1;
                        }
                    );
                    if ($images_in_description->size == 1) {
                        my $text = length($wq->text() =~ s/\s//gr);
                        if ($text < 1) {
                            $entry->{media_content} = $entry->{media_thumbnail} = $images_in_description->first->attr("src");
                            $entry->{description} = escape_html( decode_utf8($images_in_description->first->attr("alt")) );
                        }
                    }
                }

                push @_entries, $entry;
            }
        );

        if (@_entries) {
            @_entries = sort_by {
                $_->{media_content} ? 1 : 0
            } @_entries;

            my $feed_title = decode_utf8( $feed->{title} );

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

@{$data->{feeds}} = nsort_by { 0+@{ $_->{entries} } } @{$data->{feeds}};

my $body = build_html_mail($data);

if ($body) {
    send_feed_mail($body);

    if ($config->{output}{directory}) {
        my @l = (localtime)[5,4,3,2,1];
        $l[0]+=1900;
        $l[1]+=1;
        my $ts = sprintf("%4d%02d%02d%02d%02d",@l);
        io->catfile($config->{output}{directory}, "$ts.html")->utf8->print($body);
    }
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
