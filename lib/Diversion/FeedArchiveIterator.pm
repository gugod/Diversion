package Diversion::FeedArchiveIterator;
use v5.18;
use Moo;
use constant {
    database => "feed",
    table => "feed_archive",
    columns => [qw( uri sha1_digest created_at )],
};
with 'Diversion::SingleTableIterator';
no Moo;
1;
