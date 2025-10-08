import Data;

class Test {
	
	static function main() {
		Data.load(haxe.Resource.getString("test.cdb"));
		
		
		
		
		trace(Data.items.get(sword).alt.fx);
		trace(Data.items.get(sword).alt.test);
		trace(switch( Data.items.get(herb).fx ) { case Monster(m): m.id; default: null; } );
		
		for( s in Data.monsters.resolve("wolf").skills[0].sub )
			trace(s);
		
		
		var sword = Data.weapons.get(longsword);
		trace("Longsword: damage=" + sword.stats.damage + ", speed=" + sword.stats.speed);
		
		var armor = Data.armors.get(chainmail);
		trace("Chainmail: damage=" + armor.stats.damage + ", speed=" + armor.stats.speed);
		
		var dagger = Data.weapons.get(dagger);
		var leather = Data.armors.get(leather);
		trace("Dagger: damage=" + dagger.stats.damage + ", speed=" + dagger.stats.speed);
		trace("Leather: damage=" + leather.stats.damage + ", speed=" + leather.stats.speed);
	}
	
}