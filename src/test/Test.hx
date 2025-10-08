import Data;

class Test {
	
	static function main() {
		Data.load(sys.io.File.getContent("res/data.cdb"));
		
		trace(Data.items.get(sword).alt.fx);
		trace(Data.items.get(sword).alt.test);
		trace(switch( Data.items.get(herb).fx ) { case Monster(m): m.id; default: null; } );
		
		for( s in Data.monsters.resolve("wolf").skills[0].sub )
			trace(s);
		
		
		function checkStats(id: String, stats : Weapons_stats) {
			trace(id + ": damage=" + stats.damage + ", speed=" + stats.speed);
		}
		
		var dagger = Data.weapons.get(dagger);
		checkStats("dagger", dagger.stats);

		var armor = Data.armors.get(chainmail);
		checkStats("chainmail", armor.stats);
	}
	
}