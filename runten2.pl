#!perl -w
use strict;

# Retrieve stats on photos added to the 10 Million Photos Flickr group
# since the last run. Add those stats to the database.

use TenCommon;
use TenDB;

my $pageclusterlen = 10;
my $pagelen = 500;

sub GetHighestDate {
    my $dbh = new TenDB;
    my ($highestdate, $toppage) = $dbh->highestdate;
    undef $dbh;
    ($highestdate, $toppage);
}

sub main {
    my $totalpages = GetTotalPages $pagelen;
    print "Total pages = $totalpages\n";

    my ($highestdate, $toppage) = GetHighestDate();
    print "Highest date = $highestdate, Top page = $toppage\n";

    my $highestpage = ($highestdate ? 
	FindPage($totalpages, $highestdate, $pagelen) : 
	$totalpages);

    while (1) {
	# Query the highest date every time in case the most recent run of
	# tenmil.pl failed.
	my ($hidate, $hipage) = GetHighestDate();
	my $endset = $highestpage;
	$hidate > $highestdate and $endset = $hipage - $pageclusterlen;

	print "hidate = $hidate, hipage = $hipage, endset = $endset\n";

	last if $endset <= 0;

	my $startset = $endset - $pageclusterlen + 1;
	$startset < 1 and $startset = 1;
	print "startset = $startset, endset = $endset\n";

	system "perl tenmil.pl $startset $endset $highestdate";
    }
}

main;

__END__
