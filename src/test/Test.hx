import dat.Data;

class Test {
	
	static function main() {
		#if js
		dat.Data.load(null);
		#else
		dat.Data.load(haxe.Resource.getString("test.cdb"));
		#end
		
		
		
		
		trace(dat.Data.items.get(sword).alt.fx);
		
		for( s in dat.Data.monsters.resolve("wolf").skills[0].sub )
			trace(s);
	}
	
}