package Chemistry::File::MDLMol;
$VERSION = '0.15';

use base "Chemistry::File";
use Chemistry::Mol;
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

sub parse_string {
    my $self = shift;
    my $string = shift;
    my (%opts) = @_;
    my $mol_class = $opts{mol_class} || "Chemistry::Mol";
    my $atom_class = $opts{atom_class} || "Chemistry::Atom";
    my $bond_class = $opts{bond_class} || "Chemistry::Bond";
    my ($na, $nb); # number of atoms and bonds
    my $n = 0;
    local $_;

    my $mol = $mol_class->new();
    my @lines = split /\n/, $string;
    my ($name, $line2, $comment) = splice @lines, 0, 3;
    $mol->name($name);
    $mol->attr("mdlmol/line2", $line2);
    $mol->attr("mdlmol/comment", $comment);

    $_ = shift @lines;
    ($na, $nb) = map {s/ //g; $_} unpack("A3A3", $_);
    for(1 .. $na) { # for each atom...
        $_ = shift @lines;
        my ($x, $y, $z, $symbol) = unpack("A10A10A10xA3", $_);
        $mol->add_atom($atom_class->new(
            symbol=>$symbol, coords=>[$x, $y, $z], id => "a".++$n));
    }


    for(1 .. $nb) { # for each bond...
        $_ = shift @lines;
        my ($a1, $a2, $type) = map {s/ //g; $_} unpack("A3A3A3", $_);
        my $order;
        $order = $type if $type =~ /^[123]$/;
        $mol->add_bond(
            $bond_class->new(
                type => $type, 
                atoms => [$mol->{byId}{"a$a1"}, $mol->{byId}{"a$a2"}],
                order => $order || 1
            )
        );
    }

    return $mol;
}


sub file_is {
    my $self = shift;
    my $fname = shift;
    
    return 1 if $fname =~ /\.mol$/i;

#   open F, $fname or croak "Could not open file $fname";
    
    return 0;
}


sub write_string {
    my ($self, $mol, %opts) = @_;

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

0.15

=head1 SEE ALSO

L<Chemistry::Mol>

The MDL file format specification.
L<http://www.mdl.com/downloads/public/ctfile/ctfile.pdf> or
Arthur Dalby et al., J. Chem. Inf. Comput. Sci, 1992, 32, 244-255.

The PerlMol website L<http://www.perlmol.org/>

=head1 AUTHOR

Ivan Tubert-Brohman <itub@cpan.org>

=cut

