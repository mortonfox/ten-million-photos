#!perl -w
use strict;

# Add datafiles to database.
# Usage: tenconvert.pl x*.htm

use FileHandle;
use File::DosGlob;

use TenCommon;
use TenDB;

sub glob_args {
    map { File::DosGlob::glob $_ } @_;
}

sub ProcessFiles {
    my $dbh = shift;

    for my $file (@_) {
	my $fh = new FileHandle $file, "r";
	defined $fh or die "Error opening file $file for reading: $!\n";
	my $line = <$fh>;
	next unless $line =~ /Pages (\d+) to (\d+): Dates (\d+) to (\d+):/;

	my $startpage = $1;
	my $endpage = $2;
	my $lowdate = $3;
	my $highdate = $4;

	my $stats = '';
	while (defined($line = <$fh>)) {
	    $stats .= $line;
	}

	$fh->close;

	$dbh->add($startpage, $endpage, $lowdate, $highdate, $stats);
    }
}

my $dbh = new TenDB;
# Much faster to turn AutoCommit off if adding many records.
$dbh->{dbh}->{AutoCommit} = 0;
ProcessFiles($dbh, glob_args @ARGV);
$dbh->{dbh}->commit;
undef $dbh;

__END__
