package data;
import cdb.Data;
using SheetData
;
class Database {

	var data : cdb.Data;
	public var sheets(get, never) : Array<Sheet>;
	public var compress(get, set) : Bool;

	public function new() {
		data = {
			sheets : [],
			customTypes : [],
			compress : false,
		};
	}

	inline function get_sheets() return data.sheets;
	inline function get_compress() return data.compress;

	function set_compress(b) {
		if( data.compress == b )
			return b;
		data.compress = b;
		for( s in data.sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TLayer(_):
					for( obj in s.getLines() ) {
						var ldat : cdb.Types.Layer<Int> = Reflect.field(obj, c.name);
						if( ldat == null || ldat == cast "" ) continue;
						var d = ldat.decode([for( i in 0...256 ) i]);
						ldat = cdb.Types.Layer.encode(d, data.compress);
						Reflect.setField(obj, c.name, ldat);
					}
				case TTileLayer:
					for( obj in s.getLines() ) {
						var ldat : cdb.Types.TileLayer = Reflect.field(obj, c.name);
						if( ldat == null || ldat == cast "" ) continue;
						var d = ldat.data.decode();
						Reflect.setField(ldat,"data",cdb.Types.TileLayerData.encode(d, data.compress));
					}
				default:
				}
		return b;
	}

	public function createSheet( name : String ) {
		// name already exists
		for( s in data.sheets )
			if( s.name == name )
				return null;
		var s : Sheet = {
			name : name,
			columns : [],
			lines : [],
			separators : [],
			props : {
			},
		};
		data.sheets.push(s);
		return s;
	}

	public function createSubSheet( s : Sheet, c : Column ) {
		var s : Sheet = {
			name : s.name + "@" + c.name,
			props : { hide : true },
			separators : [],
			lines : [],
			columns : [],
		};
		if( c.type == TProperties ) s.props.isProps = true;
		data.sheets.push(s);
		return s;
	}

	public function getCustomTypes() {
		return data.customTypes;
	}

	public function load( content : String ) {
		data = cdb.Parser.parse(content);
	}

	public function save() {
		// process
		for( s in data.sheets ) {
			// clean props
			for( p in Reflect.fields(s.props) ) {
				var v : Dynamic = Reflect.field(s.props, p);
				if( v == null || v == false ) Reflect.deleteField(s.props, p);
			}
			if( s.props.hasIndex ) {
				var lines = s.getLines();
				for( i in 0...lines.length )
					lines[i].index = i;
			}
			if( s.props.hasGroup ) {
				var lines = s.getLines();
				var gid = 0;
				var sindex = 0;
				var titles = s.props.separatorTitles;
				if( titles != null ) {
					// skip first if at head
					if( s.separators[sindex] == 0 && titles[sindex] != null ) sindex++;
					for( i in 0...lines.length ) {
						if( s.separators[sindex] == i ) {
							if( titles[sindex] != null ) gid++;
							sindex++;
						}
						lines[i].group = gid;
					}
				}
			}
		}
		return cdb.Parser.save(data);
	}

}