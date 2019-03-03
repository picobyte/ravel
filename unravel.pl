#!/usr/bin/env perl
use warnings;
use strict;
use JSON;
use File::Spec;
use File::Basename;
use XML::LibXML;
use POSIX qw/ceil/;
use Math::Complex qw/sqrt/;
use HTML::Entities;

my $usage = "perl $0 \$output_directory [options] > \$output_twine_html_file\n";
my $dir = shift or die $usage;
$dir =~ s/\/+$//;
my $options = shift;

die "publish: Specified story workspace \`$dir' doesn't exist." unless -d $dir;

open (my $fh, "<$dir/story.json") or die "$dir/story.json:$!";
my $storyInfo = decode_json(join("", <$fh>));
close $fh;

open ($fh, "<$dir/story.html") or die "$dir/story.html:$!";
my $html = join("", <$fh>);
close($fh);

warn "Exporting story $storyInfo->{name}...\n";
my $doc = XML::LibXML::Document->new();
my $el = $doc->createElement("tw-storydata");
$el->setAttribute($_, $storyInfo->{$_}) foreach (map {$_ =~ /^>/ ? () : $_} keys %$storyInfo);
$el->addChild($doc->createTextNode("hidden"));

my $style_el = XML::LibXML::Element->new("style");
$style_el->setAttribute("role", "stylesheet");
$style_el->setAttribute("id", "twine-user-stylesheet");
$style_el->setAttribute("type", "text/twine-css");

my $script_el = XML::LibXML::Element->new("script");
$script_el->setAttribute("role", "script");
$script_el->setAttribute("id", "twine-user-script");
$script_el->setAttribute("type", "text/twine-javascript");

my $pid = 0;
my $passages = $storyInfo->{">passages"};
my $sizeX = ceil(sqrt(scalar(@$passages)));
my $full_story_dir = File::Spec->rel2abs($dir);

foreach my $pref (@$passages) {
	$pid++;
	my $posX = ($pid - 1) % $sizeX;
	my $posY = ($pid - 1 - $posX) / $sizeX;
	my $pathString = File::Spec->rel2abs("$full_story_dir/$pref->{name}.twp");
	my $dirname = dirname($pathString);
	if (substr($dirname, 0, length($full_story_dir)) ne $full_story_dir) {
		die "Error: Passage name $pref->{name} resolves to a path outside the story workspace.";
	}

	my $passage_el = XML::LibXML::Element->new("tw-passagedata");
	$passage_el->setAttribute($_, $pref->{$_}) foreach (keys %$pref);

	open($fh, "<$pathString") or die "$pathString:$!";
	$passage_el->addChild($doc->createTextNode(join("", <$fh>)));
	close($fh);
	$doc->addChild($passage_el);
}

warn $pid." passages included.\n";

# Fix up non-XML compliant parts. Order matters to avoid erroneous replacements: hidden, script, style.
open($fh, "<$dir/style.css") or die "$dir/style.css:$!";
$style_el->addChild($doc->createTextNode(join("", <$fh>)));
close($fh);
$el->addChild($style_el);

open($fh, "<$dir/script.js") or die "$dir/script.js:$!";
$script_el->addChild($doc->createTextNode(join("", <$fh>)));
close($fh);
$el->addChild($script_el);

# XXX: this seems missing
my $search = "{{STORY_HERE}}";
substr($html, index($html, $search), length($search)) = $doc->toString(1);

print $html;
warn "Story published\n";

