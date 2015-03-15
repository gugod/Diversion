package Diversion::App::Command::buildmail;
use v5.18;
use App::Cmd -command;

use IO::All;
use JSON::PP;
use DateTime::Format::RSS;
use List::UtilsBy qw( rev_nsort_by uniq_by );
use List::Util qw( max );

use Log::Any qw($log);

use Diversion::FeedArchiver;

sub execute {
    my ($self, $opt, $args) = @_;

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
        my @l = (localtime)[5,4,3,2,1];
        $l[0]+=1900;
        $l[1]+=1;
        my $ts = sprintf("%4d%02d%02d%02d%02d",@l);

        my $output_dir = $self->app->config->{output}{directory} || "/tmp";
        io->catfile($output_dir, "diversion-email-$ts.html")->utf8->print($html_body);
    }
}

sub build_html_mail {
    my $JSON = JSON::PP->new->utf8;

    my $tmpl_data = shift;
    my $body = "";
    my $fmt = DateTime::Format::RSS->new;
    my $max_title_length = max( map { length($_->{title}) } @{ $tmpl_data->{entries} } );
    for my $entry (rev_nsort_by {
        my $dt = $_->{pubDate} ? $fmt->parse_datetime($_->{pubDate}) : undef;
        ($dt ? $dt->epoch : 1000)
        + 10  * ( ($_->{media_content}   ? 1 : 0) + ($_->{media_thumbnail} ? 1 : 0) )
        + ( length($_->{title}) / $max_title_length )
    } @{$tmpl_data->{entries}}) {
        # $body .= "\n<pre>".$JSON->encode($entry)."</pre>\n";
        $body .= "\n";
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

1;
