package Chemistry::File::SDF;
$VERSION = '0.15';
# $Id$

use base "Chemistry::File";
use Chemistry::Mol;
use Chemistry::File::MDLMol;
use strict;
use warnings;

=head1 NAME

Chemistry::File::SDF - MDL Structure Data File reader/writer

=head1 SYNOPSIS

    use Chemistry::File::SDF;

    my @mols = Chemistry::Mol->read('myfile.sdf');

    # assuming that the file includes a <PKA> data item...
    print $mols[0]->attr("sdf/data")->{PKA}; 

    # write a bunch of molecules to an SDF file
    Chemistry::Mol->write('myfile.sdf', mols => \@mols);

    # or write just one molecule
    $mol->write('myfile.sdf');

=cut

Chemistry::Mol->register_format(sdf => __PACKAGE__);

=head1 DESCRIPTION

MDL SDF (V2000) reader.

This module automatically registers the 'sdf' format with Chemistry::Mol.

The parser returns a list of Chemistry::Mol objects.  SDF data can be accessed
by the $mol->attr method. Attribute names are stored as a hash ref at the
"sdf/data" attribute, as shown in the synopsis. When a data item has a single
line in the SDF file, the attribute is stored as a string; when there's more
than one line, they are stored as an array reference. The rest of the
information on the line that holds the field name is ignored.

This module is part of the PerlMol project, L<http://www.perlmol.org>.

=cut

sub parse_string {
    my ($self, $string, %opts) = @_;
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
    my %data_block;
    for my $item (@items) {
        my ($header, @data) = split /\n/, $item;
        my ($field_name) = $header =~ /<(.*?)>/g;
        warn "SDF: no field name\n", next unless $field_name;
        #$mol->attr("sdf/$field_name", @data == 1 ? $data[0] : \@data);
        $data_block{$field_name} = @data == 1 ? $data[0] : \@data;
        
    }
    $mol->attr("sdf/data", \%data_block);
}

sub write_string {
    my ($self, $mol_ref, %opts) = @_;
    my @mols;
    my $ret = '';

    if ($opts{mols}) {
        @mols = @{$opts{mols}};
    } else {
        @mols = $mol_ref; 
    }

    for my $mol (@mols) {
        $ret .= $mol->print(format => 'mdl');    
        $ret .= format_data($mol->attr('sdf/data')) . '$$$$'."\n";
    }
    $ret;
}

sub format_data {
    my ($data) = @_;
    my $ret = '';
    return $ret unless $data;
    for my $field_name (sort keys %$data) {
        $ret .= ">  <$field_name>\n";
        my $value = $data->{$field_name};
        if (ref $value) {
            $ret .= join "\n", @$value;
        } else {
            $ret .= "$value\n";
        }
        $ret .= "\n";
    }
    $ret;
}
sub file_is {
    my ($self, $fname) = @_;
    
    return 1 if $fname =~ /\.sdf?$/i;
    return 0;
}

sub string_is {
    my ($self, $s) = @_;
    /\$\$\$\$/ ? 1 : 0;
}
1;

=head1 CAVEATS

Note that by storing the SDF data as a hash, there can be only one field with
a given name. The SDF format description is not entirely clear in this regard.

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

