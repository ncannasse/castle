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

enum FormulaType {
	FInt;
	FFloat;
	FBool;
}

typedef FormulaArg = {
	var name : String;
	var type : FormulaType;
}

enum FormulaUnop {
	ONeg;
	ONot;
}

enum FormulaBinop {
	OAdd;
	OSub;
	OMul;
	ODiv;
	OMod;
	OPow;
	OEq;
	ONotEq;
	OLt;
	OLte;
	OGt;
	OGte;
	OAnd;
	OOr;
}

enum FormulaCall {
	CInt;
	CRound;
	CCeil;
	CFloor;
	CAbs;
	CMin;
	CMax;
	CRandom;
	CRand;
	CSrand;
}

enum FormulaExprDef {
	EInt( v : Int );
	EFloat( v : Float );
	EBool( b : Bool );
	EIdent( name : String );
	EParent( e : FormulaExpr );
	EUnop( op : FormulaUnop, e : FormulaExpr );
	EBinop( op : FormulaBinop, e1 : FormulaExpr, e2 : FormulaExpr );
	ETernary( cond : FormulaExpr, e1 : FormulaExpr, e2 : FormulaExpr );
	ECall( f : FormulaCall, args : Array<FormulaExpr> );
	ERef( name : String );
	ECallRef( name : String, args : Array<FormulaExpr> );
}

enum FormulaRef {
	RValue( t : FormulaType, v : Dynamic );
	RFormula( code : String );
}

typedef FormulaScope = Map<String, FormulaRef>;

typedef FormulaExpr = {
	var e : FormulaExprDef;
	var pmin : Int;
	var pmax : Int;
	var ?t : FormulaType;
}

class FormulaError {
	public var msg : String;
	public var pmin : Int;
	public var pmax : Int;
	public function new(msg, pmin, pmax) {
		this.msg = msg;
		this.pmin = pmin;
		this.pmax = pmax;
	}
	public function toString() {
		return msg + " (char " + pmin + ")";
	}
}

class CompiledFormula {
	public var code(default, null) : String;
	public var args(default, null) : Array<FormulaArg>;
	public var type(default, null) : FormulaType;
	var fun : Dynamic -> Dynamic;
	public function new(code, args, type, fun) {
		this.code = code;
		this.args = args;
		this.type = type;
		this.fun = fun;
	}
	public inline function call( args : Dynamic ) : Dynamic {
		return fun(args);
	}
	public function toFunction() : Dynamic {
		return fun;
	}
	public function toPositional() : Dynamic {
		var names = [for( a in args ) a.name];
		return Reflect.makeVarArgs(function(values : Array<Dynamic>) {
			var o = {};
			for( i in 0...names.length )
				Reflect.setField(o, names[i], values[i]);
			return fun(o);
		});
	}
	public function toString() {
		return code;
	}
}

class FormulaEngine {

	public static var DEFAULT_ARG = "value";

	// ---------------- names ----------------

	public static function typeName( t : FormulaType ) {
		return switch( t ) { case FInt: "Int"; case FFloat: "Float"; case FBool: "Bool"; }
	}

	static function parseTypeName( s : String ) : Null<FormulaType> {
		return switch( s ) { case "Int": FInt; case "Float": FFloat; case "Bool": FBool; default: null; }
	}

	public static function callName( c : FormulaCall ) {
		return switch( c ) {
		case CInt: "int";
		case CRound: "round";
		case CCeil: "ceil";
		case CFloor: "floor";
		case CAbs: "abs";
		case CMin: "min";
		case CMax: "max";
		case CRandom: "random";
		case CRand: "rand";
		case CSrand: "srand";
		}
	}

	public static function callDoc( c : FormulaCall ) : { signature : String, doc : String } {
		return switch( c ) {
		case CInt: { signature : "int(x) : Int", doc : "x truncated toward zero" };
		case CRound: { signature : "round(x) : Int", doc : "x rounded to the nearest integer" };
		case CCeil: { signature : "ceil(x) : Int", doc : "smallest integer >= x" };
		case CFloor: { signature : "floor(x) : Int", doc : "largest integer <= x" };
		case CAbs: { signature : "abs(x)", doc : "absolute value, Int when x is Int" };
		case CMin: { signature : "min(a, b, ...)", doc : "smallest value, Int when all values are Int" };
		case CMax: { signature : "max(a, b, ...)", doc : "biggest value, Int when all values are Int" };
		case CRandom: { signature : "random(max:Int) : Int / random(min:Int, max:Int) : Int", doc : "random integer in [0,max[ or [min,max[" };
		case CRand: { signature : "rand(max) : Float", doc : "random float in [0,max[" };
		case CSrand: { signature : "srand(max) : Float", doc : "random float in ]-max,max[" };
		}
	}

	public static function randomRange( min : Int, max : Int ) : Int {
		return min + Std.random(max - min);
	}

	public static function srand( max : Float ) : Float {
		var r = Math.random() * 2 - 1;
		while( r == -1 ) r = Math.random() * 2 - 1;
		return r * max;
	}

	public static function parseCallName( name : String ) : Null<FormulaCall> {
		for( c in FormulaCall.createAll() )
			if( callName(c) == name )
				return c;
		return null;
	}

	public static function binopName( op : FormulaBinop ) {
		return switch( op ) {
		case OAdd: "+";
		case OSub: "-";
		case OMul: "*";
		case ODiv: "/";
		case OMod: "%";
		case OPow: "^";
		case OEq: "==";
		case ONotEq: "!=";
		case OLt: "<";
		case OLte: "<=";
		case OGt: ">";
		case OGte: ">=";
		case OAnd: "&&";
		case OOr: "||";
		}
	}

