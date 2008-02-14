#!perl -w
use strict;

# 10pool DB functions.

package TenDB;

my $DBNAME = "10pool.db";
my $TBLNAME = "statstable";

use DBI;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->initialize();
    return $self;
}

sub initialize {
    my $self = shift;

    my $dbh = DBI->connect("dbi:SQLite:dbname=$DBNAME", "", "",
	{ RaiseError => 1, AutoCommit => 1 });

    # Create the table if it does not exist.
    my $sth = $dbh->prepare("PRAGMA table_info($TBLNAME)")
	or die $dbh->errstr;
    $sth->execute
	or die $sth->errstr;

    my @row = $sth->fetchrow_array;
    if (!@row) {
	$sth->err and
	    die $sth->errstr;
	print "Table $TBLNAME not present\n";
	$sth = $dbh->prepare("CREATE TABLE $TBLNAME (" .
	    "key INTEGER PRIMARY KEY, " .
	    "startpage INTEGER, endpage INTEGER, " .
	    "lowdate INTEGER, highdate INTEGER, " . 
	    "stats TEXT, " . 
	    "timestamp INTEGER" .
	    ")") or die $dbh->errstr;
	$sth->execute
	    or die $sth->errstr;
    }
    $self->{dbh} = $dbh;
}

sub DESTROY {
    my $self = shift;
    my $dbh = $self->{dbh};
    $dbh->disconnect;
}

# Add a record to the database.
sub add {
    my $self = shift;

    my $startpage = shift;
    my $endpage = shift;
    my $lowdate = shift;
    my $highdate = shift;
    my $stats = shift;

    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare("INSERT INTO $TBLNAME (startpage, endpage, lowdate, highdate, stats, timestamp) VALUES (?, ?, ?, ?, ?, ?)") 
	or die $dbh->errstr;
    $sth->execute($startpage, $endpage, $lowdate, $highdate, $stats, time) 
	or die $sth->errstr;

    1;
}

# Get the most recent date in the database.
sub highestdate {
    my $self = shift;
    my $dbh = $self->{dbh};

    my $highestdate = 0;
    my $toppage = 0;

    my $sth = $dbh->prepare("SELECT endpage, highdate FROM $TBLNAME WHERE highdate = (SELECT max(highdate) FROM $TBLNAME)")
	or die $dbh->errstr;
    $sth->execute
	or die $sth->errstr;

    my @row;
    if (@row = $sth->fetchrow_array) {
	($toppage, $highestdate) = @row;
    }
    elsif ($sth->err) {
	die $sth->errstr;
    }

    ($highestdate, $toppage);
}

# Calculate aggregate stats for everyone.
sub ownerstats {
    my $self = shift;
    my $dbh = $self->{dbh};

    my %owners;

    my $sth = $dbh->prepare("SELECT stats FROM $TBLNAME")
	or die $dbh->errstr;
    $sth->execute
	or die $sth->errstr;

    my @row;
    while (@row = $sth->fetchrow_array) {
	for my $line (split(/\n/, $row[0])) {
	    my ($count, $owner, $ownername) = split(/,/, $line, 3);
	    defined $ownername or next;

	    unless (defined $owners{$owner}) {
		$owners{$owner} = { 
		    owner => $owner,
		    name => $ownername,
		    count => 0 
		};
	    }
	    $owners{$owner}{count} += $count;
	}
    }
    $sth->err and die $sth->errstr;

    \%owners;
}

1;

__END__
