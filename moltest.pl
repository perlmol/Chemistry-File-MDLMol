#!/home/ivan/bin/perl

use warnings;
use strict;
use blib;
#use lib '../Mol/blib/lib';
use Chemistry::File::MDLMol;
use Chemistry::File::SDF;

#my $mol = Chemistry::Mol->read("test.mol");
#print $mol->print;

my @mols = Chemistry::Mol->read("sulfides.sdf");
printf "found %d mols\n", scalar @mols;
my $total_atoms;
my $total_sulfur;
for my $mol (@mols) {
    my @sulfurs = grep {$_->symbol eq 'S'} $mol->atoms;
    $total_sulfur += @sulfurs;
    $total_atoms += $mol->atoms;
    for my $s (@sulfurs) {
        next if $s->bonds != 2;
        for my $bond ($s->bonds) {
            if (grep {$_->symbol eq 'C'} $bond->atoms) {
                printf "%s\t%s-%s\t%.3f\n", $mol->name, $bond->atoms, 
                    $bond->length;
            }
        }
    }
}
print "Total atoms: $total_atoms\t$total_sulfur\n";