	// ---------------- arguments ----------------

	// would shadow identifiers used by the generated code
	static var RESERVED = ["Math", "Std", "cdb"];

	static function isIdent( s : String ) {
		return ~/^[A-Za-z_][A-Za-z0-9_]*$/.match(s);
	}

	public static function defaultArgs() : Array<FormulaArg> {
		return [{ name : DEFAULT_ARG, type : FFloat }];
	}

	public static function parseArgs( str : String ) : Array<FormulaArg> {
		if( str == null || StringTools.trim(str) == "" )
			return [];
		var parts = [for( p in str.split(",") ) StringTools.trim(p)];
		var args : Array<FormulaArg> = [];
		for( p in parts ) {
			if( p == "" ) throw "Empty argument";
			var name = p, type = FFloat;
			var idx = p.indexOf(":");
			if( idx >= 0 ) {
				name = StringTools.trim(p.substr(0, idx));
				var tname = StringTools.trim(p.substr(idx + 1));
				type = parseTypeName(tname);
				if( type == null ) throw 'Invalid type "$tname" (should be Int, Float or Bool)';
				if( name == "" ) {
					if( parts.length > 1 ) throw "Arguments must be named when there are more than one";
					name = DEFAULT_ARG;
				}
			} else if( parseTypeName(p) != null ) {
				if( parts.length > 1 ) throw "Arguments must be named when there are more than one";
				name = DEFAULT_ARG;
				type = parseTypeName(p);
			}
			if( !isIdent(name) ) throw 'Invalid argument name "$name"';
			if( name == "true" || name == "false" || parseCallName(name) != null || RESERVED.indexOf(name) >= 0 || StringTools.startsWith(name, "__") ) throw 'Reserved argument name "$name"';
			for( a in args ) if( a.name == name ) throw 'Duplicate argument "$name"';
			args.push({ name : name, type : type });
		}
		return args;
	}

	public static function getDefault() : String {
		return DEFAULT_ARG;
	}

	public static function argsToString( args : Array<FormulaArg> ) {
		return [for( a in args ) a.name + ":" + typeName(a.type)].join(", ");
	}

	static function isDefaultArgs( args : Array<FormulaArg> ) {
		return args.length == 1 && args[0].name == DEFAULT_ARG && args[0].type == FFloat;
	}

	public static function makeCode( args : Array<FormulaArg>, body : String ) : String {
		body = StringTools.trim(body);
		return isDefaultArgs(args) ? body : "(" + argsToString(args) + ") => " + body;
	}

	public static function split( code : String ) : { args : Array<FormulaArg>, body : String } {
		if( code == null ) code = "";
		var h = try parseHeader(code) catch( e : FormulaError ) null;
		if( h == null )
			return { args : defaultArgs(), body : code };
		return { args : h.args, body : StringTools.trim(code.substr(h.start)) };
	}

	// ---------------- parser ----------------

	static var HEADER = ~/^\s*\(([^()]*)\)\s*=>/;

	public static function parse( code : String ) : { args : Array<FormulaArg>, expr : FormulaExpr } {
		var nl = code.indexOf("\n");
		if( nl < 0 ) nl = code.indexOf("\r");
		if( nl >= 0 )
			throw new FormulaError("Formula must be on a single line", nl, nl + 1);
		var h = parseHeader(code);
		return { args : h.args, expr : new FormulaParser(code, h.start).parseAll() };
	}

	public static function parseHeader( code : String ) : { args : Array<FormulaArg>, start : Int } {
		if( !HEADER.match(code) )
			return { args : defaultArgs(), start : 0 };
		var p = HEADER.matchedPos();
		var args = try parseArgs(HEADER.matched(1)) catch( e : String ) throw new FormulaError(e, p.pos, p.pos + p.len);
		return { args : args, start : p.pos + p.len };
	}

	// ---------------- typer ----------------

	static function error( msg : String, e : FormulaExpr ) : Dynamic {
		throw new FormulaError(msg, e.pmin, e.pmax);
	}

	public static function unify( t1 : FormulaType, t2 : FormulaType ) : Null<FormulaType> {
		if( t1 == null ) return t2;
		if( t2 == null || t1 == t2 ) return t1;
		if( t1 == FBool || t2 == FBool ) return null;
		return FFloat;
	}

	public static function typeOf( e : FormulaExpr, args : Array<FormulaArg>, ?scope : FormulaScope ) : FormulaType {
		var t = typeExpr(e, args, scope);
		e.t = t;
		return t;
	}

