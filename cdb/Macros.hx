package cdb;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.Tools;
using Lambda;

typedef FieldBuild = {
	type:ComplexType,
	vars:Array<Expr>,
	init:Expr
}
#end

class Macros {
	public dynamic static function formatText(str:String, vars:Dynamic):String {
		for (f in Reflect.fields(vars))
			str = str.split("::" + f + "::").join("" + Reflect.field(vars, f));
		return str;
	}

	#if macro
	public static function buildPoly(file:String, sheetName:String, moduleName:String = "Data") {
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();

		inline function error(msg:String)
			Context.error(msg, pos);

		var data = Module.getData(file);
		var db = new Database();
		db.loadData(data);

		var mpath = Context.getLocalModule();
		Context.registerModuleDependency(mpath, Module.getDataPath(file));

		var sheet = db.getSheet(sheetName);
		if (sheet == null)
			error('"${sheetName}" not found');

		var sheetKind = Module.makeTypeName(sheetName) + "Kind";
		var idCol = sheet.columns.find(c -> c.type == TId);
		var polyCol = sheet.columns.find(c -> c.type == TPolymorph);

		if (idCol == null)
			error('Sheet needs a unique ID');
		if (polyCol == null)
			error('Sheet needs a polymorphic column');

		var module = macro $i{moduleName};

		var initExprs = [];

		inline function fullType(tname:String) {
			return (moduleName + "." + Module.makeTypeName(tname)).toComplex();
		}

		inline function getData(id:String) {
			return macro $module.$sheetName.get($module.$sheetKind.$id, true);
		}

		function extractTextArgs(val:String):Null<Array<haxe.macro.Expr.Field>> {
			var splitRegex = ~/::(.+?)::/g;
			if (!splitRegex.match(val))
				return null;
			var args = new Array<haxe.macro.Expr.Field>();
			var map = new Map<String, Bool>();
			splitRegex.map(val, function(r) {
				var name = r.matched(1);
				if (!map.exists(name)) {
					map.set(name, true);
					args.push({
						name: name,
						kind: FVar(macro :Dynamic),
						pos: pos,
						meta: []
					});
				}
				return r.matched(0);
			});
			return args;
		}

		inline function simpleType(t:cdb.Data.ColumnType):Null<ComplexType>
			return switch (t) {
				case TInt: macro :Int;
				case TFloat: macro :Float;
				case TBool: macro :Bool;
				case TString: macro :String;
				default: null;
			};

		inline function makeVar(name:String, initExpr:Expr):Expr
			return {expr: EVars([{name: name, expr: initExpr}]), pos: pos};

		function getPolyVal(polySub:Sheet, colVal:Dynamic):{col:cdb.Data.Column, val:Dynamic} {
			for (pc in polySub.columns) {
				var pv = Reflect.field(colVal, pc.name);
				if (pv != null)
					return {col: pc, val: pv};
			}
			return null;
		}

		function buildField(col:cdb.Data.Column, colVal:Dynamic, sheet:Sheet, rowExpr:Expr, prefix:String):FieldBuild {
			var colName = col.name;
			switch (col.type) {
				case TInt | TFloat | TBool:
					return {
						type: simpleType(col.type),
						vars: [],
						init: macro $rowExpr.$colName
					};
				case TString:
					var textArgs = extractTextArgs(colVal);
					if (textArgs == null)
						return {type: macro :String, vars: [], init: macro $rowExpr.$colName};
					return {
						type: TFunction([TAnonymous(textArgs)], macro :String),
						vars: [],
						init: macro function(vars) {
							return cdb.Macros.formatText($rowExpr.$colName, vars);
						}
					};
				case TProperties:
					var subType = fullType(sheet.getSub(col).name);
					return {
						type: subType,
						vars: [],
						init: macro $rowExpr.$colName
					};
				case TPolymorph:
					var polySub = sheet.getSub(col);
					var pval = getPolyVal(polySub, colVal);
					var polyVar = prefix + "_" + colName;
					var result = buildField(pval.col, pval.val, polySub, macro $i{polyVar}, prefix);
					result.vars.unshift(makeVar(polyVar, macro $rowExpr.$colName));
					return result;
				case TList:
					var sub = sheet.getSub(col);
					var subCols = sub.columns.filter(c -> c.kind != Hidden);
					if (subCols.length == 0)
						error('Empty sub-list');

					var idCol = subCols.find(c -> c.type == TId);
					if (subCols.length == 2 && idCol != null) {
						subCols.remove(idCol);
						var valCol = subCols[0];

						var val:Array<Dynamic> = colVal;
						var fields = [];
						var inits = [];
						var vars = [];

						var arrVar = prefix + "_" + colName;
						vars.push(makeVar(arrVar, macro $rowExpr.$colName));

						for (i => row in val) {
							var sid:String = Reflect.field(row, idCol.name);
							if (sid == null || sid == "")
								continue;
							var itemVar = prefix + "_" + sid;
							var itemVal = Reflect.field(row, valCol.name);
							var result = buildField(valCol, itemVal, sub, macro $i{arrVar}[$v{i}], itemVar);
							for (d in result.vars)
								vars.push(d);
							vars.push(makeVar(itemVar, result.init));
							fields.push({name: sid, pos: pos, kind: FVar(result.type), access: [AFinal]});
							inits.push({field: sid, expr: macro cast $i{itemVar}});
						}
						return {
							type: TAnonymous(fields),
							vars: vars,
							init: {expr: EObjectDecl(inits), pos: pos}
						};
					} else if (subCols.length == 1) {
						var et = simpleType(subCols[0].type) ?? fullType(sub.name);
						var valCol = subCols[0].name;
						return {
							type: macro :cdb.Types.ArrayRead<$et>,
							vars: [],
							init: macro [for (l in ($rowExpr.$colName:Array<Dynamic>)) (l : Dynamic).$valCol]
						};
					} else {
						var et = fullType(sub.name);
						return {
							type: macro :cdb.Types.ArrayRead<$et>,
							vars: [],
							init: macro $rowExpr.$colName
						};
					}
				default:
					error('Unsupported column type ${col.type}');
					return null;
			}
		};

		for (line in sheet.getLines()) {
			var id = Reflect.field(line, idCol.name);
			var pobj = Reflect.field(line, polyCol.name);
			if (id == null || id == "" || pobj == null)
				continue;

			var result = buildField(polyCol, pobj, sheet, macro obj, id);

			var initBlock = [macro var obj:Dynamic = ${getData(id)}];
			for (d in result.vars)
				initBlock.push(d);
			initBlock.push(macro $i{id} = ${result.init});
			initExprs.push(macro $b{initBlock});

			fields.push({
				name: id,
				pos: pos,
				access: [AStatic, APublic],
				kind: FVar(result.type, null)
			});
		}

		fields.push({
			name: "reload",
			pos: pos,
			access: [AStatic, APublic],
			kind: FFun({args: [], ret: macro :Void, expr: macro $b{initExprs}})
		});

		return fields;
	}
	#end
}
