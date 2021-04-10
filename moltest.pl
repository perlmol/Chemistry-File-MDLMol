#!/usr/bin/perl

use strict;
use warnings;

use Chemistry::File::MDLMol;

my $mol = Chemistry::Mol->read("test.mol");
print $mol->print(format => "mdl");
