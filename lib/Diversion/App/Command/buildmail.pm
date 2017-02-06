package Diversion::App::Command::buildmail;
# ABSTRACT: build email containing recent entries
use v5.18;
use Moo;
with 'Diversion::Service';
use Diversion::App -command;

use IO::All;
use JSON::PP;
use DateTime;
use DateTime::Format::RSS;
use List::UtilsBy qw( rev_nsort_by uniq_by );
use List::Util qw( max );
use Text::Xslate;
use Text::WrapI18N qw(wrap);

use File::ShareDir;
use Log::Any qw($log);

use Diversion::FeedArchiver;
use Diversion::FeedArchiveIterator;

sub opt_spec {
    return (
        ["ago=i", "Include entries created up to this second ago.", { default => 86400 }],
    )
}

sub is_blank {
    my $str = $_[0];
    return !defined($str) || $str =~ m/^\s*$/;
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $JSON = JSON::PP->new->utf8;

    my $blob_store = $self->blob_store;
    my $iter = Diversion::FeedArchiveIterator->new;
    my $now = DateTime->now;
    my $fmt = DateTime::Format::RSS->new;
    my %seen;
    my $tmpl_data = {};
    while (my $row = $iter->next()) {
	next unless $row->{uri} && $row->{sha1_digest};
	my $blob = $blob_store->get($row->{sha1_digest});
	my $data = $JSON->decode($blob);
	for my $entry (@{$data->{entry}}) {
	    next if !$entry->{pubDate} || !$entry->{link} || is_blank($entry->{title}) || $seen{$entry->{link}}++;
	    
            $entry->{_pubDate_as_DateTime} = $fmt->parse_datetime($entry->{pubDate});
	    if ($entry->{_pubDate_as_DateTime}) {
		next if ($now - $entry->{_pubDate_as_DateTime})->in_units("seconds") > $opt->{ago};
	    }
	    
	    if ($entry->{description} && length($entry->{description}) > 140) {
		$entry->{description_short} = substr($entry->{description}, 0, 137) . "...";
	    }
	    $entry->{description} //= "";
	    $entry->{description_short} //= "";
	    
	    push @{ $tmpl_data->{entries} }, $entry;
	}
    }

    my @l = (localtime)[5,4,3,2,1];
    $l[0]+=1900;
    $l[1]+=1;
    my $ts = sprintf("%4d%02d%02d%02d%02d",@l);
    my $output_dir = Diversion::App->config->{output}{directory} || "/tmp";

    my ($text_body, $html_body);
    if ($text_body = build_text_mail($tmpl_data)) {
	io->catfile($output_dir, "diversion-mail-$ts.txt")->utf8->print($text_body);
    }
    
    if ($html_body = build_html_mail($tmpl_data)) {
	io->catfile($output_dir, "diversion-mail-$ts.html")->utf8->print($html_body);
    }
}

sub fleshen_entries {
    my $tmpl_data = shift;
    my $fmt = DateTime::Format::RSS->new;
    my $max_title_length = max(1, map { length($_->{title}) } @{ $tmpl_data->{entries} } );
    my $max_description_length = max(1, map { length($_->{description}) } @{ $tmpl_data->{entries} } );

    $tmpl_data->{entries} = [ rev_nsort_by {
        my $dt = $_->{_pubDate_as_DateTime};
        ($dt ? $dt->epoch : 1000)
        + ( ($_->{media_content}   ? 1 : 0) + ($_->{media_thumbnail} ? 1 : 0) )
        + ( length($_->{description} // '') / $max_description_length )
        + ( length($_->{title} // '') / $max_title_length )
    } grep { $_->{link} && $_->{pubDate} } @{$tmpl_data->{entries}} ];

    for my $x (@{$tmpl_data->{entries}}) {
        $x->{has_image} = ($x->{media_thumbnail} && $x->{media_content});
	if ($x->{description}) {
	    my $t = $x->{description};
	    $t =~ s/\r\n/\n/gs;
	    $t =~ s/\n+/\n    /g;
	    $x->{description_as_text} = $t;
	}
    }
    return $tmpl_data;
}

sub build_text_mail {
    my $tmpl_data = shift;
    fleshen_entries($tmpl_data);

    my $tmpl_dir = "share/views";
    unless (-d $tmpl_dir) {
        $tmpl_dir = File::ShareDir::dist_dir('Diversion') . "/views";
    }

    my $tx = Text::Xslate->new( path => [ $tmpl_dir ]);
    return scalar $tx->render("newsletter_text.tx", $tmpl_data);
}

sub build_html_mail {
    my $tmpl_data = shift;

    fleshen_entries($tmpl_data);

    my $tmpl_dir = "share/views";
    unless (-d $tmpl_dir) {
        $tmpl_dir = File::ShareDir::dist_dir('Diversion') . "/views";
    }

    my $tx = Text::Xslate->new( path => [ $tmpl_dir ]);
    return scalar $tx->render("newsletter.tx", $tmpl_data);
}

1;
