#!/usr/bin/perl -wT
#
# search_packages.pl -- CGI interface to the Packages files on packages.debian.org
#
# Copyright (C) 1998 James Treacy
# Copyright (C) 2000, 2001 Josip Rodin
# Copyright (C) 2001 Adam Heath
# Copyright (C) 2004 Martin Schulze
# Copyright (C) 2004-2006 Frank Lichtenheld
#
# use is allowed under the terms of the GNU Public License (GPL)                              
# see http://www.fsf.org/copyleft/gpl.html for a copy of the license

use strict;
use CGI qw( -oldstyle_urls );
use CGI::Carp qw( fatalsToBrowser );
use POSIX;
use URI::Escape;
use HTML::Entities;
use DB_File;
use Benchmark;

use lib "../lib";

use Deb::Versions;
use Packages::Search qw( :all );
use Packages::HTML ();

my $thisscript = "search_packages.pl";
my $HOME = "http://www.debian.org";
my $ROOT = "";
my $SEARCHPAGE = "http://packages.debian.org/";
my @SUITES = qw( oldstable stable testing unstable experimental );
my @DISTS = @SUITES;
my @SECTIONS = qw( main contrib non-free );
my @ARCHIVES = qw( us security installer );
my @ARCHITECTURES = qw( alpha amd64 arm hppa hurd-i386 i386 ia64
			kfreebsd-i386 mips mipsel powerpc s390 sparc );
my %SUITES = map { $_ => 1 } @SUITES;
my %SECTIONS = map { $_ => 1 } @SECTIONS;
my %ARCHIVES = map { $_ => 1 } @ARCHIVES;
my %ARCHITECTURES = map { $_ => 1 } @ARCHITECTURES;

$ENV{PATH} = "/bin:/usr/bin";

# Read in all the variables set by the form
my $input = new CGI;

my $pet0 = new Benchmark;
# use this to disable debugging in production mode completly
my $debug_allowed = 1;
my $debug = $debug_allowed && $input->param("debug");
$Search::Param::debug = 1 if $debug > 1;

# If you want, just print out a list of all of the variables and exit.
print $input->header if $debug;
# print $input->dump;
# exit;

if (my $path = $input->param('path')) {
    my @components = map { lc $_ } split /\//, $path;

    foreach (@components) {
	if ($SUITES{$_}) {
	    $input->param('suite', $_);
	} elsif ($SECTIONS{$_}) {
	    $input->param('section', $_);
	} elsif ($ARCHIVES{$_}) {
	    $input->param('archive', $_);
	}elsif ($ARCHITECTURES{$_}) {
	    $input->param('arch', $_);
	}
    }
}

my %params_def = ( keywords => { default => undef, match => '^\s*([-+\@\w\/.:]+)\s*$' },
		   suite => { default => 'stable', match => '^(\w+)$',
			      alias => 'version', array => ',',
			      replace => { all => \@SUITES } },
		   case => { default => 'insensitive', match => '^(\w+)$' },
		   official => { default => 0, match => '^(\w+)$' },
		   use_cache => { default => 1, match => '^(\w+)$' },
		   subword => { default => 0, match => '^(\w+)$' },
		   exact => { default => undef, match => '^(\w+)$' },
		   searchon => { default => 'all', match => '^(\w+)$' },
		   section => { default => 'all', match => '^([\w-]+)$',
				alias => 'release', array => ',',
				replace => { all => \@SECTIONS } },
		   arch => { default => 'any', match => '^(\w+)$',
			     array => ',', replace =>
			     { any => \@ARCHITECTURES } },
		   archive => { default => 'all', match => '^(\w+)$',
				array => ',', replace =>
				{ all => \@ARCHIVES } },
		   format => { default => 'html', match => '^(\w+)$' },
		   );
my %params = Packages::Search::parse_params( $input, \%params_def );

my $format = $params{values}{format}{final};
#XXX: Don't use alternative output formats yet
$format = 'html';

if ($format eq 'html') {
    print $input->header;
} elsif ($format eq 'xml') {
#    print $input->header( -type=>'application/rdf+xml' );
    print $input->header( -type=>'text/plain' );
}

