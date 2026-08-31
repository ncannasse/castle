class Run {
	public static function main() {
		Sys.setCwd("bin");
		if( sys.FileSystem.exists("nwjs") )
			Sys.command("start nwjs\\nw.exe --nwapp package.json");
		else {
			var path = Sys.getCwd();
			path = StringTools.replace(path, "/", "\\");
			path = StringTools.replace(path, "\\\\", "\\");
			Sys.println('NWjs is required to run CastleDB.');
			Sys.println('');
			Sys.println('Get it on https://nwjs.io and unzip it in: "$path\\bin\\nwjs\\"');
			Sys.println(' $path\\bin\\nwjs\\');
			Sys.println('');
			Sys.println('The "nw.exe" should be in:');
			Sys.println(' $path\\bin\\nwjs\\nw.exe');
			Sys.println('');
		}
		Sys.exit(0);
	}
}