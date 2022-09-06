package Chemistry::File::MDLMol;

# VERSION
# $Id$

use base "Chemistry::File";
use Chemistry::Mol;
use Carp;
use List::Util;
use strict;
use warnings;

our $DEBUG = 0;

=head1 NAME

Chemistry::File::MDLMol - MDL molfile reader/writer

=head1 SYNOPSIS

    use Chemistry::File::MDLMol;

    # read a molecule
    my $mol = Chemistry::Mol->read('myfile.mol');

    # write a molecule
    $mol->write("myfile.mol");

    # use a molecule as a query for substructure matching
    use Chemistry::Pattern;
    use Chemistry::Ring;
    Chemistry::Ring::aromatize_mol($mol);

    my $patt = Chemistry::Pattern->read('query.mol');
    if ($patt->match($mol)) {
        print "it matches!\n";
    }

=cut

Chemistry::Mol->register_format(mdl => __PACKAGE__);

=head1 DESCRIPTION

MDL Molfile (V2000) reader/writer.

This module automatically registers the 'mdl' format with Chemistry::Mol.

The first three lines of the molfile are stored as $mol->name, 
$mol->attr("mdlmol/line2"), and $mol->attr("mdlmol/comment").

This version only reads and writes some of the information available in a
molfile: it reads coordinates, atom and bond types, charges, isotopes,
radicals, and atom lists. It does not read other things such as
stereochemistry, 3d properties, etc.

This module is part of the PerlMol project, L<https://github.com/perlmol>.

=head2 Query properties

The MDL molfile format supports query properties such as atom lists, and
special bond types such as "single or double", "single or aromatic", "double or
aromatic", "ring bond", or "any". These properties are supported by this module
in conjunction with L<Chemistry::Pattern>. However, support for query properties
is currently read-only, and the other properties listed in the specification
are not supported yet.

So that atom and bond objects can use these special query options, the
conditions are represented as Perl subroutines. The generated code can be
read from the 'mdlmol/test_sub' attribute:

    $atom->attr('mdlmol/test_sub');
    $bond->attr('mdlmol/test_sub');
 
This may be useful for debugging, such as when an atom doesn't seem to match as
expected.

=head2 Aromatic Queries

To be able to search for aromatic substructures are represented by Kekule
structures, molfiles that are read as patterns (with
C<Chemistry::Pattern->read) are aromatized automatically by using the
L<Chemistry::Ring> module. The default bond test from Chemistry::Pattern::Bond
is overridden by one that checks the aromaticity in addition to the bond order.
The test is,

    $patt->aromatic ?  $bond->aromatic 
        : (!$bond->aromatic && $patt->order == $bond->order);

That is, aromatic pattern bonds match aromatic bonds, and aliphatic pattern
bonds match aliphatic bonds with the same bond order.
    

=cut


# some constants, based on tables from the file format specification

my %OLD_CHARGE_MAP = (
    1 => 3,
    2 => 2,
    3 => 1,
    4 => 0,
    5 => -1,
    6 => -2,
    7 => -3,
);

my %BOND_TYPE_EXPR = (
    4 => '($bond->aromatic)',
    5 => '($bond->order == 1 or $bond->order == 2)',
    6 => '($bond->order == 1 or $bond->aromatic)',
    7 => '($bond->order == 2 or $bond->aromatic)',
    8 => '(1)',                                         # any bond
);