if ($params{errors}{keywords}) {
    print "Error: keyword not valid or missing" if $format eq 'html';
    exit 0;
}
my $keyword = $params{values}{keywords}{final};
my @suites = @{$params{values}{suite}{final}};
my $official = $params{values}{official}{final};
my $use_cache = $params{values}{use_cache}{final};
my $case = $params{values}{case}{final};
my $case_bool = ( $case !~ /insensitive/ );
my $subword = $params{values}{subword}{final};
my $exact = $params{values}{exact}{final};
$exact = !$subword unless defined $exact;
my $searchon = $params{values}{searchon}{final};
my @sections = @{$params{values}{section}{final}};
my @archs = @{$params{values}{arch}{final}};
my $page = $params{values}{page}{final};
my $results_per_page = $params{values}{number}{final};

# for URL construction
my $suites_param = join ',', @{$params{values}{suite}{no_replace}};
my $sections_param = join ',', @{$params{values}{section}{no_replace}};
my $archs_param = join ',', @{$params{values}{arch}{no_replace}};

# for output
my $keyword_enc = encode_entities $keyword;
my $searchon_enc = encode_entities $searchon;
my $suites_enc = encode_entities join ', ', @{$params{values}{suite}{no_replace}};
my $sections_enc = encode_entities join ', ', @{$params{values}{section}{no_replace}};
my $archs_enc = encode_entities join ', ',  @{$params{values}{arch}{no_replace}};
my $pet1 = new Benchmark;
my $petd = timediff($pet1, $pet0);
print "DEBUG: Parameter evaluation took ".timestr($petd)."<br>" if $debug;

if ($format eq 'html') {
print Packages::HTML::header( title => 'Package Search Results' ,
			      lang => 'en',
			      title_tag => 'Debian Package Search Results',
			      print_title_above => 1,
			      print_search_field => 'packages',
			      search_field_values => { 
				  keywords => $keyword_enc,
				  searchon => $searchon,
				  arch => $archs_enc,
				  suite => $suites_enc,
				  section => $sections_enc,
				  subword => $subword,
				  exact => $exact,
				  case => $case,
				  },
			      );
}

# read the configuration
my $topdir;
if (!open (C, "../config.sh")) {
    print "\nInternal Error: Cannot open configuration file.\n\n"
if $format eq 'html';
    exit 0;
}
while (<C>) {
    $topdir = $1 if (/^\s*topdir="?(.*)"?\s*$/);
}
close (C);

my $DBDIR = $topdir . "/files/db";
my $search_on_sources = 0;

my $st0 = new Benchmark;
my @results;
if ($searchon eq 'sourcenames') {
    $search_on_sources = 1;
}

my %suites = map { $_ => 1 } @suites;
my %sections = map { $_ => 1 } @sections;
my %archs = map { $_ => 1 } @archs;

print "DEBUG: suites=@suites, sections=@sections, archs=@archs<br>" if $debug > 2;

if ($searchon eq 'names') {

    $keyword = lc $keyword unless $case_bool;
    
    my $obj = tie my %packages, 'DB_File', "$DBDIR/packages_small.db", O_RDONLY, 0666, $DB_BTREE
	or die "couldn't tie DB $DBDIR/packages_small.db: $!";
    
    if ($exact) {
	my $result = $packages{$keyword};
	foreach (split /\000/, $result) {
	    my @data = split ( /\s/, $_, 7 );
	    print "DEBUG: Considering entry ".join( ':', @data)."<br>" if $debug > 2;
	    if ($suites{$data[0]} && ($archs{$data[1]} || $data[1] eq 'all')
		&& $sections{$data[2]}) {
		print "DEBUG: Using entry ".join( ':', @data)."<br>" if $debug > 2;
		push @results, [ $keyword, @data ];
	    }
	}
    } else {
	while (my ($pkg, $result) = each %packages) {
            #what's faster? I can't really see a difference
	    (index($pkg, $keyword) >= 0) or next;
	    #$pkg =~ /\Q$keyword\E/ or next;
	    foreach (split /\000/, $packages{$pkg}) {
		my @data = split ( /\s/, $_, 7 );
		print "DEBUG: Considering entry ".join( ':', @data)."<br>" if $debug > 2;
		if ($suites{$data[0]} && ($archs{$data[1]} || $data[1] eq 'all')
		    && $sections{$data[2]}) {
		    print "DEBUG: Using entry ".join( ':', @data)."<br>" if $debug > 2;
		    push @results, [ $pkg , @data ];
		}
	    }
	}
    }
}

