package Chemistry::File::MDLMol;
$VERSION = '0.18';
# $Id$

use base "Chemistry::File";
use Chemistry::Mol;
use Carp;
use strict;
use warnings;

=head1 NAME

Chemistry::File::MDLMol - MDL molfile reader/writer

=head1 SYNOPSIS

    use Chemistry::File::MDLMol;

    # read a molecule
    my $mol = Chemistry::Mol->read('myfile.mol');

    # write a molecule
    $mol->write("myfile.mol");

=cut

Chemistry::Mol->register_format(mdl => __PACKAGE__);

=head1 DESCRIPTION

MDL Molfile (V2000) reader.

This module automatically registers the 'mdl' format with Chemistry::Mol.

The first three lines of the molfile are stored as $mol->name, 
$mol->attr("mdlmol/line2"), and $mol->attr("mdlmol/comment").

This version only reads and writes the basic connection table: atomic symbols, 
coordinates, bonds and bond types. It doesn't read charges, isotopes, or 
any extended properties yet.

This module is part of the PerlMol project, L<http://www.perlmol.org>.

=cut

sub read_mol {
    my ($self, $fh, %opts) = @_;
    return if $fh->eof;

    %opts = ( slurp => 1, %opts );
    my $mol_class  = $opts{mol_class}  || "Chemistry::Mol";
    my $atom_class = $opts{atom_class} || $mol_class->atom_class;
    my $bond_class = $opts{bond_class} || $mol_class->bond_class;
    local $_;

    my $mol = $mol_class->new();

    # header
    my $name    = <$fh>; chomp $name;
    my $line2   = <$fh>; chomp $line2;
    my $comment = <$fh>; chomp $comment;
    $mol->name($name);
    $mol->attr("mdlmol/line2", $line2);
    $mol->attr("mdlmol/comment", $comment);

    # counts line
    defined ($_ = <$fh>) or croak "unexpected end of file";
    my ($na, $nb) = unpack("A3A3", $_);

    # atom block
    for(1 .. $na) { # for each atom...
        defined ($_ = <$fh>) or croak "unexpected end of file";
        my ($x, $y, $z, $symbol) = unpack("A10A10A10xA3", $_);
        $mol->new_atom(symbol => $symbol, coords => [$x*1, $y*1, $z*1]);
    }

    # bond block
    for(1 .. $nb) { # for each bond...
        defined ($_ = <$fh>) or croak "unexpected end of file";
        my ($a1, $a2, $type) = map {$_*1} unpack("A3A3A3", $_);
        my $order = $type =~ /^[123]$/ ? $type : 1;
        $mol->new_bond(
            type => $type, 
            atoms => [$mol->atoms($a1,$a2)],
            order => $order,
        );
    }
    if ($opts{slurp}) {
        1 while <$fh>;
    }
    while (<$fh>) {
        last if /^M  END/ or /^\$\$\$\$/;
    }

    return $mol;
}

sub name_is {
    my ($self, $fname) = @_;
    $fname =~ /\.mol$/i;
}


sub file_is {
    my ($self, $fname) = @_;
    $fname =~ /\.mol$/i;
}


sub write_string {
    my ($self, $mol, %opts) = @_;

    no warnings 'uninitialized';
    my $s = sprintf "%s\n      perlmol   \n\n", $mol->name;
    $s .= sprintf "%3i%3i%3i%3i%3i%3i%3i%3i%3i%3i%3i%6s\n", 
        0+$mol->atoms, 0+$mol->bonds, 
        0, 0, 0, 0, 0, 0, 0, 0, 999, "V2000";   # "counts" line

    my $i = 1;
    my %idx_map;
    for my $atom ($mol->atoms) {
        my ($x, $y, $z) = $atom->coords->array;

        $s .= sprintf 
            "%10.4f%10.4f%10.4f %-3s%2i%3i%3i%3i%3i%3i%3i%3i%3i%3i%3i%3i\n",
            $x, $y, $z, $atom->symbol,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
        $idx_map{$atom->id} = $i++;
    }

    for my $bond ($mol->bonds) {
        my ($a1, $a2) = map {$idx_map{$_->id}} $bond->atoms;
        $s .= sprintf "%3i%3i%3i%3i%3i%3i%3i\n", 
            $a1, $a2, $bond->order,
            0, 0, 0, 0;
    }

    $s .= "M  END\n";
    $s;
}



1;

=head1 VERSION

0.18

=head1 SEE ALSO

L<Chemistry::Mol>

The MDL file format specification.
L<http://www.mdl.com/downloads/public/ctfile/ctfile.pdf> or
Arthur Dalby et al., J. Chem. Inf. Comput. Sci, 1992, 32, 244-255.

The PerlMol website L<http://www.perlmol.org/>

=head1 AUTHOR

Ivan Tubert-Brohman <itub@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005 Ivan Tubert-Brohman. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=cut