	static function typeExpr( e : FormulaExpr, args : Array<FormulaArg>, scope : FormulaScope ) : FormulaType {
		inline function typeOf( e : FormulaExpr ) return FormulaEngine.typeOf(e, args, scope);
		inline function num( e : FormulaExpr ) {
			var t = typeOf(e);
			if( t == FBool ) error("Number expected", e);
			return t;
		}
		inline function bool( e : FormulaExpr ) {
			if( typeOf(e) != FBool ) error("Bool expected", e);
		}
		return switch( e.e ) {
		case EInt(_): FInt;
		case EFloat(_): FFloat;
		case EBool(_): FBool;
		case EIdent(name):
			var t = null;
			for( a in args ) if( a.name == name ) { t = a.type; break; }
			if( t == null ) {
				switch( getRef(scope, name) ) {
				case RValue(rt, _):
					e.e = ERef(name);
					t = rt;
				case RFormula(_):
					error('$name is a formula, call it with $name(...)', e);
				case null:
					error('Unknown identifier "$name"', e);
				}
			}
			t;
		case ERef(name):
			switch( getRef(scope, name) ) {
			case RValue(t, _): t;
			default: error('Unknown identifier "$name"', e);
			}
		case ECallRef(name, params):
			var f = refFormula(name, scope, e);
			if( params.length != f.args.length )
				error('$name() requires ${f.args.length} argument' + (f.args.length > 1 ? "s" : ""), e);
			for( i in 0...params.length ) {
				var a = f.args[i], p = params[i];
				var pt = typeOf(p);
				if( pt != a.type && !(a.type == FFloat && pt == FInt) )
					error('${typeName(a.type)} expected for ${a.name}', p);
			}
			f.type;
		case EParent(e): typeOf(e);
		case EUnop(ONot, e1):
			bool(e1);
			FBool;
		case EUnop(ONeg, e1):
			num(e1);
		case EBinop(op, e1, e2):
			switch( op ) {
			case OAdd, OSub, OMul, OMod:
				var t1 = num(e1), t2 = num(e2);
				t1 == FInt && t2 == FInt ? FInt : FFloat;
			case OPow:
				var t1 = num(e1);
				num(e2);
				t1 == FInt && isIntPower(e2) ? FInt : FFloat;
			case ODiv:
				num(e1);
				num(e2);
				FFloat;
			case OLt, OLte, OGt, OGte:
				num(e1);
				num(e2);
				FBool;
			case OEq, ONotEq:
				if( unify(typeOf(e1), typeOf(e2)) == null ) error("Cannot compare Bool and number", e);
				FBool;
			case OAnd, OOr:
				bool(e1);
				bool(e2);
				FBool;
			}
		case ETernary(cond, e1, e2):
			bool(cond);
			var t = unify(typeOf(e1), typeOf(e2));
			if( t == null ) error("Both branches should have the same type", e);
			t;
		case ECall(f, params):
			var name = callName(f);
			inline function nargs( min : Int, max : Int ) {
				if( params.length < min || params.length > max ) {
					var expect = min == max ? '$min argument' + (min > 1 ? "s" : "") : max < 0x7FFFFFFF ? '$min to $max arguments' : 'at least $min arguments';
					error('$name() requires $expect', e);
				}
			}
			switch( f ) {
			case CInt, CRound, CCeil, CFloor:
				nargs(1, 1);
				num(params[0]);
				FInt;
			case CAbs:
				nargs(1, 1);
				num(params[0]);
			case CMin, CMax:
				nargs(2, 0x7FFFFFFF);
				var t = FInt;
				for( p in params ) if( num(p) == FFloat ) t = FFloat;
				t;
			case CRandom:
				nargs(1, 2);
				for( p in params ) if( num(p) != FInt ) error("Int expected", p);
				FInt;
			case CRand, CSrand:
				nargs(1, 1);
				num(params[0]);
				FFloat;
			}
		}
	}

	static function isIntPower( e : FormulaExpr ) {
		return switch( e.e ) {
		case EInt(v): v >= 0;
		case EParent(e): isIntPower(e);
		default: false;
		}
	}

	// ---------------- scope ----------------

	static inline function getRef( scope : FormulaScope, name : String ) {
		return scope == null ? null : scope.get(name);
	}

	public static function listScope( rows : Array<Dynamic>, idCol : String, col : cdb.Data.Column, ?variants : Array<cdb.Data.Column>, ?exclude : String ) : FormulaScope {
		var scope : FormulaScope = new Map();
		if( rows == null ) return scope;
		for( r in rows ) {
			var id : String = Reflect.field(r, idCol);
			if( id == null || id == "" || id == exclude ) continue;
			var c = col, v : Dynamic = Reflect.field(r, col.name);
			if( v == null ) continue;
			if( col.type == TPolymorph ) {
				c = null;
				if( variants != null )
					for( pc in variants ) {
						var pv = Reflect.field(v, pc.name);
						if( pv != null ) { c = pc; v = pv; break; }
					}
				if( c == null ) continue;
			}
			var ref = switch( c.type ) {
			case TInt: RValue(FInt, v);
			case TFloat: RValue(FFloat, v);
			case TBool: RValue(FBool, v);
			case TFormula: RFormula(v);
			default: null;
			}
			if( ref != null ) scope.set(id, ref);
		}
		return scope;
	}

	public static function scopeKey( code : String, scope : FormulaScope ) : String {
		if( scope == null ) return code;
		var used = new Map<String, Bool>();
		collectRefs(code, scope, used);
		var keys = [for( k in used.keys() ) k];
		keys.sort(Reflect.compare);
		var b = new StringBuf();
		b.add(code);
		for( k in keys ) {
			b.add("|" + k + "=");
			b.add(switch( scope.get(k) ) {
			case RValue(FFloat, v): floatKey(v);
			case RValue(_, v): Std.string(v);
			case RFormula(c): "{" + c + "}";
			});
		}
		return b.toString();
	}

	static function floatKey( v : Float ) : String {
		var i = haxe.io.FPHelper.doubleToI64(v);
		return StringTools.hex(i.high, 8) + StringTools.hex(i.low, 8);
	}

