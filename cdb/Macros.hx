package cdb;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.Tools;
using Lambda;

typedef FieldBuild = {
	var type:ComplexType;
	var vars:Array<Expr>;
	var load:Expr;
	@:optional var init:Null<Expr>;
}

typedef BuildArgs = {
	/** CDB module name */
	@:optional var moduleName:String;

	/** Whether to group consts by separator names */
	@:optional var groupIds:Bool;

	/** Whether to wrap load expressions in try/catch */
	@:optional var safeLoad:Bool;
}
#end

class Macros {
	public dynamic static function formatText(str:String, vars:Dynamic):String {
		for (f in Reflect.fields(vars))
			str = str.split("::" + f + "::").join("" + Reflect.field(vars, f));
		return str;
	}

	#if macro
	public static function buildConsts(file:String, path:String, args:BuildArgs = null) {
		var moduleName = args?.moduleName ?? "Data";
		var groupIds = args?.groupIds ?? false;
		var safeLoad = args?.safeLoad ?? false;

		var fields = Context.getBuildFields();
		var pos = Context.currentPos();

		inline function error(msg:String)
			Context.error(msg, pos);

		var data = Module.getData(file);
		var db = new Database();
		db.loadData(data);

		var mpath = Context.getLocalModule();
		Context.registerModuleDependency(mpath, Module.getDataPath(file));

		var parts = path.split("@");
		if (parts.length < 2)
			error('Path must contain at least Sheet@Column, got: "${path}"');

		var sheetName = parts[0];
		var colPath = parts.slice(1);

		var rootSheet = db.getSheet(sheetName);
		if (rootSheet == null)
			error('Sheet "${sheetName}" not found');

		var sheetKind = Module.makeTypeName(sheetName) + "Kind";
		var idCol = rootSheet.columns.find(c -> c.type == TId);
		if (idCol == null)
			error('Sheet "${sheetName}" needs a unique ID');

		var colSheetName = parts.slice(0, -1).join("@");
		var colSheet = db.getSheet(colSheetName);
		if (colSheet == null)
			error('Column sheet "${colSheetName}" not found');

		var colName = colPath[colPath.length - 1];
		var buildCol = colSheet.columns.find(c -> c.name == colName);
		if (buildCol == null)
			error('Column "${colName}" not found in sheet "${colSheetName}"');

		function getObj(line:Dynamic):Dynamic {
			var obj = line;
			for (fieldName in colPath) {
				obj = Reflect.field(obj, fieldName);
				if (obj == null)
					return null;
			}
			return obj;
		}

		var module = macro $i{moduleName};

		var loadExprs = [];

		var fullTypes = new Map<String, ComplexType>();
		function fullType(tname:String) {
			if(fullTypes.exists(tname))
				return fullTypes.get(tname);
			var type = (moduleName + "." + Module.makeTypeName(tname)).toComplex();
			fullTypes.set(tname, type);
			return type;
		}

		function getData(id:String) {
			var e : Dynamic = macro $module.$sheetName.get($module.$sheetKind.$id);
			for (i in 0...colPath.length-1) {
				e = {expr: EField(e, colPath[i]), pos: pos};
			}
			return e;
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

		var simpleTypes = new Map<cdb.Data.ColumnType, ComplexType>();
		function simpleType(t:cdb.Data.ColumnType):Null<ComplexType> {
			if(simpleTypes.exists(t))
				return simpleTypes.get(t);
			var type = switch (t) {
				case TInt | TColor: macro :Int;
				case TFloat: macro :Float;
				case TBool: macro :Bool;
				case TString: macro :String;
				case TCurve: macro :cdb.Types.Curve;
				case TGradient: macro :cdb.Types.Gradient;
				case TImage: macro :String;
				case TFile: macro :String;
				case TTilePos: macro :cdb.Types.TilePos;
				case TTileLayer: macro :cdb.Types.TileLayer;
				case TDynamic: macro :Dynamic;
				default: null;
			};
			simpleTypes.set(t, type);
			return type;
		}

		inline function makeVar(name:String, loadExpr:Expr):Expr
			return {expr: EVars([{name: name, expr: loadExpr}]), pos: pos};

		inline function debugPos(e:Expr, info:String):Expr
			return {expr: e.expr, pos: Context.makePosition({file: info, min: 0, max: 0})};

		function getPolyVal(polySub:Sheet, colVal:Dynamic):{col:cdb.Data.Column, val:Dynamic} {
			for (pc in polySub.columns) {
				var pv = Reflect.field(colVal, pc.name);
				if (pv != null)
					return {col: pc, val: pv};
			}
			return null;
		}

		function buildField(col:cdb.Data.Column, colVal:Dynamic, sheet:Sheet, rowExpr:Expr, prefix:String):FieldBuild {
			if (colVal == null)
				return null;
			rowExpr = macro ($rowExpr : Dynamic);
			var colName = col.name;
			switch (col.type) {
				case TInt | TColor | TFloat | TBool:
					return {
						type: simpleType(col.type),
						vars: [],
						load: macro $rowExpr.$colName,
						init: macro $v{colVal}
					};
				case TCurve | TGradient | TImage | TFile | TTilePos | TTileLayer | TDynamic:
					return {
						type: simpleType(col.type),
						vars: [],
						load: macro $rowExpr.$colName
					};
				case TString:
					var textArgs = extractTextArgs(colVal);
					if (textArgs == null)
						return {type: macro :String, vars: [], load: macro $rowExpr.$colName};
					return {
						type: TFunction([TAnonymous(textArgs)], macro :String),
						vars: [],
						load: macro function(vars) {
							return cdb.Macros.formatText($rowExpr.$colName, vars);
						}
					};
				case TRef(refTable):
					var refType = fullType(refTable);
					var refTableName = Module.fieldName(refTable);
					return {
						type: refType,
						vars: [],
						load: col.opt ? macro $module.$refTableName.resolve($rowExpr.$colName.toString()) : macro $rowExpr.$colName == null ? null : $module.$refTableName.resolve($rowExpr.$colName.toString())
					};
				case TProperties:
					var subType = fullType(sheet.getSub(col).name);
					return {
						type: subType,
						vars: [],
						load: macro $rowExpr.$colName
					};
				case TPolymorph:
					var polySub = sheet.getSub(col);
					var pval = getPolyVal(polySub, colVal);
					if (pval == null)
						return null;
					var polyVar = prefix + "_" + colName;
					var result = buildField(pval.col, pval.val, polySub, macro $i{polyVar}, prefix);
					if (result == null)
						return null;
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
						var fields:Array<haxe.macro.Expr.Field> = [];
						var loads = [];
						var vars = [];
						var keys:Array<Expr> = [];
						var valueType:ComplexType = null;
						var iterator = true;
						var thisVar = prefix + "_ref";
						var keysVar = prefix + "_keys";

						var arrVar = prefix + "_" + colName;
						vars.push(makeVar(arrVar, debugPos(macro $rowExpr.$colName, 'field: $arrVar')));
						vars.push(makeVar(thisVar, macro null));

						for (i => row in val) {
							var sid:String = Reflect.field(row, idCol.name);
							if (sid == null || sid == "")
								continue;
							var itemVar = prefix + "_" + sid;
							var itemVal = Reflect.field(row, valCol.name);
							var result = buildField(valCol, itemVal, sub, macro $i{arrVar}[$v{i}], itemVar);
							if (result == null)
								return continue;
							for (d in result.vars)
								vars.push(d);
							vars.push(makeVar(itemVar, result.load));
							fields.push({
								name: sid,
								pos: pos,
								kind: FVar(result.type),
								access: [AFinal]
							});
							loads.push({field: sid, expr: macro cast $i{itemVar}});
							if(iterator) {
								keys.push(macro $v{sid});
								if (valueType == null)
									valueType = result.type;
								// comparison relies on memoized types in fullType and simpleType
								else if(!Type.enumEq(valueType, result.type))
									iterator = false;
							}
						}

						vars.push(makeVar(keysVar, {expr: EArrayDecl(keys), pos: pos}));
						if (iterator) {
							var iterElemType:ComplexType = TAnonymous([
								{name: idCol.name, pos: pos, kind: FVar(macro :String)},
								{name: valCol.name, pos: pos, kind: FVar(valueType)}
							]);
							fields.push({
								name: "iterator",
								pos: pos,
								kind: FFun({args: [], ret: macro :Iterator<$iterElemType>, expr: null}),
								meta: [{name: ":noCompletion", pos: pos}]
							});
							var iterBody:Expr = {expr: EObjectDecl([{field: idCol.name, expr: macro key}, {field: valCol.name, expr: macro cast Reflect.field($i{thisVar}, key)}]), pos: pos};
							loads.push({
								field: "iterator",
								expr: macro() -> [for (key in $i{keysVar}) $iterBody].iterator()
							});
						}

						var objExpr:Expr = {expr: EObjectDecl(loads), pos: pos};
						vars.push(macro $i{thisVar} = $objExpr);
						return {
							type: TAnonymous(fields),
							vars: vars,
							load: macro $i{thisVar}
						};
					} else if (subCols.length == 1) {
						var vcol = subCols[0];
						var vname = vcol.name;
						var valueType : ComplexType;
						var loadExpr:Expr = macro (l : Dynamic).$vname;

						if (vcol.type == TPolymorph) {
							// Special case, list of polymorphs of identical type
							var polyCol : String = null;
							var polySub = sub.getSub(vcol);

							for (row in (colVal : Array<Dynamic>)) {
								var cv = Reflect.field(row, vname);
								if (cv == null) continue;
								var pval = getPolyVal(polySub, cv);
								if (pval == null) continue;

								var result = buildField(pval.col, pval.val, polySub, macro cv, prefix);
								if (result == null) {
									valueType = null;
									break;
								}
								if (valueType == null) {
									valueType = result.type;
									polyCol = pval.col.name;
								}
								// comparison relies on memoized types in fullType and simpleType
								else if (!Type.enumEq(valueType, result.type)) {
									valueType = null;
									break;
								}
								else if (polyCol != pval.col.name) {
									valueType = null;
									break;
								}
							}
							if (valueType != null && polyCol != null)
								loadExpr = macro ($loadExpr : Dynamic).$polyCol;
						}

						if(valueType == null)
							valueType = simpleType(vcol.type) ?? fullType(sub.name);

						return {
							type: macro :cdb.Types.ArrayRead<$valueType>,
							vars: [],
							load: macro [for (l in ($rowExpr.$colName:Array<Dynamic>)) $loadExpr]
						};
					} else {
						var et = fullType(sub.name);
						return {
							type: macro :cdb.Types.ArrayRead<$et>,
							vars: [],
							load: macro $rowExpr.$colName
						};
					}
				default:
					error('Unsupported column type ${col.type}');
					return null;
			}
		};

		function safeWrap(id: String, expr:Expr):Expr {
			if(safeLoad) {
				var err = 'Failed to load "$path.$id"';
				return macro try { $expr; } catch (e:Dynamic) { trace($v{err}); throw e; };
			}
			return expr;
		}

		if (groupIds) {
			// Group fields by separators
			var separators = rootSheet.separators;
			if (separators == null || separators.length == 0)
				error('Sheet needs separators for groupIds feature');
			if (separators[0].index == null)
				error("groupIds need exported groups");

			var i = 0;
			for (sepi in 0...separators.length) {
				var sep = separators[sepi];
				var nextSep = (sepi < separators.length - 1) ? separators[sepi + 1] : null;

				var groupFields = [];
				var initExprs = [];
				var groupLoads = [];

				groupLoads.push(macro var __gobj:Dynamic = {});

				while (i < rootSheet.lines.length) {
					var line = rootSheet.lines[i];
					if (nextSep != null && nextSep.index == i)
						break;
					i++;

					var id = Reflect.field(line, idCol.name);
					var pobj = getObj(line);

					if (id == null || id == "" || pobj == null)
						continue;

					var result = buildField(buildCol, pobj, colSheet, macro __o, id);
					if (result == null)
						continue;

					{
						var block = [];
						block.push(macro var __o:Dynamic = ${getData(id)});
						for (d in result.vars)
							block.push(d);
						block.push(macro __gobj.$id = ${result.load});
						groupLoads.push(safeWrap(id, macro $b{block}));
					}

					initExprs.push({field: id, expr: result.init ?? macro cast null});

					groupFields.push({
						name: id,
						pos: pos,
						kind: FVar(result.type),
						access: [AFinal]
					});
				}

				groupLoads.push(macro $i{sep.title} = cast __gobj);
				loadExprs.push(macro $b{groupLoads});
				fields.push({
					name: sep.title,
					pos: pos,
					access: [AStatic, APublic],
					kind: FVar(TAnonymous(groupFields), {
						expr: EObjectDecl(initExprs), pos: pos
					})
				});
			}
		} else {
			// Flat fields
			for (line in rootSheet.getLines()) {
				var id = Reflect.field(line, idCol.name);
				var pobj = getObj(line);
				if (id == null || id == "" || pobj == null)
					continue;

				var result = buildField(buildCol, pobj, colSheet, macro __o, id);
				if (result == null)
					continue;

				var loadBlock = [macro var __o:Dynamic = ${getData(id)}];
				for (d in result.vars)
					loadBlock.push(d);
				loadBlock.push(macro $i{id} = cast ${result.load});
				loadExprs.push(safeWrap(id, macro $b{loadBlock}));

				fields.push({
					name: id,
					pos: pos,
					access: [AStatic, APublic],
					kind: FVar(result.type, result.init)
				});
			}
		}

		fields.push({
			name: "reload",
			pos: pos,
			access: [AStatic, APublic],
			kind: FFun({args: [], ret: macro :Void, expr: macro $b{loadExprs}})
		});

		return fields;
	}
	#end
}
