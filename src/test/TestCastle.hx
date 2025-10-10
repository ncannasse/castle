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