	static function collectRefs( code : String, scope : FormulaScope, used : Map<String, Bool> ) {
		var f = try parse(code) catch( e : Dynamic ) return;
		function loop( e : FormulaExpr ) {
			switch( e.e ) {
			case EInt(_), EFloat(_), EBool(_):
			case EIdent(name), ERef(name):
				if( !used.exists(name) && scope.exists(name) && !Lambda.exists(f.args, a -> a.name == name) ) {
					used.set(name, true);
					switch( scope.get(name) ) { case RFormula(c): collectRefs(c, scope, used); default: }
				}
			case ECallRef(name, params):
				if( !used.exists(name) && scope.exists(name) ) {
					used.set(name, true);
					switch( scope.get(name) ) { case RFormula(c): collectRefs(c, scope, used); default: }
				}
				for( p in params ) loop(p);
			case EParent(e), EUnop(_, e): loop(e);
			case EBinop(_, e1, e2): loop(e1); loop(e2);
			case ETernary(c, e1, e2): loop(c); loop(e1); loop(e2);
			case ECall(_, params): for( p in params ) loop(p);
			}
		}
		loop(f.expr);
	}

	public static function describeRef( name : String, scope : FormulaScope ) : { info : String, isFunction : Bool } {
		return switch( getRef(scope, name) ) {
		case null: null;
		case RValue(t, v): { info : typeName(t) + " = " + v, isFunction : false };
		case RFormula(code):
			var f = try { var p = parse(code); { args : p.args, t : typeOf(p.expr, p.args, scope) }; } catch( e : Dynamic ) null;
			{ info : f == null ? "(?)" : "(" + argsToString(f.args) + ") : " + typeName(f.t), isFunction : true };
		}
	}

	// formulas being typed, to detect cycles
	static var resolving : Array<String> = [];

	static function refFormula( name : String, scope : FormulaScope, e : FormulaExpr ) : { args : Array<FormulaArg>, type : FormulaType } {
		var code = switch( getRef(scope, name) ) {
		case RFormula(code): code;
		case RValue(_): error('$name is not a formula', e);
		case null: error('Unknown function $name()', e);
		}
		if( resolving.indexOf(name) >= 0 )
			error('Recursive reference to $name', e);
		resolving.push(name);
		try {
			var f = parse(code);
			var t = typeOf(f.expr, f.args, scope);
			resolving.pop();
			return { args : f.args, type : t };
		} catch( err : FormulaError ) {
			resolving.pop();
			return error('In $name : ' + err.msg, e);
		} catch( err : Dynamic ) {
			resolving.pop();
			throw err;
		}
	}

	public static function columnType( codes : Iterable<String>, ?onInvalid : String -> Dynamic -> Void ) : FormulaType {
		return scopedColumnType([for( code in codes ) { code : code, scope : null }], onInvalid);
	}

	static function scopedColumnType( codes : Iterable<{ code : String, scope : FormulaScope }>, ?onInvalid : String -> Dynamic -> Void ) : FormulaType {
		var t : FormulaType = null;
		for( c in codes ) {
			var code = c.code;
			if( code == null ) continue;
			var ft = try check(code, c.scope) catch( e : Dynamic ) {
				if( onInvalid != null ) onInvalid(code, e);
				continue;
			}
			var u = unify(t, ft);
			if( u == null ) throw 'Formulas mix Bool and number results ("$code")';
			t = u;
		}
		return t == null ? FFloat : t;
	}

	public static function check( code : String, ?scope : FormulaScope ) : FormulaType {
		var f = parse(code);
		return typeOf(f.expr, f.args, scope);
	}

	public static function getError( code : String, ?scope : FormulaScope ) : String {
		try {
			check(code, scope);
			return null;
		} catch( e : FormulaError ) {
			return e.msg;
		} catch( e : Dynamic ) {
			return Std.string(e);
		}
	}

	// ---------------- interpreter ----------------

	static var cache = new Map<String, CompiledFormula>();

	public static function get( code : String ) : CompiledFormula {
		if( code == null ) return null;
		var f = cache.get(code);
		if( f == null ) {
			f = compile(code);
			cache.set(code, f);
		}
		return f;
	}

	public static function compile( code : String, ?scope : FormulaScope ) : CompiledFormula {
		var f = parse(code);
		var t = typeOf(f.expr, f.args, scope);
		return new CompiledFormula(code, f.args, t, compileExpr(f.expr, scope));
	}

