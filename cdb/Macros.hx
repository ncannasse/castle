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

typedef BuildArgs = {
	@:optional var moduleName : String;
	@:optional var groupIds : Bool;
}
#end

class Macros {
	public dynamic static function formatText(str:String, vars:Dynamic):String {
		for (f in Reflect.fields(vars))
			str = str.split("::" + f + "::").join("" + Reflect.field(vars, f));
		return str;
	}

	#if macro
	public static function buildPoly(file:String, sheetName:String, args:BuildArgs = null) {
		var moduleName = args?.moduleName ?? "Data";
		var groupIds = args?.groupIds ?? false;

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
			return macro $module.$sheetName.get($module.$sheetKind.$id);  // TODO: why too many arguments here ?
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
				case TCurve: macro : cdb.Types.Curve;
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
			if(colVal == null) return null;
			var colName = col.name;
			switch (col.type) {
				case TInt | TFloat | TBool | TCurve:
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
				case TRef(refTable):
					var refType = fullType(refTable);
					var refTableName = Module.fieldName(refTable);
					return {
						type: refType,
						vars: [],
						init: col.opt ?
							macro $module.$refTableName.resolve($rowExpr.$colName.toString()) :
							macro $rowExpr.$colName == null ? null : $module.$refTableName.resolve($rowExpr.$colName.toString())
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
					if(pval == null) return null;
					var polyVar = prefix + "_" + colName;
					var result = buildField(pval.col, pval.val, polySub, macro $i{polyVar}, prefix);
					if(result == null) return null;
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
							if(result == null) return continue;
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

		if (groupIds) {
			// Group fields by separators
			var separators = sheet.separators;
			if (separators == null || separators.length == 0)
				error('Sheet needs separators for groupIds feature');
			if(separators[0].index == null)
				error("groupIds need exported groups");

			var i = 0;
			for (sepi in 0...separators.length) {
				var sep = separators[sepi];
				var nextSep = (sepi < separators.length - 1) ? separators[sepi + 1] : null;

				var groupFields = [];
				var groupInits = [];

				groupInits.push(macro var __gobj:Dynamic = {});

				while (i < sheet.lines.length) {
					var line = sheet.lines[i];
					if (nextSep != null && nextSep.index == i)
						break;
					i++;


					var id = Reflect.field(line, idCol.name);
					var pobj = Reflect.field(line, polyCol.name);

					if (id == null || id == "" || pobj == null)
						continue;

					var result = buildField(polyCol, pobj, sheet, macro __o, id);
					if(result == null) continue;
					var block = [];
					block.push(macro var __o:Dynamic = ${getData(id)});
					for (d in result.vars)
						block.push(d);
					block.push(macro __gobj.$id = ${result.init});
					groupInits.push(macro $b{block});

					groupFields.push({
						name: id,
						pos: pos,
						kind: FVar(result.type),
						access: [AFinal]
					});
				}

				groupInits.push(macro $i{sep.title} = cast __gobj);
				initExprs.push(macro $b{groupInits});
				fields.push({
					name: sep.title,
					pos: pos,
					access: [AStatic, APublic],
					kind: FVar(TAnonymous(groupFields), null)
				});
			}
		} else {
			// Flat fields
			for (line in sheet.getLines()) {
				var id = Reflect.field(line, idCol.name);
				var pobj = Reflect.field(line, polyCol.name);
				if (id == null || id == "" || pobj == null)
					continue;

				var result = buildField(polyCol, pobj, sheet, macro __o, id);
				if(result == null) continue;

				var initBlock = [macro var __o:Dynamic = ${getData(id)}];
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