my $st1 = new Benchmark;
my $std = timediff($st1, $st0);
print "DEBUG: Search took ".timestr($std)."<br>" if $debug;

if ($format eq 'html') {
    my $suite_wording = $suites_enc eq "all" ? "all suites"
	: "suite(s) <em>$suites_enc</em>";
    my $section_wording = $sections_enc eq 'all' ? "all sections"
	: "section(s) <em>$sections_enc</em>";
    my $arch_wording = $archs_enc eq 'any' ? "all architectures"
	: "architecture(s) <em>$archs_enc</em>";
    if (($searchon eq "names") || ($searchon eq 'sourcenames')) {
	my $source_wording = $search_on_sources ? "source " : "";
	my $exact_wording = $exact ? "named" : "that names contain";
	print "<p>You have searched for ${source_wording}packages $exact_wording <em>$keyword_enc</em> in $suite_wording, $section_wording, and $arch_wording.</p>";
    } else {
	my $exact_wording = $exact ? "" : " (including subword matching)";
	print "<p>You have searched for <em>$keyword_enc</em> in packages names and descriptions in $suite_wording, $section_wording, and $arch_wording$exact_wording.</p>";
    }
}

if (!@results) {
    if ($format eq 'html') {
	my $keyword_esc = uri_escape( $keyword );
	my $printed = 0;
	if (($searchon eq "names") || ($searchon eq 'sourcenames')) {
	    if (($suites_enc eq 'all')
		&& ($archs_enc eq 'any')
		&& ($sections_enc eq 'all')) {
		print "<p><strong>Can't find that package.</strong></p>\n";
	    } else {
		print "<p><strong>Can't find that package, at least not in that suite ".
		    ( $search_on_sources ? "" : " and on that architecture" ).
		    ".</strong></p>\n";
	    }
	    
	    if ($exact) {
		$printed = 1;
		print "<p>You have searched only for exact matches of the package name. You can try to search for <a href=\"$thisscript?exact=0&amp;searchon=$searchon&amp;suite=$suites_param&amp;case=$case&amp;section=$sections_param&amp;keywords=$keyword_esc&amp;arch=$archs_param\">package names that contain your search string</a>.</p>";
	    }
	} else {
	    if (($suites_enc eq 'all')
		&& ($archs_enc eq 'any')
		&& ($sections_enc eq 'all')) {
		print "<p><strong>Can't find that string.</strong></p>\n";
	    } else {
		print "<p><strong>Can't find that string, at least not in that suite ($suites_enc, section $sections_enc) and on that architecture ($archs_enc).</strong></p>\n";
	    }
	    
	    unless ($subword) {
		$printed = 1;
		print "<p>You have searched only for words exactly matching your keywords. You can try to search <a href=\"$thisscript?subword=1&amp;searchon=$searchon&amp;suite=$suites_param&amp;case=$case&amp;section=$sections_param&amp;keywords=$keyword_esc&amp;arch=$archs_param\">allowing subword matching</a>.</p>";
	    }
	}
	print "<p>".( $printed ? "Or you" : "You" )." can try a different search on the <a href=\"$SEARCHPAGE#search_packages\">Packages search page</a>.</p>";
	
	&printfooter;
    }
    exit;
}

my (%pkgs, %sect, %part, %desc, %binaries);

