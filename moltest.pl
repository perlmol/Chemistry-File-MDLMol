#!/home/ivan/bin/perl

use warnings;
use strict;
use blib;
#use lib '../Mol/blib/lib';
use Chemistry::File::MDLMol;
#use Chemistry::File::SDF;

my $mol = Chemistry::Mol->read("test.mol");
#print $mol->print;
print $mol->print(format => "mdl");

#my @mols = Chemistry::Mol->read("test_data.sdf");
#print $mols[0]->print;

#for my $mol (@mols) {
#    print $mol->name, "\t", $mol->attr("sdf/<PKA>")||'', "\t", $mol->mass, "\n";
#}
