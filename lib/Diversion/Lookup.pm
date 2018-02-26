package Diversion::Lookup;
use v5.18;
use Moo;
with "Diversion::Service";

has what => (
    is => "ro",
    required => 1,
);

sub lookup {
    my ($self, $val) = @_;
    my $what = $self->what;
    my $table = "lookup_${what}";
    my $dbh = $self->db_open("lookup");
    my $sql_lookup = qq{ SELECT `id` FROM `${table}` WHERE `${what}` = ? LIMIT 1 };

    my $ret = $dbh->selectcol_arrayref($sql_lookup, {}, $val);
    defined($ret) or die $DBI::err;
    return $ret->[0] if defined($ret->[0]);

    $dbh->do(qq{ INSERT INTO $table (`$what`) VALUES (?) }, {}, $val);
    $ret = $dbh->selectcol_arrayref($sql_lookup, {}, $val);
    defined($ret) or die $DBI::err;
    return $ret->[0] if defined($ret->[0]);
}

1;
