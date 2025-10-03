import dat.Data;

class Test {
	
	static function main() {
		dat.Data.load(haxe.Resource.getString("test.cdb"));
		
		
		
		
		trace(dat.Data.items.get(sword).alt.fx);
		trace(dat.Data.items.get(sword).alt.test);
		trace(switch( dat.Data.items.get(herb).fx ) { case Monster(m): m.id; default: null; } );
		
		for( s in dat.Data.monsters.resolve("wolf").skills[0].sub )
			trace(s);
		
		// Test shared structure references
		trace("=== Testing Shared Structures ===");
		
		// Test weapon stats (master structure)
		var sword = dat.Data.weapons.get(longsword);
		trace("Longsword: damage=" + sword.stats.damage + ", speed=" + sword.stats.speed);
		
		// Test armor stats (references weapons@stats structure)
		var armor = dat.Data.armors.get(chainmail);
		trace("Chainmail: damage=" + armor.stats.damage + ", speed=" + armor.stats.speed);
		
		// Verify both use the same structure (both should have damage and speed fields)
		var dagger = dat.Data.weapons.get(dagger);
		var leather = dat.Data.armors.get(leather);
		trace("Dagger: damage=" + dagger.stats.damage + ", speed=" + dagger.stats.speed);
		trace("Leather: damage=" + leather.stats.damage + ", speed=" + leather.stats.speed);
	}
	
}