my %BOND_TOPOLOGY_EXPR = (
    1 => '@{$bond->attr("ring/rings")||[]}',
    2 => '! @{$bond->attr("ring/rings")||[]}',
);


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
    my ($na, $nb, undef, undef, $is_chiral) = unpack("A3A3A3A3A3", $_);

    $mol->attr("mdlmol/chiral", int $is_chiral);

    my %old_charges;
    my %old_radicals;

    # atom block
    for my $i (1 .. $na) { # for each atom...
        defined (my $line = <$fh>) or croak "unexpected end of file";
        my ($x, $y, $z, $symbol, $mass, $charge)
            = unpack("A10A10A10xA3A2A3", $line);
        
        $old_charges{$i} = $OLD_CHARGE_MAP{$charge}
            if $OLD_CHARGE_MAP{$charge};
        $old_radicals{$i} = 2
            if $charge && $charge == 4;
        my $mass_number;
        if( int $mass && eval { require Chemistry::Isotope } ) {
            my $abundance =
                Chemistry::Isotope::isotope_abundance($symbol);
            ($mass_number) = sort { $abundance->{$b} cmp
                                    $abundance->{$a} }
                                  sort keys %$abundance;
            $mass_number += $mass;
        } elsif( int $mass ) {
            warn "no Chemistry::Isotope, cannot read mass number " .
                 "from atom block\n";
        }
        $mol->new_atom(
            symbol         => $symbol, 
            coords         => [$x*1, $y*1, $z*1],
            mass_number    => $mass_number,
        );
    }

    # bond block
    for my $i (1 .. $nb) { # for each bond...
        no warnings 'numeric';
        defined ($_ = <$fh>) or croak "unexpected end of file";
        my ($a1, $a2, $type, $stereo, $topology, $rxn) 
            = map {$_*1} unpack("A3A3A3A3x3A3A3", $_);
        my $order = $type =~ /^[123]$/ ? $type : 1;
        my $bond = $mol->new_bond(
            type => $type, 
            atoms => [$mol->atoms($a1,$a2)],
            order => $order,
            attr => { 'mdlmol/stereo' => int $stereo },
        );
        if ($mol->isa('Chemistry::Pattern')) {
            $self->bond_expr($bond, $i, $type, $topology);
        }
    }

    # properties block
    while (<$fh>) {
        if (/^M  END/ or /^\$\$\$\$/) {
            last;
        } elsif (/^M  (...)/) { # generic extended property handler
            if ($1 eq 'CHG' or $1 eq 'RAD'){ # XXX
                # clear old-style info
                %old_radicals = (); 
                %old_charges  = ();
            }

            my $method = "M_$1";
            $self->$method($mol, $_) if $self->can($method);
        }
    }

    # add old-style charges and radicals if they still apply
    while (my ($key, $val) = each %old_charges) {
        $mol->atoms($key)->formal_charge($val);
    }
    while (my ($key, $val) = each %old_radicals) {
        $mol->atoms($key)->formal_radical($val);
    }

    # make sure we get to the end of the file
    if ($opts{slurp}) {
        1 while <$fh>;
    }

    $mol->add_implicit_hydrogens;

    if ($mol->isa('Chemistry::Pattern')) {
        require Chemistry::Ring;
        Chemistry::Ring::aromatize_mol($mol);
    }

    return $mol;
}

sub bond_expr {
    my ($self, $bond, $i, $type, $topology) = @_;
    my @bond_exprs;
    my $s = $BOND_TOPOLOGY_EXPR{$topology};
    push @bond_exprs, $s if $s;
    $s = $BOND_TYPE_EXPR{$type};
    push @bond_exprs, $s if $s;
    if (@bond_exprs) {
        my $expr = join " and ", @bond_exprs;
        my $sub_txt = <<SUB;
            sub {
                no warnings;
                my (\$patt, \$bond) = \@_;
                $expr;
            };
SUB
        print "MDLMol bond($i) sub: <<<<$sub_txt>>>\n" if $DEBUG;
        $bond->attr('mdlmol/test_sub' => $sub_txt);
        $bond->test_sub(eval $sub_txt);
    } else { # default bond sub
        $bond->test_sub(\&default_bond_test);
    }
}

sub default_bond_test {
    no warnings;
    my ($patt, $bond) = @_;
    $patt->aromatic ?  $bond->aromatic 
        : (!$bond->aromatic && $patt->order == $bond->order);
}


sub M_CHG {
    my ($self, $mol, $line) = @_;
    my ($m, $type, $n, %data) = split " ", $line;
    while (my ($key, $val) = each %data) {
        $mol->atoms($key)->formal_charge($val);
    }
}

sub M_RAD {
    my ($self, $mol, $line) = @_;
    my ($m, $type, $n, %data) = split " ", $line;
    while (my ($key, $val) = each %data) {
        $mol->atoms($key)->formal_radical($val);
    }
}

sub M_ISO {
    my ($self, $mol, $line) = @_;
    my ($m, $type, $n, %data) = split " ", $line;
    while (my ($key, $val) = each %data) {
        $mol->atoms($key)->mass_number($val);
    }
}

