#!perl -w
use strict;

# Generate stats on photos posted to the 10 Million Photos Flickr group
# within the past day and the past week.

use FileHandle;
use TenCommon;
use ApiKey;
use Encode;

sub report {
    my $fh = shift;
    my $title = shift;
    my $rows = shift;
    my $counts = shift;
    my $names = shift;

    print $fh "<b><u>$title</u></b>\n";
    print $fh "\n";

    my @keys = sort { $counts->{$b} <=> $counts->{$a} } keys %$counts;
    for my $i (0 .. $rows - 1) {
	print $fh $i + 1, ". $names->{$keys[$i]}: $counts->{$keys[$i]}\n";
    }

    print $fh "\n";
    print $fh "\n";
}

sub main {
    my $totalpages = GetTotalPages;
    print "Total pages = $totalpages\n";

    my $ONEDAY = 24 * 60 * 60;
    my $pagelen = 500;

    my $weekago = time - 7 * $ONEDAY;
    my %weekcounts;
    my %weeknames;
    my %daycounts;
    my %daynames;

    my $highestpage = FindPage($totalpages, $weekago);

    for my $pagenum (reverse 1..$highestpage) {
#	print "Scanning page $pagenum of $highestpage...\n";
	CountPhotos($groupid, $pagenum, $pagelen, [
	    {
		mindate => $weekago,
		counts => \%weekcounts,
		names => \%weeknames,
	    },
	    {
		mindate => time - $ONEDAY,
		counts => \%daycounts,
		names => \%daynames,
	    },
	]);
    }

    my $fname = "newtop.txt";

    my $fh = new FileHandle $fname, "w";
    defined $fh or die "Can't open $fname for writing: $!\n";

    report $fh, "Top Posters in the Past Day", 25,
	\%daycounts, \%daynames;
    report $fh, "Top Posters in the Past Week", 25,
	\%weekcounts, \%weeknames;

    $fh->close;
}

main;

__END__