	static function compileExpr( e : FormulaExpr, scope : FormulaScope ) : Dynamic -> Dynamic {
		inline function isInt( e : FormulaExpr ) return e.t == FInt;
		inline function sub( e : FormulaExpr ) return compileExpr(e, scope);
		return switch( e.e ) {
		case EInt(v): _ -> v;
		case EFloat(v): _ -> v;
		case EBool(b): _ -> b;
		case ERef(name):
			var v : Dynamic = switch( getRef(scope, name) ) {
			case RValue(FFloat, v): (v : Float);
			case RValue(_, v): v;
			default: throw "assert";
			}
			_ -> v;
		case ECallRef(name, params):
			var code = switch( getRef(scope, name) ) { case RFormula(c): c; default: throw "assert"; };
			var f = compile(code, scope);
			var fl = [for( p in params ) sub(p)];
			var names = [for( a in f.args ) a.name];
			a -> {
				var o = {};
				for( i in 0...fl.length )
					Reflect.setField(o, names[i], fl[i](a));
				f.call(o);
			};
		case EIdent(name):
			switch( e.t ) {
			case FInt: a -> { var v : Int = Reflect.field(a, name); v; };
			case FFloat: a -> { var v : Float = Reflect.field(a, name); v; };
			case FBool: a -> { var v : Bool = Reflect.field(a, name); v; };
			}
		case EParent(e): sub(e);
		case EUnop(ONot, e1):
			var f = sub(e1);
			a -> !(f(a) : Bool);
		case EUnop(ONeg, e1):
			var f = sub(e1);
			isInt(e1) ? a -> -(f(a) : Int) : a -> -(f(a) : Float);
		case EBinop(op, e1, e2):
			var f1 = sub(e1), f2 = sub(e2);
			var ints = isInt(e1) && isInt(e2);
			var bools = e1.t == FBool;
			switch( op ) {
			case OAdd: ints ? a -> (f1(a) : Int) + (f2(a) : Int) : a -> (f1(a) : Float) + (f2(a) : Float);
			case OSub: ints ? a -> (f1(a) : Int) - (f2(a) : Int) : a -> (f1(a) : Float) - (f2(a) : Float);
			case OMul: ints ? a -> (f1(a) : Int) * (f2(a) : Int) : a -> (f1(a) : Float) * (f2(a) : Float);
			case OMod: ints ? a -> (f1(a) : Int) % (f2(a) : Int) : a -> (f1(a) : Float) % (f2(a) : Float);
			case ODiv: a -> (f1(a) : Float) / (f2(a) : Float);
			case OPow: isInt(e) ? a -> ipow(f1(a), f2(a)) : a -> Math.pow(f1(a), f2(a));
			case OLt: a -> (f1(a) : Float) < (f2(a) : Float);
			case OLte: a -> (f1(a) : Float) <= (f2(a) : Float);
			case OGt: a -> (f1(a) : Float) > (f2(a) : Float);
			case OGte: a -> (f1(a) : Float) >= (f2(a) : Float);
			case OEq: bools ? a -> (f1(a) : Bool) == (f2(a) : Bool) : a -> (f1(a) : Float) == (f2(a) : Float);
			case ONotEq: bools ? a -> (f1(a) : Bool) != (f2(a) : Bool) : a -> (f1(a) : Float) != (f2(a) : Float);
			case OAnd: a -> (f1(a) : Bool) && (f2(a) : Bool);
			case OOr: a -> (f1(a) : Bool) || (f2(a) : Bool);
			}
		case ETernary(cond, e1, e2):
			var fc = sub(cond), f1 = sub(e1), f2 = sub(e2);
			if( e.t == FFloat && (isInt(e1) || isInt(e2)) ) {
				var g1 = f1, g2 = f2;
				f1 = a -> { var v : Float = g1(a); v; };
				f2 = a -> { var v : Float = g2(a); v; };
			}
			a -> (fc(a) : Bool) ? f1(a) : f2(a);
		case ECall(f, params):
			var fl = [for( p in params ) sub(p)];
			var f0 = fl[0];
			var int = isInt(params[0]);
			switch( f ) {
			case CInt: int ? f0 : a -> Std.int((f0(a) : Float));
			case CRound: int ? f0 : a -> Math.round(f0(a));
			case CCeil: int ? f0 : a -> Math.ceil(f0(a));
			case CFloor: int ? f0 : a -> Math.floor(f0(a));
			case CAbs: int ? a -> { var v : Int = f0(a); v < 0 ? -v : v; } : a -> Math.abs(f0(a));
			case CMin, CMax if( fl.length == 2 ):
				var f1 = fl[1];
				switch( [f == CMin, e.t == FInt] ) {
				case [true, true]: a -> { var x : Int = f0(a), y : Int = f1(a); x < y ? x : y; };
				case [false, true]: a -> { var x : Int = f0(a), y : Int = f1(a); x > y ? x : y; };
				case [true, false]: a -> Math.min(f0(a), f1(a));
				case [false, false]: a -> Math.max(f0(a), f1(a));
				}
			case CMin, CMax:
				var isMin = f == CMin;
				if( e.t == FInt )
					a -> {
						var r : Int = fl[0](a);
						for( i in 1...fl.length ) {
							var v : Int = fl[i](a);
							if( isMin ? v < r : v > r ) r = v;
						}
						r;
					}
				else
					a -> {
						var r : Float = fl[0](a);
						for( i in 1...fl.length ) {
							var v : Float = fl[i](a);
							r = isMin ? Math.min(r, v) : Math.max(r, v);
						}
						r;
					}
			case CRandom:
				if( fl.length == 1 )
					a -> Std.random(f0(a));
				else {
					var f1 = fl[1];
					a -> randomRange(f0(a), f1(a));
				}
			case CRand: a -> Math.random() * (f0(a) : Float);
			case CSrand: a -> srand(f0(a));
			}
		}
	}

	public static function ipow( b : Int, e : Int ) : Int {
		if( e < 0 )
			return Std.int(Math.pow(b, e));
		var r = 1;
		while( e > 0 ) {
			if( e & 1 != 0 ) r *= b;
			b *= b;
			e >>= 1;
		}
		return r;
	}

	// ---------------- macro ----------------

	#if macro
	// refExpr : the function generated for a referenced formula
	public static function toFunction( code : String, pos : haxe.macro.Expr.Position, ?scope : FormulaScope, ?refExpr : String -> haxe.macro.Expr ) : { expr : haxe.macro.Expr, type : haxe.macro.Expr.ComplexType } {
		var f = parse(code);
		var ret = typeOf(f.expr, f.args, scope);
		var rt = complexType(ret);
		var body = toExpr(f.expr, pos, scope, refExpr);
		var fargs : Array<haxe.macro.Expr.FunctionArg> = [for( a in f.args ) { name : a.name, type : complexType(a.type) }];
		var fexpr : haxe.macro.Expr = { expr : EFunction(FAnonymous, { args : fargs, ret : rt, expr : macro return $body }), pos : pos };
		return { expr : fexpr, type : TFunction([for( a in f.args ) TNamed(a.name, complexType(a.type))], rt) };
	}

