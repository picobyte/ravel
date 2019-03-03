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
$dir =~ s/\/+$//;

## parse html.
my $html = join("", <>);

my $startTail = " hidden>";
my $tw_end = "</tw-storydata>";

my $startOffset = index($html, "<tw-storydata");
my $startTailOffset = index($html, $startTail, $startOffset);
my $passageStartOffset = index($html, "<tw-passagedata", $startOffset);

my $xmlString = substr($html, $startOffset, $startTailOffset - $startOffset).">";
$xmlString .= substr($html, $passageStartOffset, rindex($html, $tw_end) + length($tw_end) - $passageStartOffset);

# extract css and javascript
my $otherString = substr($html, $startTailOffset + length($startTail), $passageStartOffset - $startTailOffset - length($startTail));
my $fh;
if ($otherString =~ s/<style[^>]*>(.*)<\/style>//s) {
	open($fh, ">$dir/style.css") or die "dir/style.css:$!";
	print $fh $1;
	close($fh);
}

if ($otherString =~ s/<script[^>]*>(.*)<\/script>//s) {
	open($fh, ">$dir/script.js") or die "$dir/script.js:$!";
	print $fh $1;
	close($fh);
}

# parse xml document
my $doc = XML::LibXML->load_xml(string => $xmlString);
my $st = $doc->getElementsByTagName("tw-storydata");
die "tw-storydata element occurs multiple times in xml?!" unless $st->size() == 1;
$st = $st->pop();

my $st_attrs = {map {$_->nodeName => $_->getValue} $st->attributes()};

warn "Serializing $st_attrs->{name}...\n";
mkdir($dir);

my $errors = 0;
my @passages = $st->getElementsByTagName("tw-passagedata");
my $full_story_dir = File::Spec->rel2abs($dir);

foreach my $el (@passages) {
	my $name = $el->getAttribute("name");
	my $psg_attrs = {map {$_->nodeName => $_->getValue} $el->attributes()};
	push @{$st_attrs->{">passages"}}, $psg_attrs;

	my $pathString = File::Spec->rel2abs("$full_story_dir/$name.twp");
	my $dirname = dirname($pathString);
	if (substr($dirname, 0, length($full_story_dir)) ne $full_story_dir) {
		die "Error: Passage name $name resolves to a path outside the story workspace.";
	}
	$st_attrs->{">startnodeName"} = $name if $el->getAttribute("pid") == $st_attrs->{startnode};

	mkdir($dirname);
	open($fh, ">$pathString") or die "$pathString:$!";
	print $fh decode_entities(join("", $el->childNodes()));
	close($fh);
}

my $include_string = "{{STORY_HERE}}";
substr($html, $passageStartOffset, rindex($html, $tw_end) + length($tw_end) - $passageStartOffset) = $include_string;

open($fh, ">$full_story_dir/story.html") or die "$full_story_dir/story.html:$!";
print $fh $html;
close($fh);

warn scalar(@passages)." passages imported\n";

die "Start node not observed" unless exists $st_attrs->{">startnodeName"};

open($fh, ">$full_story_dir/story.json") or die "$full_story_dir/story.json:$!";
print $fh encode_json($st_attrs)."\n";
close($fh);


