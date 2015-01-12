package cdb;


class SqlConnection implements sys.db.Connection {

	var file : String;
	var data : Data;
	var modified : Bool;
	var autoCommit = true;
	var sheets : Map<String, Data.Sheet>;

	public function new( file : String ) {
		this.file = file;
		load();
	}

	function load() {
		data = cdb.Parser.parse(sys.io.File.getContent(file));
		modified = false;
		sheets = [for( s in data.sheets ) if( !s.props.hide ) s.name => s];
	}

	function flush() {
		if( !modified ) return;
		sys.io.File.saveContent(file, cdb.Parser.save(data));
		modified = false;
	}

	public function close() {
		flush();
		file = null;
		data = null;
	}

	public function request( s : String ) : sys.db.ResultSet {
		var p = new SqlParser();
		var r = p.parse(s);
		switch( r ) {
		case Select(fields, table, cond):
			var s = sheets.get(table);
			if( s == null ) throw "Unknown table " + table;
		case CreateTable(_), AlterTable(_):
			trace(r+"<br>");
			return null;
		default:
		}
		throw "Unsupported query " + r;
	}

	public function escape( s : String ) : String {
		throw "TODO " + s;
		return s;
	}

	public function quote( s : String ) : String {
		throw "TODO";
		return s;
	}

	public function addValue( s : StringBuf, v : Dynamic ) {
		throw "TODO";
	}

	public function lastInsertId() {
		throw "TODO";
		return 0;
	}

	public function dbName() {
		return "CDB";
	}

	public function startTransaction() {
		autoCommit = false;
	}

	public function commit() {
		flush();
		autoCommit = true;
	}

	public function rollback() {
		load();
		autoCommit = true;
	}
}