	public static function complexType( t : FormulaType ) : haxe.macro.Expr.ComplexType {
		return switch( t ) {
		case FInt: macro : Int;
		case FFloat: macro : Float;
		case FBool: macro : Bool;
		}
	}

	// return type of the formulas of a column, typed with the scope of the list or root sheet holding them
	public static function sheetColumnType( sheets : Map<String, cdb.Data.SheetData>, lines : cdb.Data.SheetData -> Array<Dynamic>, s : cdb.Data.SheetData, c : cdb.Data.Column, pos : haxe.macro.Expr.Position ) : haxe.macro.Expr.ComplexType {
		return try complexType(scopedColumnType(sheetCodes(sheets, lines, s, c), (code, e) -> haxe.macro.Context.warning('${s.name}.${c.name} : invalid formula "$code" ($e)', pos)))
			catch( e : String ) macro : Dynamic;
	}

	static function sheetCodes( sheets : Map<String, cdb.Data.SheetData>, lines : cdb.Data.SheetData -> Array<Dynamic>, s : cdb.Data.SheetData, c : cdb.Data.Column ) : Array<{ code : String, scope : FormulaScope }> {
		function getParent( s : cdb.Data.SheetData ) : { sheet : cdb.Data.SheetData, col : cdb.Data.Column } {
			var name = s.name.split("@");
			var col = name.pop();
			var ps = sheets.get(name.join("@"));
			if( ps == null ) return null;
			for( c in ps.columns )
				if( c.name == col )
					return { sheet : ps, col : c };
			return null;
		}
		function getIdCol( s : cdb.Data.SheetData ) {
			for( c in s.columns ) if( c.type == TId ) return c;
			return null;
		}
		var p = getParent(s);
		var idCol = getIdCol(s);
		if( p != null && p.col.type == TList && idCol != null ) {
			var out = [];
			for( o in lines(p.sheet) ) {
				var rows : Array<Dynamic> = Reflect.field(o, p.col.name);
				var scope = listScope(rows, idCol.name, c);
				if( rows != null )
					for( r in rows ) out.push({ code : (Reflect.field(r, c.name) : String), scope : scope });
			}
			return out;
		}
		var gp = p == null ? null : getParent(p.sheet);
		var pid = p == null ? null : getIdCol(p.sheet);
		if( p != null && p.col.type == TPolymorph && gp != null && gp.col.type == TList && pid != null ) {
			var out = [];
			for( o in lines(gp.sheet) ) {
				var rows : Array<Dynamic> = Reflect.field(o, gp.col.name);
				var scope = listScope(rows, pid.name, p.col, s.columns);
				if( rows != null )
					for( r in rows ) {
						var v = Reflect.field(r, p.col.name);
						if( v != null ) out.push({ code : (Reflect.field(v, c.name) : String), scope : scope });
					}
			}
			return out;
		}
		if( p != null && p.col.type == TPolymorph && gp == null && pid != null ) {
			var rows = lines(p.sheet);
			var scope = listScope(rows, pid.name, p.col, s.columns);
			return [for( r in rows ) { var v = Reflect.field(r, p.col.name); if( v != null ) { code : (Reflect.field(v, c.name) : String), scope : scope }; }];
		}
		if( p == null && idCol != null ) {
			var rows = lines(s);
			var scope = listScope(rows, idCol.name, c);
			return [for( r in rows ) { code : (Reflect.field(r, c.name) : String), scope : scope }];
		}
		return [for( obj in lines(s) ) { code : (Reflect.field(obj, c.name) : String), scope : null }];
	}

	public static function argsComplexType( args : Array<FormulaArg>, pos ) : haxe.macro.Expr.ComplexType {
		return TAnonymous([for( a in args ) ({ name : a.name, pos : pos, kind : FVar(complexType(a.type)) } : haxe.macro.Expr.Field)]);
	}

