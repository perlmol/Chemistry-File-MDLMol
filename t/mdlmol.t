use Test::More tests => 9;
BEGIN { use_ok('Chemistry::File::MDLMol') };

my $mol = Chemistry::Mol->read("t/1.mol");

isa_ok($mol, 'Chemistry::Mol', '$mol');
is($mol->name, "trans-Difluorodiazene", "name");
is($mol->attr("mdlmol/line2"), "  -ISIS-            3D", "line2");
is($mol->attr("mdlmol/comment"), "r23 N2F2 FN=NF", "comment");
is($mol->atoms(2)->symbol, "N", "symbol");
is($mol->atoms(3)->y3, 1.2409, "coords");
is($mol->bonds(1)->type, 2, "bond type");
is($mol->bonds(1)->order, 2, "bond order");

