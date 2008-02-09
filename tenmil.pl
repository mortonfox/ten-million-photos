#!perl -w
use strict;

# Scan a set of pages from the 10 Million Photos Flickr group and generate
# stats. Add those stats to the database.

use Getopt::Long;
use FileHandle;
use TenCommon;
use ApiKey;
use Encode;

# Open log file.
sub OpenLog {
    my $prefix = shift;
    my $logfn = sprintf("$prefix%X.htm", time);
    my $fh = new FileHandle $logfn, "w";
    defined $fh or die "Error opening $logfn for writing: $!\n";
    $fh->autoflush(1);
    $fh;
}

# Get photo stats on the specified page. Don't count photos older than
# mindate.
sub CountPhotos_old {
    my $groupid = shift;
    my $pagenum = shift;
    my $pagelen = shift;
    my $mindate = shift;

    my $ownercounts = shift;
    my $ownernames = shift;

    my ($totalpages, $lodate, $hidate, $photolist) =
	GetPage($groupid, $pagenum, $pagelen);

    for my $photo (@$photolist) {
	next if $photo->{dateadded} < $mindate;
	my $owner = $photo->{owner};
	unless (defined $ownercounts->{$owner}) {
	    $ownernames->{$owner} = encode("iso-8859-1", $photo->{ownername});
	    $ownercounts->{$owner} = 0;
	}
	$ownercounts->{$owner}++;
    }

    return ($totalpages, $lodate, $hidate);
}

sub Usage {
    print <<EOM;
$0 [-pagelen=n] startpagenum endpagenum mindate

-pagelen=n: 
	Set the page length to n. 
	n must be at least 1. 
	Default n is 500.

startpagenum
	First page to retrieve.

endpagenum
	Last page to retrieve.

mindate
	Count only photos posted to the group after this date.
EOM
    exit 1;
}

sub main {
    my $startpagenum = shift;
    my $endpagenum = shift;
    my $pagelen = shift;
    my $mindate = shift;

    my %ownercounts;
    my %ownernames;

    print "Scanning pages $startpagenum to $endpagenum...\n";

    my $lowestdate = 0x7FFFFFFF;
    my $highestdate = 0;

    for my $pagenum ($startpagenum .. $endpagenum) {
	my ($totalpages, $lodate, $hidate) = 
	    CountPhotos($groupid, $pagenum, $pagelen, [
		{
		    mindate => $mindate,
		    counts => \%ownercounts, 
		    names => \%ownernames
		}
	    ]);
	$lodate < $lowestdate and $lowestdate = $lodate;
	$hidate > $highestdate and $highestdate = $hidate;
	last if $pagenum >= $totalpages;
    }

    $highestdate > 0 or die "No data\n";

    my $stats = '';
    for my $key (sort { $ownercounts{$b} <=> $ownercounts{$a} } keys %ownercounts) {
	$stats .= "$ownercounts{$key},$key,$ownernames{$key}\n";
    }

    my $dbh = OpenDB;
    AddToDB($dbh, 
	$startpagenum, $endpagenum,
	$lowestdate, $highestdate, 
	$stats);
    CloseDB $dbh;
}

my $pagelen = 500;

Getopt::Long::Configure("bundling_override");
GetOptions('pagelen=s' => \$pagelen) or Usage();
die "Page length must be at least 1\n" if $pagelen < 1;

my $startpagenum = (shift or 1);
my $endpagenum = (shift or $startpagenum);

my $mindate = (shift or 0);

$endpagenum < $startpagenum and
    ($startpagenum, $endpagenum) = ($endpagenum, $startpagenum);

main($startpagenum, $endpagenum, $pagelen, $mindate);

__END__