	static function toExpr( e : FormulaExpr, pos : haxe.macro.Expr.Position, scope : FormulaScope, refExpr : String -> haxe.macro.Expr ) : haxe.macro.Expr {
		inline function isInt( e : FormulaExpr ) return e.t == FInt;
		inline function make( e : FormulaExpr ) return toExpr(e, pos, scope, refExpr);
		var expr : haxe.macro.Expr = switch( e.e ) {
		case EInt(v): macro $v{v};
		case EFloat(v):
			var s = Std.string(v);
			{ expr : EConst(CFloat(s.indexOf(".") < 0 && s.indexOf("e") < 0 ? s + ".0" : s)), pos : pos };
		case EBool(b): macro $v{b};
		case EIdent(name): macro $i{name};
		case ERef(name):
			var def = switch( getRef(scope, name) ) {
			case RValue(FInt, v): EInt(v);
			case RValue(FFloat, v): EFloat(v);
			case RValue(FBool, v): EBool(v);
			default: throw "assert";
			}
			make({ e : def, pmin : e.pmin, pmax : e.pmax, t : e.t });
		case ECallRef(name, params):
			if( refExpr == null ) throw 'Cannot reference $name here';
			{ expr : ECall(refExpr(name), [for( p in params ) make(p)]), pos : pos };
		case EParent(e): macro (${make(e)});
		case EUnop(ONot, e1): macro !${make(e1)};
		case EUnop(ONeg, e1): macro -${make(e1)};
		case EBinop(OPow, e1, e2):
			isInt(e) ? macro cdb.FormulaEngine.ipow(${make(e1)}, ${make(e2)}) : macro Math.pow(${make(e1)}, ${make(e2)});
		case EBinop(op, e1, e2):
			var bop : haxe.macro.Expr.Binop = switch( op ) {
			case OAdd: OpAdd;
			case OSub: OpSub;
			case OMul: OpMult;
			case ODiv: OpDiv;
			case OMod: OpMod;
			case OLt: OpLt;
			case OLte: OpLte;
			case OGt: OpGt;
			case OGte: OpGte;
			case OEq: OpEq;
			case ONotEq: OpNotEq;
			case OAnd: OpBoolAnd;
			case OOr: OpBoolOr;
			case OPow: throw "assert";
			}
			{ expr : EBinop(bop, macro (${make(e1)}), macro (${make(e2)})), pos : pos };
		case ETernary(cond, e1, e2):
			var x1 = make(e1), x2 = make(e2);
			if( e.t == FFloat ) {
				x1 = macro ($x1 : Float);
				x2 = macro ($x2 : Float);
			}
			macro (${make(cond)} ? $x1 : $x2);
		case ECall(f, params):
			var p0 = make(params[0]);
			var int = isInt(params[0]);
			switch( f ) {
			case CInt: int ? p0 : macro Std.int($p0);
			case CRound: int ? p0 : macro Math.round($p0);
			case CCeil: int ? p0 : macro Math.ceil($p0);
			case CFloor: int ? p0 : macro Math.floor($p0);
			case CAbs: int ? macro { var __v = $p0; __v < 0 ? -__v : __v; } : macro Math.abs($p0);
			case CMin, CMax:
				var isMin = f == CMin;
				inline function isSimple( e : FormulaExpr ) return e.e.match(EIdent(_) | EInt(_) | EFloat(_));
				var r = p0;
				var rSimple = isSimple(params[0]);
				for( i in 1...params.length ) {
					var v = make(params[i]);
					r = if( e.t == FInt ) {
						if( rSimple && isSimple(params[i]) )
							isMin ? macro ($r < $v ? $r : $v) : macro ($r > $v ? $r : $v);
						else
							isMin ? macro { var __a = $r, __b = $v; __a < __b ? __a : __b; } : macro { var __a = $r, __b = $v; __a > __b ? __a : __b; };
					} else
						isMin ? macro Math.min($r, $v) : macro Math.max($r, $v);
					rSimple = false;
				}
				r;
			case CRandom:
				params.length == 1 ? macro Std.random($p0) : macro cdb.FormulaEngine.randomRange($p0, ${make(params[1])});
			case CRand: macro Math.random() * $p0;
			case CSrand: macro cdb.FormulaEngine.srand($p0);
			}
		}
		expr.pos = pos;
		return expr;
	}
	#end
}

private class FormulaParser {

	var code : String;
	var pos : Int;
	var tok : Token;
	var tokMin : Int;
	var tokMax : Int;

	public function new( code : String, start : Int ) {
		this.code = code;
		pos = start;
	}

	public function parseAll() : FormulaExpr {
		next();
		if( tok == TEof )
			throw new FormulaError("Empty formula", tokMin, tokMax);
		var e = parseTernary();
		if( tok != TEof )
			unexpected();
		return e;
	}

	function unexpected() : Dynamic {
		throw new FormulaError(tok == TEof ? "Unexpected end of formula" : "Unexpected " + code.substring(tokMin, tokMax), tokMin, tokMax);
	}

	function mk( e : FormulaExprDef, pmin : Int, pmax : Int ) : FormulaExpr {
		return { e : e, pmin : pmin, pmax : pmax };
	}

	function parseTernary() : FormulaExpr {
		var cond = parseBinop(0);
		if( tok != TQuestion )
			return cond;
		next();
		var e1 = parseTernary();
		if( tok != TColon ) unexpected();
		next();
		var e2 = parseTernary();
		return mk(ETernary(cond, e1, e2), cond.pmin, e2.pmax);
	}

	static var PRIORITIES : Array<Array<FormulaBinop>> = [
		[OOr],
		[OAnd],
		[OEq, ONotEq, OLt, OLte, OGt, OGte],
		[OAdd, OSub],
		[OMul, ODiv, OMod],
	];
	static inline var COMPARISON_LEVEL = 2;

	static function priority( op : FormulaBinop ) {
		for( i in 0...PRIORITIES.length )
			if( PRIORITIES[i].indexOf(op) >= 0 )
				return i;
		return -1;
	}

	function parseBinop( level : Int ) : FormulaExpr {
		if( level == PRIORITIES.length )
			return parseUnop();
		var e = parseBinop(level + 1);
		while( true ) {
			var op = switch( tok ) { case TBinop(op) if( priority(op) == level ): op; default: null; };
			if( op == null ) break;
			switch( e.e ) {
			case EBinop(o, _, _) if( level == COMPARISON_LEVEL && priority(o) == COMPARISON_LEVEL ):
				throw new FormulaError("Comparisons cannot be chained", tokMin, tokMax);
			default:
			}
			next();
			var e2 = parseBinop(level + 1);
			e = mk(EBinop(op, e, e2), e.pmin, e2.pmax);
		}
		return e;
	}

	function parseUnop() : FormulaExpr {
		var op = switch( tok ) {
		case TBinop(OSub): ONeg;
		case TNot: ONot;
		default: return parsePower();
		}
		var pmin = tokMin;
		next();
		var e = parseUnop();
		if( op == ONeg )
			switch( e.e ) {
			case EInt(v): return mk(EInt(-v), pmin, e.pmax);
			case EFloat(v): return mk(EFloat(-v), pmin, e.pmax);
			default:
			}
		return mk(EUnop(op, e), pmin, e.pmax);
	}

