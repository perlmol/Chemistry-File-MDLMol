package Chemistry::File::SDF;
$VERSION = '0.10';

use base "Chemistry::File";
use Chemistry::Mol;
use Chemistry::File::MDLMol;
use strict;

=head1 NAME

Chemistry::File::SDF - MDL Structure Data File reader

=head1 SYNOPSIS

    use Chemistry::File::SDF;

    my @mols = Chemistry::Mol->read('myfile.sdf');

    # assuming that the file includes a <PKA> data item...
    print $mols[0]->attr("sdf/<PKA>"); 

=cut

Chemistry::Mol->register_format(sdf => __PACKAGE__);

=head1 DESCRIPTION

MDL SDF (V2000) reader.

This module automatically registers the 'sdf' format with Chemistry::Mol.

The parser returns a list of Chemistry::Mol objects.
SDF data can be accessed by the $mol->attr method. Attribute names are
prefixed by "sdf/", as shown in the synopsis. When a data item has a single
line in the SDF file, the attribute is stored as a string; when there's more
than one line, they are stored as an array reference.

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
        parse_data($mol, $mol_string);
    }
    @mols;
}


sub parse_data {
    my ($mol, $mol_string) = @_;
    my (@items) = split /\n>/, $mol_string; 
    shift @items; # drop everything until first datum
    for my $item (@items) {
        my ($header, @data) = split /\n/, $item;
        my ($field_name) = $header =~ /<.*?>/g;
        warn "SDF: no field name\n", next unless $field_name;
        $mol->attr("sdf/$field_name", @data == 1 ? $data[0] : \@data);
    }
}


sub file_is {
    my $self = shift;
    my $fname = shift;
    
    return 1 if $fname =~ /\.sdf?$/i;

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

