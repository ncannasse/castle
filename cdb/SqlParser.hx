/*
 * Copyright (c) 2015, Nicolas Cannasse
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
 * IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
package cdb;

enum Token {
	CInt( v : Int );
	CFloat( v : Float );
	Kwd( s : String );
	Ident( s : String );
	Star;
	Eof;
	POpen;
	PClose;
	Comma;
	Op( op : Binop );
}

enum Binop {
	Eq;
}

enum Expr {
	True;
}

typedef Field = {
	@:optional public var table : Null<String>;
	@:optional public var field : Null<String>;
	@:optional public var all : Null<Bool>;
}

enum SqlType {
	SInt;
	SVarChar( n : Int );
	SDate;
	SDateTime;
	SDouble;
	STinyText;
	STinyInt;
	SMediumText;
}

typedef FieldDesc = {
	var name : String;
	@:optional var type : SqlType;
	@:optional var notNull : Bool;
	@:optional var autoIncrement : Bool;
	@:optional var digits : Int;
}

enum TableProp {
	PrimaryKey( field : Array<String> );
	Engine( name : String );
}

enum FKDelete {
	FKDSetNull;
	FKDCascade;
}

enum AlterCommand {
	AddConstraintFK( name : String, field : String, table : String, targetField : String, ?onDelete : FKDelete );
}

enum Query {
	Select( fields : Array<Field>, table : String, cond : Expr );
	CreateTable( table : String, fields : Array<FieldDesc>, props : Array<TableProp> );
	AlterTable( table : String, alters : Array<AlterCommand> );
}

class SqlParser {

	static var KWDS = [
		"ALTER", "SELECT", "UPDATE", "WHERE", "CREATE", "FROM", "TABLE", "NOT", "NULL", "PRIMARY", "KEY", "ENGINE", "AUTO_INCREMENT",
		"ADD", "CONSTRAINT", "FOREIGN", "REFERENCES", "ON", "DELETE", "SET", "NULL", "CASCADE",
	];

	var query : String;
	var pos : Int;
	var keywords : Map<String,Bool>;
	var sqlTypes : Map<String, SqlType>;
	var idChar : Array<Bool>;
	var cache : Array<Token>;

	public function new() {
		idChar = [];
		for( i in 'A'.code...'Z'.code + 1 )
			idChar[i] = true;
		for( i in 'a'.code...'z'.code + 1 )
			idChar[i] = true;
		for( i in '0'.code...'9'.code + 1 )
			idChar[i] = true;
		idChar['_'.code] = true;
		keywords = [for( k in KWDS ) k => true];
		sqlTypes = [
			"DATE" => SDate,
			"DOUBLE" => SDouble,
			"INT" => SInt,
			"TINYTEXT" => STinyText,
			"MEDIUMTEXT" => SMediumText,
			"TINYINT" => STinyInt,
			"DATETIME" => SDateTime,
		];
	}

	public function parse( q : String ) {
		this.query = q;
		this.pos = 0;
		cache = [];
		#if neko
		try {
			return parseQuery();
		} catch( e : Dynamic ) {
			neko.Lib.rethrow(e+" in " + q);
			return null;
		}
		#else
		return parseQuery();
		#end
	}

	inline function push(t) {
		cache.push(t);
	}

	inline function nextChar() {
		return StringTools.fastCodeAt(query, pos++);
	}

	inline function isIdentChar( c : Int ) {
		return idChar[c];
	}

	function invalidChar(c) {
		throw "Unexpected char '" + String.fromCharCode(c)+"'";
	}

	function token() {
		var t = cache.pop();
		if( t != null ) return t;
		while( true ) {
			var c = nextChar();
			switch( c ) {
			case ' '.code, '\r'.code, '\n'.code, '\t'.code:
				continue;
			case '*'.code:
				return Star;
			case '('.code:
				return POpen;
			case ')'.code:
				return PClose;
			case ','.code:
				return Comma;
			case '='.code:
				return Op(Eq);
			case '`'.code:
				var start = pos;
				do {
					c = nextChar();
				} while( isIdentChar(c) );
				if( c != '`'.code )
					throw "Unclosed `";
				return Ident(query.substr(start, (pos - 1) - start));
			case '0'.code, '1'.code, '2'.code, '3'.code, '4'.code, '5'.code, '6'.code, '7'.code, '8'.code, '9'.code:
				var n = (c - '0'.code) * 1.0;
				var exp = 0.;
				while( true ) {
					c = nextChar();
					exp *= 10;
					switch( c ) {
					case 48,49,50,51,52,53,54,55,56,57:
						n = n * 10 + (c - 48);
					case '.'.code:
						if( exp > 0 )
							invalidChar(c);
						exp = 1.;
					default:
						pos--;
						var i = Std.int(n);
						return (exp > 0) ? CFloat(n * 10 / exp) : ((i == n) ? CInt(i) : CFloat(n));
					}
				}
			default:
				if( (c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code) ) {
					var start = pos - 1;
					do {
						c = nextChar();
					} while( #if neko c != null #end && isIdentChar(c) );
					pos--;
					var i = query.substr(start, pos - start);
					var iup = i.toUpperCase();
					if( keywords.exists(iup) )
						return Kwd(iup);
					return Ident(i);
				}
				if( StringTools.isEof(c) )
					return Eof;
				invalidChar(c);
			}
		}
	}

	function tokenStr(t) {
		return switch( t ) {
		case Kwd(k): k;
		case Ident(k): k;
		case Star: "*";
		case Eof: "<eof>";
		case POpen: "(";
		case PClose: ")";
		case Comma: ",";
		case Op(o): opStr(o);
		case CInt(i): "" + i;
		case CFloat(f): "" + f;
		};
	}

	function opStr( op : Binop ) {
		return switch( op ) {
		case Eq: "=";
		}
	}

	function req(tk:Token) {
		var t = token();
		if( !Type.enumEq(t,tk) ) unexpected(t);
	}

	function unexpected(t) : Dynamic {
		throw "Unexpected " + tokenStr(t);
		return null;
	}

	function ident() : String {
		return switch( token() ) {
		case Ident(i): i;
		case t: unexpected(t);
		}
	}

	function eof() {
		var t = token();
		if( t != Eof ) unexpected(t);
	}

	function parseQuery() : Query {
		var t = token();
		switch( t ) {
		case Kwd("SELECT"):
			var fields = [];
			while( true ) {
				switch( token() ) {
				case Star:
					fields.push( { all : true } );
				case t:
					unexpected(t);
				}
				switch( token() ) {
				case Kwd("FROM"):
					break;
				case t:
					unexpected(t);
				}
			}
			var table = ident();
			var cond = switch( token() ) {
			case Eof: True;
			case Kwd("WHERE"): parseExpr();
			case t: unexpected(t);
			}
			eof();
			return Select(fields, table, cond);
		case Kwd("CREATE"):
			switch( token() ) {
			case Kwd("TABLE"):
				var table = ident();
				var fields = [], props = [];
				req(POpen);
				while( true ) {
					switch( token() ) {
					case Ident(name):
						var f : FieldDesc = { name : name };
						fields.push(f);
						while( true ) {
							var t = token();
							switch( t ) {
							case Kwd("NOT"):
								req(Kwd("NULL"));
								f.notNull = true;
								continue;
							case Kwd("AUTO_INCREMENT"):
								f.autoIncrement = true;
								continue;
							case Ident(i), Kwd(i) if( f.type == null ):
								var st = sqlTypes.get(i.toUpperCase());
								if( st != null ) {
									f.type = st;
									switch( token() ) {
									case POpen:
										switch( token() ) {
										case CInt(v): f.digits = v;
										case t: unexpected(t);
										}
										req(PClose);
									case t: push(t);
									}
									continue;
								}
							default:
							}
							push(t);
							break;
						}
					case Kwd("PRIMARY"):
						req(Kwd("KEY"));
						req(POpen);
						var key = [];
						while( true ) {
							key.push(ident());
							switch( token() ) {
							case PClose: break;
							case Comma: continue;
							case t: unexpected(t);
							}
						}
						props.push(PrimaryKey(key));
					case t: unexpected(t);
					}
					switch( token() ) {
					case Comma: continue;
					case PClose: break;
					case t: unexpected(t);
					}
				}
				while( true ) {
					switch( token() ) {
					case Eof: break;
					case Kwd("ENGINE"):
						req(Op(Eq));
						props.push(Engine(ident()));
					case t:
						unexpected(t);
					}
				}
				return CreateTable(table, fields, props);
			default:
			}
		case Kwd("ALTER"):
			req(Kwd("TABLE"));
			var table = ident();
			var cmds = [];
			while( true ) {
				switch( token() ) {
				case Eof: break;
				case Kwd("ADD"):
					switch( token() ) {
					case Kwd("CONSTRAINT"):
						var cname = ident();
						req(Kwd("FOREIGN"));
						req(Kwd("KEY"));
						req(POpen);
						var field = ident();
						req(PClose);
						req(Kwd("REFERENCES"));
						var target = ident();
						req(POpen);
						var tfield = ident();
						req(PClose);
						var onDel = null;
						switch( token() ) {
						case Kwd("ON"):
							req(Kwd("DELETE"));
							switch( token() ) {
							case Kwd("SET"):
								req(Kwd("NULL"));
								onDel = FKDSetNull;
							case Kwd("CASCADE"):
								onDel = FKDCascade;
							case t:
								unexpected(t);
							}
						case t:
							push(t);
						}
						cmds.push(AddConstraintFK(cname, field, target, tfield, onDel));
					case t: unexpected(t);
					}
				case t: unexpected(t);
				}
			}
			return AlterTable(table, cmds);
		default:
		}
		throw "Unsupported query " + query;
	}

	function parseExpr() : Expr {
		var t = token();
		switch( t ) {
		default:
			unexpected(t);
		}
		return null;
	}

}