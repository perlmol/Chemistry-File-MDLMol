package Chemistry::File::SDF;
$VERSION = '0.10';

use base "Chemistry::File";
use Chemistry::Mol;
use Chemistry::File::MDLMol;
use strict;

=head1 NAME

Chemistry::File::SDF

=head1 SYNOPSIS

=cut

Chemistry::Mol->register_format(sdf => __PACKAGE__);

=head1 DESCRIPTION

MDL SDF (V2000) reader.

This module automatically registers the 'sdf' format with Chemistry::Mol.

=cut

sub parse_string {
    my $self = shift;
    my $string = shift;
    my (%opts) = @_;
    my @mols;

    $string =~ s/\r\n?/\n/g; # normalize EOL
    my @mol_strings = split /\$\$\$\$\n/, $string;
    for my $mol_string (@mol_strings) {
        my $mol = Chemistry::File::MDLMol->parse_string($mol_string, %opts);
        push @mols, $mol;
    }
    @mols;
}


sub file_is {
    my $self = shift;
    my $fname = shift;
    
    return 1 if $fname =~ /\.sdf?$/i;

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

