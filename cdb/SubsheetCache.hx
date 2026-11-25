package cdb;

private typedef SubsheetCacheEntry = {
	var lines : Array<Dynamic>;
	var byGlobalId : Null<Map<String, Dynamic>>;
	var byScopedId : Null<haxe.ds.ObjectMap<Dynamic, Map<String, Dynamic>>>;
	var idColumn : Null<cdb.Data.Column>;
}

class SubsheetCache {
	static var cache : haxe.ds.ObjectMap<Data, Map<String, SubsheetCacheEntry>> = new haxe.ds.ObjectMap();

	public static function getEntry(data:Data, name:String) : SubsheetCacheEntry {
		var perData = cache.get(data);
		if (perData == null) {
			perData = new Map();
			cache.set(data, perData);
		}

		var entry = perData.get(name);
		if (entry != null)
			return entry;

		var sheet = findSheet(data, name);
		if (sheet == null)
			throw "'" + name + "' not found in CDB data";

		entry = buildEntry(data, sheet);
		perData.set(name, entry);
		return entry;
	}

	public static function getLines(data:Data, name:String) : Array<Dynamic> {
		return getEntry(data, name).lines;
	}
	
	static function findSheet(data:Data, name:String) : Data.SheetData {
		for (s in data.sheets)
			if (s.name == name)
				return s;
		return null;
	}

	static function getIdColumn(sheet:cdb.Data.SheetData) : Null<cdb.Data.Column> {
		for (c in sheet.columns)
			switch (c.type) {
				case TId: return c;
				default:
			}
		return null;
	}

	static function buildEntry(data:Data, sheet:cdb.Data.SheetData) : SubsheetCacheEntry {
		@:privateAccess
		var refs = Module.getSheetLineRefs(data.sheets, sheet);
		var lines = [for (r in refs) r.line];
		@:privateAccess
		cdb.Types.Index.initLinesVirtual(sheet, lines);

		var idCol = getIdColumn(sheet);
		var byGlobalId : Map<String, Dynamic> = null;
		var byScopedId : haxe.ds.ObjectMap<Dynamic, Map<String, Dynamic>> = null;

		if (idCol != null) {
			var cname = idCol.name;

			if (idCol.scope == null) {
				byGlobalId = new Map();
				for (r in refs) {
					var id:String = Reflect.field(r.line, cname);
					if (id != null && id != "") {
						if (byGlobalId.exists(id))
							throw "Duplicate global subsheet id '" + id + "' in sheet '" + sheet.name + "'";
						byGlobalId.set(id, r.line);
					}
				}
			} else {
				byScopedId = new haxe.ds.ObjectMap();
				for (r in refs) {
					var id:String = Reflect.field(r.line, cname);
					if (id == null || id == "") continue;

					var map = byScopedId.get(r.parent);
					if (map == null) {
						map = new Map();
						byScopedId.set(r.parent, map);
					}

					if (map.exists(id))
						throw "Duplicate local subsheet id '" + id + "' under same parent in sheet '" + sheet.name + "'";

					map.set(id, r.line);
				}
			}
		}

		return {
			lines : lines,
			byGlobalId : byGlobalId,
			byScopedId : byScopedId,
			idColumn : idCol,
		};
	}
}