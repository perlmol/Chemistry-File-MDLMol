package Chemistry::File::MDLMol;
$VERSION = '0.10';

use base "Chemistry::File";
use Chemistry::Mol;
use strict;

=head1 NAME

Chemistry::File::MDLMol - MDL molfile reader

=head1 SYNOPSIS

    use Chemistry::File::MDLMol;

    my $mol = Chemistry::Mol->read('myfile.mol');
    print $mol->print;

=cut

Chemistry::Mol->register_format(mdl => __PACKAGE__);

=head1 DESCRIPTION

MDL Molfile (V2000) reader.

This module automatically registers the 'mdl' format with Chemistry::Mol.

The first three lines of the molfile are stored as $mol->name, 
$mol->attr("mdlmol/line2"), and $mol->attr("mdlmol/comment").

This version only reads the basic connection table: atomic symbols, 
coordinates, bonds and bond types. It doesn't read charges, isotopes, or 
any extended properties yet.

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
        $mol->add_atom($atom_class->new(symbol=>$symbol, coords=>[$x, $y, $z], id => "a".++$n));
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
                order => $order
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

1;

=head1 SEE ALSO

L<Chemistry::Mol>

The MDL file format specification.
L<http://www.mdl.com/downloads/public/ctfile/ctfile.pdf> or
Arthur Dalby et al., J. Chem. Inf. Comput. Sci, 1992, 32, 244-255.

=head1 AUTHOR

Ivan Tubert-Brohman <itub@cpan.org>

=cut

