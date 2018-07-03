package Diversion::Lookup;
use v5.18;
use Moo;
with "Diversion::Service";

has what => (
    is => "ro",
    required => 1,
);

sub bulk_lookup_by_id {
    my ($self, $vals) = @_;
    my @missing = @$vals;

    my %lookup;

    while (@missing) {
        my $question_marks = join(',' , map { '?' } @missing);
        my $what = $self->what;
        my $table = "lookup_${what}";
        my $sql_lookup = qq{ SELECT `id`,`${what}` FROM `${table}` WHERE `id` IN ($question_marks) };

        $self->db_open(
            "lookup",
            sub {
                my ($dbh) = @_;
                my $rows = $dbh->selectall_arrayref($sql_lookup, {}, @missing);
                for (@$rows) {
                    $lookup{ $_->[0] } = $_->[1];
                }
            }
        );

        my @still_missing = grep { !defined($lookup{$_}) } @missing;

        if (@still_missing) {
            $self->db_open(
                "lookup",
                sub {
                    my ($dbh) = @_;
                    my $placeholder = join(', ' , map { '(?)' } @still_missing);
                    $dbh->do(qq{ INSERT INTO $table (`$what`) VALUES ${placeholder} ON DUPLICATE KEY UPDATE id=id }, undef, @still_missing);
                }
            );
        }
        @missing = @still_missing;
    }
    return \%lookup;
}

sub bulk_lookup {
    my ($self, $vals) = @_;
    my @missing = @$vals;

    my %lookup;

    while (@missing) {
        my $question_marks = join(',' , map { '?' } @missing);
        my $what = $self->what;
        my $table = "lookup_${what}";
        my $sql_lookup = qq{ SELECT `id`,`${what}` FROM `${table}` WHERE `${what}` IN ($question_marks) };

        $self->db_open(
            "lookup",
            sub {
                my ($dbh) = @_;
                my $rows = $dbh->selectall_arrayref($sql_lookup, {}, @missing);
                for (@$rows) {
                    $lookup{ $_->[1] } = $_->[0];
                }
            }
        );

        my @still_missing = grep { !defined($lookup{$_}) } @missing;

        if (@still_missing) {
            $self->db_open(
                "lookup",
                sub {
                    my ($dbh) = @_;
                    my $placeholder = join(', ' , map { '(?)' } @still_missing);
                    $dbh->do(qq{ INSERT INTO $table (`$what`) VALUES ${placeholder} ON DUPLICATE KEY UPDATE id=id }, undef, @still_missing);
                }
            );
        }
        @missing = @still_missing;
    }
    return \%lookup;
}

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

no Moo;
1;
