use v5.18;
use strict;

use Test::More;

use Diversion::App;
use Diversion::ContentIterator;
use Diversion::UrlArchiveIterator;

use File::XDG;
use TOML qw(from_toml);

sub init_config {
    # This paragraph is required to setup db conf.
    my $xdg = File::XDG->new( name => "diversion" );
    my $config_file = $xdg->config_home->file("config.toml");
    my $config = from_toml(scalar $config_file->slurp);
    my $app = Diversion::App->new->set_config($config);
}

sub test_content_iterator {
    my $count = 0;
    my $iter = Diversion::ContentIterator->new();
    while (my $row = $iter->next()) {
        diag $row->{uri};
        last if $count++ > 10;
    }

    ok $count > 0;
}

sub test_content_iterator {
    my $count = 0;
    my $iter = Diversion::ContentIterator->new();
    while (my $row = $iter->next()) {
        diag $row->{uri};
        last if $count++ > 10;
    }

    ok $count > 0;
    pass "ContentIterator";
}

sub test_url_archive_iterator {
    my $count = 0;
    my $iter = Diversion::UrlArchiveIterator->new();
    while (my $row = $iter->next()) {
        diag $row->{uri};
        last if $count++ > 3000;
    }
    ok $count > 3000;
    pass "UrlArchiveIterator";
}

init_config();
test_content_iterator();
test_url_archive_iterator();

done_testing;
