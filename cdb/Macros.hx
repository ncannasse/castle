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
        var pos = Context.currentPos();

        var db = new Database();
        db.loadData(getData(file));

        var sheet = db.getSheet(sheetName);
        if(sheet == null)
            Context.error("Sheet '" + sheetName + "' not found", pos);

        var idCol = sheet.columns.find(c -> c.type == TId);
        if(idCol == null)
            Context.error("Sheet '" + sheet.name + "' must have a unique ID", pos);
        var polyCol = sheet.columns.find(c -> c.type == TPolymorph);
        if(polyCol == null)
            Context.error("Sheet '" + sheet.name + "' must have a polymorphic column", pos);

        var polySheet = sheet.getSub(polyCol);
        if(polySheet == null)
            Context.error("Polymorph sub-sheet not found for column '" + polyCol.name + "'", pos);

        for(line in sheet.getLines()) {
            var id = Reflect.field(line, idCol.name);
            var pobj = Reflect.field(line, polyCol.name);
            if(id == null || id == "")
                continue;
            if(pobj == null)
                continue;

            var pval = polySheet.getPolyVal(pobj);
            if(pval == null)
                continue;

            var pvar : FieldType = switch(pval.col.type) {
                case TFloat: FVar(macro: Float, macro $v{pval.val});
                case TInt: FVar(macro: Int, macro $v{pval.val});
                case TString: FVar(macro: String, macro $v{pval.val});
                case TBool: FVar(macro: Bool, macro $v{pval.val});
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

        return fields;
    }
}