	function parsePower() : FormulaExpr {
		var e = parsePrimary();
		if( tok.match(TBinop(OPow)) ) {
			next();
			var e2 = parseUnop();
			return mk(EBinop(OPow, e, e2), e.pmin, e2.pmax);
		}
		return e;
	}

	function parsePrimary() : FormulaExpr {
		var pmin = tokMin, pmax = tokMax;
		switch( tok ) {
		case TInt(v):
			next();
			return mk(EInt(v), pmin, pmax);
		case TFloat(v):
			next();
			return mk(EFloat(v), pmin, pmax);
		case TIdent("true"):
			next();
			return mk(EBool(true), pmin, pmax);
		case TIdent("false"):
			next();
			return mk(EBool(false), pmin, pmax);
		case TIdent(name):
			next();
			if( tok != TPOpen )
				return mk(EIdent(name), pmin, pmax);
			var f = FormulaEngine.parseCallName(name);
			next();
			var args = [];
			if( tok != TPClose ) {
				while( true ) {
					args.push(parseTernary());
					if( tok == TComma ) { next(); continue; }
					break;
				}
			}
			if( tok != TPClose ) unexpected();
			var pmax = tokMax;
			next();
			return mk(f == null ? ECallRef(name, args) : ECall(f, args), pmin, pmax);
		case TPOpen:
			next();
			var e = parseTernary();
			if( tok != TPClose ) unexpected();
			var pmax = tokMax;
			next();
			return mk(EParent(e), pmin, pmax);
		default:
			return unexpected();
		}
	}

	function next() {
		while( pos < code.length ) {
			var c = StringTools.fastCodeAt(code, pos);
			if( c != " ".code && c != "\t".code ) break;
			pos++;
		}
		tokMin = pos;
		tok = readToken();
		tokMax = pos;
	}

	inline function peek( c : Int ) {
		return pos < code.length && StringTools.fastCodeAt(code, pos) == c;
	}

	function readToken() : Token {
		if( pos >= code.length )
			return TEof;
		var c = StringTools.fastCodeAt(code, pos++);
		switch( c ) {
		case "(".code: return TPOpen;
		case ")".code: return TPClose;
		case ",".code: return TComma;
		case "?".code: return TQuestion;
		case ":".code: return TColon;
		case "+".code: return TBinop(OAdd);
		case "-".code: return TBinop(OSub);
		case "*".code: return TBinop(OMul);
		case "/".code: return TBinop(ODiv);
		case "%".code: return TBinop(OMod);
		case "^".code: return TBinop(OPow);
		case "<".code:
			if( peek("=".code) ) { pos++; return TBinop(OLte); }
			return TBinop(OLt);
		case ">".code:
			if( peek("=".code) ) { pos++; return TBinop(OGte); }
			return TBinop(OGt);
		case "!".code:
			if( peek("=".code) ) { pos++; return TBinop(ONotEq); }
			return TNot;
		case "=".code:
			if( peek("=".code) ) { pos++; return TBinop(OEq); }
			throw new FormulaError("Use == for comparison", pos - 1, pos);
		case "&".code:
			if( peek("&".code) ) { pos++; return TBinop(OAnd); }
			throw new FormulaError("Unsupported operator &", pos - 1, pos);
		case "|".code:
			if( peek("|".code) ) { pos++; return TBinop(OOr); }
			throw new FormulaError("Unsupported operator |", pos - 1, pos);
		default:
		}
		if( (c >= "0".code && c <= "9".code) || c == ".".code ) {
			var start = pos - 1;
			var isFloat = c == ".".code;
			while( pos < code.length ) {
				var c = StringTools.fastCodeAt(code, pos);
				if( c >= "0".code && c <= "9".code ) { pos++; continue; }
				if( c == ".".code && !isFloat ) { isFloat = true; pos++; continue; }
				if( c == "e".code || c == "E".code ) {
					var p = pos + 1;
					if( p < code.length && (StringTools.fastCodeAt(code, p) == "-".code || StringTools.fastCodeAt(code, p) == "+".code) ) p++;
					if( p < code.length && StringTools.fastCodeAt(code, p) >= "0".code && StringTools.fastCodeAt(code, p) <= "9".code ) {
						isFloat = true;
						pos = p;
						continue;
					}
				}
				break;
			}
			var str = code.substring(start, pos);
			if( str == "." ) throw new FormulaError("Invalid number", start, pos);
			var f = Std.parseFloat(str);
			if( isFloat || f > 2147483647. )
				return TFloat(f);
			return TInt(Std.parseInt(str));
		}
		if( (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || c == "_".code ) {
			var start = pos - 1;
			while( pos < code.length ) {
				var c = StringTools.fastCodeAt(code, pos);
				if( (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || (c >= "0".code && c <= "9".code) || c == "_".code )
					pos++;
				else
					break;
			}
			return TIdent(code.substring(start, pos));
		}
		throw new FormulaError("Unexpected char '" + String.fromCharCode(c) + "'", pos - 1, pos);
	}
}

private enum Token {
	TEof;
	TInt( v : Int );
	TFloat( v : Float );
	TIdent( s : String );
	TBinop( op : FormulaBinop );
	TNot;
	TQuestion;
	TColon;
	TPOpen;
	TPClose;
	TComma;
}
