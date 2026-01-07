package cdb;
import haxe.macro.Context;
import haxe.macro.Expr.FieldType;
using haxe.macro.Tools;
using Lambda;

class Macros {

    public static function getData(file:String) : Data {
        var pos = Context.currentPos();
		var path = try Context.resolvePath(file) catch( e : Dynamic ) null;
		if( path == null ) {
			var r = Context.definedValue("resourcesPath");
			if( r != null ) {
				r = r.split("\\").join("/");
				if( !StringTools.endsWith(r, "/") ) r += "/";
				try path = Context.resolvePath(r + file) catch( e : Dynamic ) null;
			}
		}
		if( path == null )
			try path = Context.resolvePath("res/" + file) catch( e : Dynamic ) null;
		if( path == null )
			Context.error("File not found " + file, pos);
        return Parser.parse(sys.io.File.getContent(path), false);
    }

    public static function buildPoly(file: String, sheetName: String) {
        var fields = Context.getBuildFields();
        /*
        var data = getData(file);
        var pos = Context.currentPos();
        var sheet = data.sheets.find(s -> s.name == sheetName);

        if(sheet == null)
            Context.error("Sheet '" + sheetName + "' not found", pos);

        var idCol = sheet.columns.find(c -> c.type == TId);
        if(idCol == null)
            Context.error("Sheet '" + sheet.name + "' must have a unique ID", pos);
        var polyCol = sheet.columns.find(c -> c.type == TPolymorph);
        if(polyCol == null)
            Context.error("Sheet '" + sheet.name + "' must have a polymorphic column", pos);

        // Find the poly sub-sheet by name (same as Module.hx pattern)
        var polySheetName = sheet.name + "@" + polyCol.name;
        var polySheet = data.sheets.find(s -> s.name == polySheetName);
        if(polySheet == null)
            Context.error("Polymorph sub-sheet '" + polySheetName + "' not found", pos);

        for(line in sheet.lines) {
            var id = Reflect.field(line, idCol.name);
            var pval = Reflect.field(line, polyCol.name);
            if(id == null || id == "")
                continue;
            if(pval == null)
                continue;

            // Find which column in polySheet has a value (inline getPolyVal logic)
            var foundCol = null;
            var foundVal : Dynamic = null;
            for(col in polySheet.columns) {
                var v = Reflect.field(pval, col.name);
                if(v != null) {
                    foundCol = col;
                    foundVal = v;
                    break;
                }
            }

            if(foundCol == null)
                continue;

            var pvar : FieldType = switch(foundCol.type) {
                case TFloat: FVar(macro: Float, foundVal);
                case TInt: FVar(macro: Int, foundVal);
                case TString: FVar(macro: String, foundVal);
                case TBool: FVar(macro: Bool, foundVal);
                default: null;
                // case TProperties:
                // case TList:
            };
            
            if(pvar != null) {
                fields.push({
                    name : id,
                    pos : pos,
                    access: [AStatic, APublic],
                    kind : pvar
                });
            }
        }
            */

        return fields;
    }
}