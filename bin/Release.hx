class Release {
	
	public static function main() {
		var files = [
			"package.json",
			"icon.png",
			"index.html",
			"castle.js",
			"style.css",
			"dock",
			"libs",
		];
		
		var zfiles = [];
		
		function add(f:String) {
			if( sys.FileSystem.isDirectory(f) ) {
				for( file in sys.FileSystem.readDirectory(f) )
					add(f+"/"+file);
				return;
			}
			var data = sys.io.File.getBytes(f);
			zfiles.push({
				fileTime : Date.now(),
				fileSize : data.length,
				fileName : f,
				dataSize : data.length,
				data : data,
				compressed : false,
				crc32 : null,
				extraFields : null,
			});
		}
		for( f in files )
			add(f);			
		var o = new haxe.io.BytesOutput();
		new haxe.zip.Writer(o).write(Lambda.list(zfiles));
		var bytes = o.getBytes();
		sys.io.File.saveBytes("package.nw", bytes);
		
		/*
		var platforms = [
			"win",
			"osx", // When unzipping with OSX, the rights will be correctly set on the .app
			"linux", // TODO : linux uses TGZ for rights, we lack format.tgz.Writer atm
		];
		for( pf in platforms ) {
			var zip = 'node-webkit-$pf.zip';
			if( !sys.FileSystem.exists(zip) ) {
				Sys.println('$zip not found');
				continue;
			}
			var z = new haxe.zip.Reader(sys.io.File.read(zip)).read();
			for( e in z ) {
				switch( e.fileName ) {
				case "nw":
					e.fileName = "cdb";
				case "nw.exe":
					e.fileName = "cdb.exe";
				case "nwsnapshot", "nwsnapshot.exe":
					z.remove(e);
				default:
					if( e.fileName.substr(0, 15) == "node-webkit.app" )
						e.fileName = "castleDB.app" + e.fileName.substr(15);
				}
			}
			z.add({
				fileTime : Date.now(),
				fileSize : bytes.length,
				fileName : "package.nw",
				dataSize : bytes.length,
				data : bytes,
				compressed : false,
				crc32 : null,
				extraFields : null,
			});
			var out = 'castledb-$pf.zip';
			var o = sys.io.File.write(out);
			new haxe.zip.Writer(o).write(z);
			o.close();
			Sys.println('$out written');
		}*/
	}

}