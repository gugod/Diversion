package Diversion::ContentIterator;
use v5.18;
use Moo;
use constant {
    database => "content",
    table => "content",
    columns => [qw( uri uri_content_sha1_digest sha1_digest created_at )],
};
with 'Diversion::SingleTableIterator';
1;
