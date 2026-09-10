import haxe.unit.*;
import Data;

class TestCastle extends haxe.unit.TestCase {
	static var db : cdb.Database;

	function test() {
		assertTrue(Data.items.get(sword).alt.fx.match(Poison(_)));
		assertEquals(Data.MonstersKind.wolf, switch (Data.items.get(herb).fx) { case Monster(m): m.id; default: null; });
		assertEquals(10, Data.monsters.resolve("wolf").skills[0].sub[0].subX);

		var s = db.getSheet("items");
		assertEquals(2, s.getReferencesFromId("herb").length);
		assertEquals(2, s.getReferencesFromId("healp").length);
		
		
		function checkStats(id: String, stats : Weapons_stats) {
			return id + ": damage=" + stats.damage + ", speed=" + stats.speed;
		}
		
		var dagger = Data.weapons.get(dagger);
		assertEquals("dagger: damage=8, speed=10", checkStats("dagger", dagger.stats));

		var armor = Data.armors.get(chainmail);
		assertEquals("chainmail: damage=0, speed=-2", checkStats("chainmail", armor.stats));

		var sheet = db.getSheet("items");
		var psheet = db.getSheet("items@ingredients");
		var subSheet = new cdb.Sheet(db,
			{ columns: psheet.columns, props: psheet.props, name: psheet.name, lines : Reflect.field(sheet.getLines()[2], "ingredients"), separators: [] },
			"items@ingredients:2",
			{ sheet: sheet, column: 4, line: 2 });
		assertEquals(3, subSheet.getReferencesFromId("Water").length);
		assertEquals(0, subSheet.getReferencesFromId("Seed").length);

		var psheet = db.getSheet("items@ingredients");
		var subSheet = new cdb.Sheet(db,
			{ columns: psheet.columns, props: psheet.props, name: psheet.name, lines : Reflect.field(sheet.getLines()[1], "ingredients"), separators: [] },
			"items@ingredients:1",
			{ sheet: sheet, column: 4, line: 1 });
		assertEquals(1, subSheet.getReferencesFromId("Water").length);
	}

	function testEnumStr() {
		// string-stored enum : same end-user API as int-stored enums
		var res = Data.resource.all;
		assertTrue(res[0].climate == Wet);
		assertTrue(res[1].climate == Dry);
		assertEquals("Wet", res[0].climate.toString());
		assertEquals(1, res[0].climate.toInt());
		assertTrue(Resource_climate.ofInt(2) == Frozen);
		assertTrue(Resource_climate.ofString("Dry") == Dry);
		assertEquals(3, Resource_climate.COUNT);
		assertEquals("dry", switch( res[1].climate ) { case Dry: "dry"; case Wet: "wet"; case Frozen: "frozen"; });
		// int-stored enum still works
		assertTrue(res[0].biome == Plain);
		assertEquals(1, res[1].biome.toInt());

		// storage conversions through Database.updateColumn
		var db2 = new cdb.Database();
		db2.load(sys.io.File.getContent("res/data.cdb"));
		var s = db2.getSheet("resource");
		var col = Lambda.find(s.columns, c -> c.name == "climate");
		assertTrue(col.enumStr == true);
		assertEquals("Wet", Reflect.field(s.lines[0], "climate"));
		assertEquals("Wet", db2.valToString(col.type, Reflect.field(s.lines[0], "climate")));
		assertEquals("Dry", db2.getDefault(col));

		// string -> int
		var nc : cdb.Data.Column = { name : "climate", type : TEnum(["Dry","Wet","Frozen"]), typeStr : null, opt : false };
		assertEquals(null, db2.updateColumn(s, col, nc));
		assertFalse(col.enumStr == true);
		assertFalse(Reflect.hasField(col, "enumStr"));
		assertEquals(1, Reflect.field(s.lines[0], "climate"));
		assertEquals(0, Reflect.field(s.lines[1], "climate"));
		assertEquals(0, db2.getDefault(col));

		// int -> string, with a rename (Dry -> Arid) at the same time
		var nc2 : cdb.Data.Column = { name : "climate", type : TEnum(["Arid","Wet","Frozen"]), typeStr : null, opt : false, enumStr : true };
		assertEquals(null, db2.updateColumn(s, col, nc2));
		assertTrue(col.enumStr == true);
		assertEquals("Wet", Reflect.field(s.lines[0], "climate"));
		assertEquals("Arid", Reflect.field(s.lines[1], "climate"));

		// string -> string, rename + remove : removed values become null
		var nc3 : cdb.Data.Column = { name : "climate", type : TEnum(["Wet","Cold"]), typeStr : null, opt : false, enumStr : true };
		assertEquals(null, db2.updateColumn(s, col, nc3));
		assertEquals("Wet", Reflect.field(s.lines[0], "climate"));
		assertEquals(null, Reflect.field(s.lines[1], "climate"));

		// string enum <-> other types
		var sc : cdb.Data.Column = { name : "x", type : TEnum(["A","B"]), typeStr : null, enumStr : true };
		var ic : cdb.Data.Column = { name : "x", type : TInt, typeStr : null };
		var tc : cdb.Data.Column = { name : "x", type : TString, typeStr : null };
		assertEquals(1, db2.getConvFunction(sc, ic).f("B"));
		assertEquals("B", db2.getConvFunction(sc, tc).f("B"));
		assertEquals("B", db2.getConvFunction(ic, sc).f(1));
		assertEquals(null, db2.getConvFunction(ic, sc).f(5));
		assertEquals("A", db2.getConvFunction(tc, sc).f("a"));
	}

	static function main() {
		var data = sys.io.File.getContent("res/data.cdb");

		Data.load(data);
		db = new cdb.Database();
		db.load(data);

		var runner = new TestRunner();
		runner.add(new TestCastle());
		var succeed = runner.run();

		#if sys
			Sys.exit(succeed ? 0 : 1);
		#else
			if (!succeed)
				throw "failed";
		#end
	}
}