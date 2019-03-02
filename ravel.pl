#!/usr/bin/env perl
use warnings;
use strict;
use XML::LibXML;
use Data::Dumper;
use Try::Tiny;
use File::Spec;
use File::Basename;
use JSON;
use HTML::Entities;

my $usage = "cat \$twine_html_file | perl $0 \$output_directory\n";

my $dir = shift or die $usage;

## parse html.
my $html = join("", <>);

my $startTail = " hidden>";
my $end = "</tw-storydata>";

my $startOffset = index($html, "<tw-storydata");
my $startTailOffset = index($html, $startTail, $startOffset);
my $passageStartOffset = index($html, "<tw-passagedata", $startOffset);

my $xmlString = substr($html, $startOffset, $startTailOffset - $startOffset).">";
$xmlString .= substr($html, $passageStartOffset, rindex($html, $end) + length($end) - $passageStartOffset);

# extract css and javascript
my $otherString = substr($html, $startTailOffset + length($startTail), $passageStartOffset - $startTailOffset - length($startTail));

die unless $otherString =~ s/<style[^>]*>(.*)<\/style>//s;
my $globalStyle = $1;

die unless $otherString =~ s/<script[^>]*>(.*)<\/script>//s;
my $globalScript = $1;

# parse xml document
my $doc = XML::LibXML->load_xml(string => $xmlString);
my $st = $doc->getElementsByTagName("tw-storydata");
die "tw-storydata element occurs multiple times in xml?!" unless $st->size() == 1;
$st = $st->pop();

my $startnode = $st->getAttribute("startnode");
my $startnodeName = "";

warn "Serializing ".$st->getAttribute("name")."...\n";
mkdir($dir);

open(my $fh, ">$dir/style.css");
print $fh $globalStyle;
close($fh);

open($fh, ">$dir/script.js");
print $fh $globalScript;
close($fh);

my $errors = 0;
my $passageCount = 0;
my $full_story_dir = File::Spec->rel2abs($dir);

foreach my $el ($st->getElementsByTagName("tw-passagedata")) {
	my $name = $el->getAttribute("name");
	my $pathString = File::Spec->rel2abs("$full_story_dir/$name.twp");
	my $dirname = dirname($pathString);
	if (substr($dirname, 0, length($full_story_dir)) ne $full_story_dir) {
		warn "Error: Passage name $name resolves to a path outside the story workspace.";
		$errors++;
		next;
	}
	if ($el->getAttribute("pid") == $startnode) {
		$startnodeName = $name;
	}
	mkdir($dirname);
	open($fh, ">$pathString");

	my $tags = $el->getAttribute("tags");
	print $fh "/* tags: $tags */" if $tags ne "";
	print $fh decode_entities(join("", $el->childNodes()));
	close($fh);
	$passageCount++;
}

warn "$passageCount of ".($passageCount + $errors)." passages imported.\n";

my $rec_hash = {name => $st->getAttribute("name"), startnode => $startnodeName, ifid => $st->getAttribute("ifid")};

open($fh, ">$full_story_dir/story.json");
print $fh encode_json($rec_hash)."\n";

warn "Story info saved.\n";
warn "serialization completed with $errors errors.\n" if $errors > 0;

