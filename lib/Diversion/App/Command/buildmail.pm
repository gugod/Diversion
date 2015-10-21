package Diversion::App::Command::buildmail;
use v5.18;
use Diversion::App -command;

use IO::All;
use JSON::PP;
use DateTime::Format::RSS;
use List::UtilsBy qw( rev_nsort_by uniq_by );
use List::Util qw( max );
use Text::Xslate;

use File::ShareDir;
use Log::Any qw($log);

use Diversion::FeedArchiver;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }]
    )
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $feed_archiver = Diversion::FeedArchiver->new;

    my $dbh = $feed_archiver->dbh_index;
    my $blob_store = $feed_archiver->blob_store;

    my $rows = $dbh->selectall_arrayref('SELECT uri, created_at, entry_json FROM feed_entries WHERE created_at > ?', {Slice=>{}}, (time - $opt->{ago}));
    $dbh->disconnect;

    my $JSON = JSON::PP->new->utf8;
    my $tmpl_data = {};
    for my $row (@$rows) {
        my $entry = $JSON->decode($row->{entry_json});
        push @{ $tmpl_data->{entries} }, $entry;
    }

    my $html_body = build_html_mail($tmpl_data);

    if ($html_body) {
        my @l = (localtime)[5,4,3,2,1];
        $l[0]+=1900;
        $l[1]+=1;
        my $ts = sprintf("%4d%02d%02d%02d%02d",@l);

        my $output_dir = $self->app->config->{output}{directory} || "/tmp";
        io->catfile($output_dir, "diversion-mail-$ts.html")->utf8->print($html_body);
    }
}

sub build_html_mail {
    my $tmpl_data = shift;

    my $fmt = DateTime::Format::RSS->new;
    my $max_title_length = max( map { length($_->{title}) } @{ $tmpl_data->{entries} } );
    my $max_description_length = max( map { length($_->{description}) } @{ $tmpl_data->{entries} } );

    $tmpl_data->{entries} = [ rev_nsort_by {
        my $dt = $_->{pubDate} ? $fmt->parse_datetime($_->{pubDate}) : undef;
        ($dt ? $dt->epoch : 1000)
        + ( ($_->{media_content}   ? 1 : 0) + ($_->{media_thumbnail} ? 1 : 0) )
        + ( length($_->{description_length}) / $max_description_length )
        + ( length($_->{title}) / $max_title_length )
    } grep { defined($_->{link}) } @{$tmpl_data->{entries}} ];

    for my $x (@{$tmpl_data->{entries}}) {
        $x->{has_image} = ($x->{media_thumbnail} && $x->{media_content});
    }

    my $tmpl_dir = "share/views";
    unless (-d $tmpl_dir) {
        $tmpl_dir = File::ShareDir::dist_dir('Diversion') . "/views";
    }

    my $tx = Text::Xslate->new( path => [ $tmpl_dir ]);
    return scalar $tx->render("newsletter.tx", $tmpl_data);
}

1;
