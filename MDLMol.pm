package Chemistry::File::MDLMol;
$VERSION = '0.10';

use base "Chemistry::File";
use Chemistry::Mol;
use strict;

=head1 NAME

Chemistry::File::MDLMol

=head1 SYNOPSIS

    use Chemistry::File::MDLMol 'mdlmol_read';

    my $mol = mdlmol_read("myfile.mol");

=cut

Chemistry::Mol->register_format(mdl => __PACKAGE__);

=head1 DESCRIPTION

MDL Molfile (V2000) reader.

This module automatically registers the 'mdl' format with Chemistry::Mol.

=cut

sub parse_string {
    my $self = shift;
    my $string = shift;
    my (%opts) = @_;
    my $mol_class = $opts{mol_class} || "Chemistry::Mol";
    my $atom_class = $opts{atom_class} || "Chemistry::Atom";
    my $bond_class = $opts{bond_class} || "Chemistry::Bond";
    my $m;
    my ($na, $nb);
    my $n = 0;
    local $_;

    my $mol = $mol_class->new();
    my @lines = split /\n/, $string;
    my ($name, $line2, $comment) = splice @lines, 0, 3;
    $mol->name($name);
    $mol->attr("mdlmol/line2", $line2);
    $mol->attr("comment", $comment);

    $_ = shift @lines;
    ($na, $nb) = map {s/ //g; $_} unpack("A3A3", $_);
    for(1 .. $na){
        $_ = shift @lines;
        my ($x, $y, $z, $symbol) = unpack("A10A10A10xA3", $_);
        $mol->add_atom($atom_class->new(symbol=>$symbol, coords=>[$x, $y, $z], id => "a".++$n));
    }


    for(1..$nb){
        $_ = shift @lines;
        my ($a1, $a2, $type) = map {s/ //g; $_} unpack("A3A3A3", $_);
        $mol->add_bond($bond_class->new(type => $type, atoms =>
        [$mol->{byId}{"a$a1"}, $mol->{byId}{"a$a2"}]));
    }

    return $mol;
}


sub file_is {
    my $self = shift;
    my $fname = shift;
    
    return 1 if $fname =~ /\.mol$/i;

#   open F, $fname or croak "Could not open file $fname";
    
#    while (<F>){
#	if (/^ATOM/) {
#	    close F;
#	    return 1;
#	}
#    }

    return 0;
}

1;

=head1 SEE ALSO

Chemistry::Mol

=head1 AUTHOR

Ivan Tubert-Brohman <ivan@tubert.org>

=head1 VERSION

$Id$

=cut

