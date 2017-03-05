package Diversion::UrlArchiveIterator;
use v5.18;
use Moo;
use constant {
    database => "url",
    table => "uri_archive",
    columns => [qw(uri response_sha1_digest content_sha1_digest created_at)]
};
with 'Diversion::SingleTableIterator';
1;
