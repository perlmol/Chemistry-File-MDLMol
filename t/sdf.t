use Test::More tests => 5;
BEGIN { use_ok('Chemistry::File::SDF') };

my @mols = Chemistry::Mol->read("t/1.sdf");

ok(@mols == 8, "read 8");
my $i;
for my $mol(@mols) {
    $i++ if $mol->isa('Chemistry::Mol');
}

ok($i == @mols, "isa Chemistry::Mol");
is($mols[1]->name, "[2-(4-Bromo-phenoxy)-ethyl]-(4-dimethylamino-6-methoxy-[1,3,5]triazin-2-yl)-cyan", "name");
ok($mols[1]->attr("sdf/<PKA>") == 4.65, "attr");