unless ($search_on_sources) {
    foreach (@results) {
	my ($pkg_t, $suite, $arch, $section, $subsection,
            $priority, $version, $desc) = @$_;
	
	my ($package) = $pkg_t =~ m/^(.+)/; # untaint
	$pkgs{$package}{$suite}{$version}{$arch} = 1;
	$sect{$package}{$suite}{$version} = $subsection;
	$part{$package}{$suite}{$version} = $section unless $section eq 'main';
	
	$desc{$package}{$suite}{$version} = $desc;

    }

    if ($format eq 'html') {
	my ($start, $end) = multipageheader( scalar keys %pkgs );
	my $count = 0;
	
	foreach my $pkg (sort keys %pkgs) {
	    $count++;
	    next if $count < $start or $count > $end;
	    printf "<h3>Package %s</h3>\n", $pkg;
	    print "<ul>\n";
	    foreach my $ver (@SUITES) {
		if (exists $pkgs{$pkg}{$ver}) {
		    my @versions = version_sort keys %{$pkgs{$pkg}{$ver}};
		    my $part_str = "";
		    if ($part{$pkg}{$ver}{$versions[0]}) {
			$part_str = "[<span style=\"color:red\">$part{$pkg}{$ver}{$versions[0]}</span>]";
		    }
		    printf "<li><a href=\"$ROOT/%s/%s/%s\">%s</a> (%s): %s   %s\n",
		    $ver, $sect{$pkg}{$ver}{$versions[0]}, $pkg, $ver, $sect{$pkg}{$ver}{$versions[0]}, $desc{$pkg}{$ver}{$versions[0]}, $part_str;
		    
		    foreach my $v (@versions) {
			printf "<br>%s: %s\n",
			$v, join (" ", (sort keys %{$pkgs{$pkg}{$ver}{$v}}) );
		    }
		    print "</li>\n";
		}
	    }
	    print "</ul>\n";
	}
    } elsif ($format eq 'xml') {
	require RDF::Simple::Serialiser;
	my $rdf = new RDF::Simple::Serialiser;
	$rdf->addns( debpkg => 'http://packages.debian.org/xml/01-debian-packages-rdf' );
	my @triples;
	foreach my $pkg (sort keys %pkgs) {
	    foreach my $ver (@DISTS) {
		if (exists $pkgs{$pkg}{$ver}) {
		    my @versions = version_sort keys %{$pkgs{$pkg}{$ver}};
		    foreach my $version (@versions) {
			my $id = "$ROOT/$ver/$sect{$pkg}{$ver}{$version}/$pkg/$version";
			push @triples, [ $id, 'debpkg:package', $pkg ];
			push @triples, [ $id, 'debpkg:version', $version ];
			push @triples, [ $id, 'debpkg:section', $sect{$pkg}{$ver}{$version}, ];
			push @triples, [ $id, 'debpkg:suite', $ver ];
			push @triples, [ $id, 'debpkg:shortdesc', $desc{$pkg}{$ver}{$version} ];
			push @triples, [ $id, 'debpkg:part', $part{$pkg}{$ver}{$version} || 'main' ];
			foreach my $arch (sort keys %{$pkgs{$pkg}{$ver}{$version}}) {
			    push @triples, [ $id, 'debpkg:architecture', $arch ];
			}
		    }
		}
	    }
	}
	
	print $rdf->serialise(@triples);
    }
} else {
    foreach (@results) {
        my ($package, $suite, $section, $version, $binaries);
	
	$pkgs{$package}{$suite} = $version;
	$sect{$package}{$suite}{source} = 'subsection';
	$part{$package}{$suite}{source} = $section unless $section eq 'main';

	$binaries{$package}{$suite} = [ sort split( /\s*,\s*/, $binaries ) ];

    }

    if ($format eq 'html') {
	my ($start, $end) = multipageheader( scalar keys %pkgs );
	my $count = 0;
	
	foreach my $pkg (sort keys %pkgs) {
	    $count++;
	    next if ($count < $start) or ($count > $end);
	    printf "<h3>Source package %s</h3>\n", $pkg;
	    print "<ul>\n";
	    foreach my $ver (@SUITES) {
		if (exists $pkgs{$pkg}{$ver}) {
		    my $part_str = "";
		    if ($part{$pkg}{$ver}{source}) {
			$part_str = "[<span style=\"color:red\">$part{$pkg}{$ver}{source}</span>]";
		    }
		    printf "<li><a href=\"$ROOT/%s/source/%s\">%s</a> (%s): %s   %s", $ver, $pkg, $ver, $sect{$pkg}{$ver}{source}, $pkgs{$pkg}{$ver}, $part_str;
		    
		    print "<br>Binary packages: ";
		    my @bp_links;
		    foreach my $bp (@{$binaries{$pkg}{$ver}}) {
			my $sect = find_section($bp, $ver, $part{$pkg}{$ver}{source}||'main') || '';
			$sect =~ s,^(non-free|contrib)/,,;
			$sect =~ s,^non-US.*$,non-US,,;
			my $bp_link;
			if ($sect) {
			    $bp_link = sprintf "<a href=\"$ROOT/%s/%s/%s\">%s</a>", $ver, $sect, uri_escape( $bp ),  $bp;
			} else {
			    $bp_link = $bp;
			}
			push @bp_links, $bp_link;
		    }
		    print join( ", ", @bp_links );
		    print "</li>\n";
		}
	    }
	    print "</ul>\n";
	}
    } elsif ($format eq 'xml') {
	require RDF::Simple::Serialiser;
	my $rdf = new RDF::Simple::Serialiser;
	$rdf->addns( debpkg => 'http://packages.debian.org/xml/01-debian-packages-rdf' );
	my @triples;
	foreach my $pkg (sort keys %pkgs) {
	    foreach my $ver (@SUITES) {
		if (exists $pkgs{$pkg}{$ver}) {
		    my $id = "$ROOT/$ver/source/$pkg";

		    push @triples, [ $id, 'debpkg:package', $pkg ];
		    push @triples, [ $id, 'debpkg:type', 'source' ];
		    push @triples, [ $id, 'debpkg:section', $sect{$pkg}{$ver}{source} ];
		    push @triples, [ $id, 'debpkg:version', $pkgs{$pkg}{$ver} ];
		    push @triples, [ $id, 'debpkg:part', $part{$pkg}{$ver}{source} || 'main' ];
		    
		    foreach my $bp (@{$binaries{$pkg}{$ver}}) {
			push @triples, [ $id, 'debpkg:binary', $bp ];
		    }
		}
	    }
	}
	print $rdf->serialise(@triples);
    }
}

