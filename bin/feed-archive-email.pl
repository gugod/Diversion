#!/usr/bin/env perl
use v5.18;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../local/lib/perl5";
use Diversion::FeedArchiver;

use TOML;
use IO::All;

use Email::Stuffer;
use Email::Sender::Transport::SMTP;

use List::UtilsBy qw( rev_nsort_by uniq_by );
use List::Util qw( max );
use JSON::PP;
use Log::Dispatch;
use Log::Any::Adapter;

Log::Any::Adapter->set(
    'Dispatch',
    dispatcher => Log::Dispatch->new(
        outputs => [
            [ 'File', min_level => "debug", filename => "/tmp/feed-archive-email.log" ],
            [ 'Screen', min_level => "debug" ],
        ]
    )
);

use Log::Any qw($log);
use Getopt::Std qw(getopts);

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

sub build_html_mail {
    my $tmpl_data = shift;
    my $body = "";

    my $max_title_length = max( map { length($_->{title}) } @{ $tmpl_data->{entries} } );
    for my $entry (rev_nsort_by {
        ( length($_->{title}) / $max_title_length )
        + 10 * ($_->{media_content}   ? 1 : 0)
        + 10 * ($_->{media_thumbnail} ? 1 : 0)
    } @{$tmpl_data->{entries}}) {
        if ($entry->{media_content} && $entry->{media_thumbnail}) {
            my $url = $entry->{link};
            $body .= qq{<div class="image"><a title="$entry->{description}" href="$url"><img alt="$entry->{description}" src="$entry->{media_thumbnail}"/></a></div>};
        } else {
            $body .= qq{<div class="text"><a href="$entry->{link}">$entry->{title}</a></div>};
        }
    }

    if ($body) {
        my $style = <<STYLE;
<style type="text/css">
img { vertical-align: top }
.image { display: inline-block; padding: 5px; max-width: 600px; }
.image img { width: 100% }
.text { display: block; padding: 5px; }
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

sub main {
    my %opts;
    getopts("c:", \%opts);
    die "-c requise a valid TOML file\n" unless -f "$opts{c}";

    my $config = from_toml( io($opts{c})->all );

    die "Msising config ?\n" unless $config->{smtp} && $config->{email} && $config->{email}{from} && $config->{email}{to};

    my $feed_archiver = Diversion::FeedArchiver->new;

    my $dbh = $feed_archiver->dbh_index;
    my $blob_store = $feed_archiver->blob_store;

    my $rows = $dbh->selectall_arrayref('SELECT uri, created_at, entry_sha1_digest FROM feed_archive WHERE created_at > ?', {Slice=>{}}, (time - 86400));

    my $JSON = JSON::PP->new->utf8;
    my $tmpl_data = {};
    for my $row (@$rows) {
        my $b = $blob_store->get($row->{entry_sha1_digest});
        push @{ $tmpl_data->{entries} }, $JSON->decode($b);
    }
    my $html_body = build_html_mail($tmpl_data);

    if ($html_body) {
        if ($config->{output}{directory}) {
            my @l = (localtime)[5,4,3,2,1];
            $l[0]+=1900;
            $l[1]+=1;
            my $ts = sprintf("%4d%02d%02d%02d%02d",@l);
            io->catfile($config->{output}{directory}, "$ts.html")->utf8->print($html_body);
        }
        send_feed_mail($config, $html_body);
    }
}
main();