sub M_ALS {
    my ($self, $mol, $line) = @_;

    return unless $line =~ /^M  ALS (...)(...) (.)/;
    my ($n, $cnt, $exclude) = ($1, $2, $3);
    my @symbols;
    $exclude = $exclude =~ /^[Tt]$/ ? '!' : '';

    # parse the symbols out of the atom list line
    for my $i (0 .. $cnt-1) {
        my $s = substr $_, 16+$i*4, 4;
        $s =~ s/\s+//g;
        push @symbols, $s;
    }

    # save attr
    $mol->atoms($n)->attr('mdlmol/atom_list' => $_);

    # create test sub
    if ($mol->isa('Chemistry::Pattern')) {
        my $sub_txt = <<SUB;
            sub{
                my (\$patt, \$atom) = \@_;
                my \$sym = \$atom->symbol;
                $exclude (List::Util::first {\$sym eq \$_} \@symbols);
            };
SUB
        print "MDLMol atom($n) sub: <<<<$sub_txt>>>\n" if $DEBUG;
        print "MDLMol symbol list: (@symbols)\n" if $DEBUG;
        $mol->atoms($n)->attr('mdlmol/test_sub' => $sub_txt);
        $mol->atoms($n)->test_sub(eval $sub_txt);
    }
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
    my @charged_atoms;
    my @isotope_atoms;
    my @radical_atoms;
    for my $atom ($mol->atoms) {
        my ($x, $y, $z) = $atom->coords->array;

        $s .= sprintf 
            "%10.4f%10.4f%10.4f %-3s%2i%3i%3i%3i%3i%3i%3i%3i%3i%3i%3i%3i\n",
            $x, $y, $z, $atom->symbol,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
        push @charged_atoms, $i if $atom->formal_charge;
        push @isotope_atoms, $i if $atom->mass_number;
        push @radical_atoms, $i if $atom->formal_radical;
        $idx_map{$atom->id} = $i++;
    }

    for my $bond ($mol->bonds) {
        my ($a1, $a2) = map {$idx_map{$_->id}} $bond->atoms;
        $s .= sprintf "%3i%3i%3i%3i%3i%3i%3i\n", 
            $a1, $a2, $bond->order,
            0, 0, 0, 0;
    }
    
    while (@charged_atoms) {
        my $n = @charged_atoms > 8 ? 8 : @charged_atoms;
        $s .= "M  CHG  $n";
        for my $key (splice @charged_atoms, 0, $n) {
            $s .= sprintf "%4d%4d", $key, $mol->atoms($key)->formal_charge;
        }
        $s .= "\n";
    }
    while (@isotope_atoms) {
        my $n = @isotope_atoms > 8 ? 8 : @isotope_atoms;
        $s .= "M  ISO  $n";
        for my $key (splice @isotope_atoms, 0, $n) {
            $s .= sprintf "%4d%4d", $key, $mol->atoms($key)->mass_number;
        }
        $s .= "\n";
    }
    while (@radical_atoms) {
        my $n = @radical_atoms > 8 ? 8 : @radical_atoms;
        $s .= "M  RAD  $n";
        for my $key (splice @radical_atoms, 0, $n) {
            $s .= sprintf "%4d%4d", $key, $mol->atoms($key)->formal_radical;
        }
        $s .= "\n";
    }

    $s .= "M  END\n";
    $s;
}



1;

=head1 SOURCE CODE REPOSITORY

L<https://github.com/perlmol/Chemistry-File-MDLMol>

=head1 SEE ALSO

L<Chemistry::Mol>

The MDL file format specification.
L<https://discover.3ds.com/ctfile-documentation-request-form#_ga=2.229779804.1581205944.1643725102-a2d5f010-6f4c-11ec-a2da-e3641d195888>,
L<https://discover.3ds.com/sites/default/files/2020-08/biovia_ctfileformats_2020.pdf>,
L<https://web.archive.org/web/20070927033700/http://www.mdl.com/downloads/public/ctfile/ctfile.pdf>,
or Arthur Dalby et al., J. Chem. Inf. Comput. Sci, 1992, 32, 244-255.
L<https://doi.org/10.1021/ci00007a012>.

=head1 AUTHOR

Ivan Tubert-Brohman <itub@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2009 Ivan Tubert-Brohman. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=cut