if ($format eq 'html') {
    &printindexline( scalar keys %pkgs );
    &printfooter;
}

exit;

sub printindexline {
    my $no_results = shift;

    my $index_line;
    if ($no_results > $results_per_page) {
	
	$index_line = prevlink($input,\%params)." | ".indexline( $input, \%params, $no_results)." | ".nextlink($input,\%params, $no_results);
	
	print "<p style=\"text-align:center\">$index_line</p>";
    }
}

sub multipageheader {
    my $no_results = shift;

    my ($start, $end);
    if ($results_per_page =~ /^all$/i) {
	$start = 1;
	$end = $no_results;
	$results_per_page = $no_results;
    } else {
	$start = Packages::Search::start( \%params );
	$end = Packages::Search::end( \%params );
	if ($end > $no_results) { $end = $no_results; }
    }

    print "<p>Found <em>$no_results</em> matching packages,";
    if ($end == $start) {
	print " displaying package $end.</p>";
    } else {
	print " displaying packages $start to $end.</p>";
    }

    printindexline( $no_results );

    if ($no_results > 100) {
	print "<p>Results per page: ";
	my @resperpagelinks;
	for (50, 100, 200) {
	    if ($results_per_page == $_) {
		push @resperpagelinks, $_;
	    } else {
		push @resperpagelinks, resperpagelink($input,\%params,$_);
	    }
	}
	if ($params{values}{number}{final} =~ /^all$/i) {
	    push @resperpagelinks, "all";
	} else {
	    push @resperpagelinks, resperpagelink($input, \%params,"all");
	}
	print join( " | ", @resperpagelinks )."</p>";
    }
    return ( $start, $end );
}

sub printfooter {
print <<END;
</div>

<hr class="hidecss">
<p style="text-align:right;font-size:small;font-stlye:italic"><a href="$SEARCHPAGE">Packages search page</a></p>

</div>
END

print $input->end_html;
}
