use Test::More tests => 6;
BEGIN { use_ok('Chemistry::File::SDF') };

my @mols = Chemistry::Mol->read("t/1.sdf");

ok(@mols == 8, "read 8");
my $i;
for my $mol(@mols) {
    $i++ if $mol->isa('Chemistry::Mol');
}

ok($i == @mols, "isa Chemistry::Mol");
is($mols[1]->name, "[2-(4-Bromo-phenoxy)-ethyl]-(4-dimethylamino-6-methoxy-[1,3,5]triazin-2-yl)-cyan", "name");
ok($mols[1]->attr("sdf/data")->{'PKA'} == 4.65, "attr");

my $fname = "t/rw.sdf";
open F, "<", "$fname" or die "couldn't open $fname; $!\n";
my $sdf_str;
{ local $/; $sdf_str = <F> }
@mols = Chemistry::Mol->parse($sdf_str, format => 'sdf');
my $sdf_out = Chemistry::Mol->print(format => 'sdf', mols => \@mols);
ok($sdf_str eq $sdf_out, "read-write test");

