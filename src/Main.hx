import js.JQuery.JQueryHelper.*;
import nodejs.webkit.Menu;
import nodejs.webkit.MenuItem;
import nodejs.webkit.MenuItemType;

typedef Prefs = {
	windowPos : { x : Int, y : Int, w : Int, h : Int, max : Bool },
	curFile : String,
	curSheet : Int,
}

typedef Index = { id : String, disp : String, obj : Dynamic }

class Main {

	var window : nodejs.webkit.Window;
	var prefs : Prefs;
	var data : Data;
	var imageBank : Dynamic<String>;
	var viewSheet : Data.Sheet;
	var curSheet(default,set) : Data.Sheet;
	var smap : Map< String, { s : Data.Sheet, index : Map<String,Index> , all : Array<Index> } >;
	
	var curSavedData : String;
	var history : Array<String>;
	var redo : Array<String>;
	var mousePos : { x : Int, y : Int };
	var openedList : Map<String,Bool>;
	
	static var r_id = ~/^[A-Za-z_][A-Za-z_0-9]*$/;
	
	function new() {
		window = nodejs.webkit.Window.get();
		
		prefs = {
			windowPos : { x : 50, y : 50, w : 800, h : 600, max : false },
			curFile : null,
			curSheet : 0,
		};
		try {
			prefs = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem("prefs"));
		} catch( e : Dynamic ) {
		}

		openedList = new Map();
		initMenu();
		mousePos = { x : 0, y : 0 };
		window.window.addEventListener("keydown", onKey);
		window.window.addEventListener("mousemove", onMouseMove);
		J("body").click(function(_) {
			J(".selected").removeClass("selected");
		});
		load(true);
	}
	
	function set_curSheet( s : Data.Sheet ) {
		if( curSheet != s ) J(".selected").removeClass("selected");
		return curSheet = s;
	}
	
	function getDefault( c : Data.Column ) : Dynamic {
		if( c.opt )
			return null;
		return switch( c.type ) {
		case TInt, TFloat, TEnum(_): 0;
		case TString, TId, TRef(_), TImage: "";
		case TBool: false;
		case TList: [];
		}
	}
	
	function onMouseMove( e : js.html.MouseEvent ) {
		mousePos.x = e.clientX;
		mousePos.y = e.clientY;
	}
	
	function onKey( e : js.html.KeyboardEvent ) {
		switch( e.keyCode ) {
		case 45: // Insert
			if( curSheet != null )
				newLine(curSheet, J("tr.selected").data("index"));
		case 46: // Delete
			var indexes = [for( i in J(".selected") ) { i.change(); i.data("index"); } ];
			while( indexes.remove(null) ) {
			}
			if( indexes.length == 0 )
				return;
			indexes.sort(function(a, b) return b - a);
			for( i in indexes )
				deleteLine(curSheet, i);
			refresh();
			if( indexes.length == 1 )
				selectLine(curSheet, indexes[0] == curSheet.lines.length ? indexes[0] - 1 : indexes[0]);
			save();
		case 38: // Up Key
			var index = J("tr.selected").data("index");
			if( index != null )
				moveLine(curSheet, index, -1);
		case 40: // Down Key
			var index = J("tr.selected").data("index");
			if( index != null )
				moveLine(curSheet, index, 1);
		case 'Z'.code:
			if( e.ctrlKey && history.length > 0 ) {
				redo.push(curSavedData);
				curSavedData = history.pop();
				quickLoad(curSavedData);
				initContent();
				save(false);
			}
		case 'Y'.code:
			if( e.ctrlKey && redo.length > 0 ) {
				history.push(curSavedData);
				curSavedData = redo.pop();
				quickLoad(curSavedData);
				initContent();
				save(false);
			}
		default:
		}
	}

	function getLine( sheet : Data.Sheet, index : Int ) {
		return J(J("table[sheet='"+getPath(sheet)+"'] > tbody > tr").not(".head,.separator,.list")[index]);
	}
	
	function selectLine( sheet : Data.Sheet, index : Int ) {
		getLine(sheet, index).addClass("selected");
	}
	
	function moveLine( sheet : Data.Sheet, index : Int, delta : Int ) {
		// remove opened list
		getLine(sheet, index).next("tr.list").dblclick();
		if( delta < 0 && index > 0 ) {
			var l = sheet.lines[index];
			sheet.lines.splice(index, 1);
			sheet.lines.insert(index - 1, l);
			refresh();
			save();
			selectLine(sheet, index - 1);
		} else if( delta > 0 && sheet != null && index < sheet.lines.length-1 ) {
			var l = sheet.lines[index];
			sheet.lines.splice(index, 1);
			sheet.lines.insert(index+1, l);
			refresh();
			save();
			selectLine(sheet, index + 1);
		}
	}
	
	function changed( sheet : Data.Sheet, c : Data.Column ) {
		save();
		switch( c.type ) {
		case TId:
			makeSheet(sheet);
		case TImage:
			saveImages();
		default:
			// TODO : update display if( sheet.props.displayColumn == c.name )
		}
	}
	
	function load(noError = false) {
		history = [];
		redo = [];
		try {
			data = haxe.Json.parse(sys.io.File.getContent(prefs.curFile));
			for( s in data.sheets )
				for( c in s.columns )
					c.type = haxe.Unserializer.run(c.typeStr);
		} catch( e : Dynamic ) {
			if( !noError ) js.Lib.alert(e);
			prefs.curFile = null;
			prefs.curSheet = 0;
			data = {
				sheets : [],
			};
		}
		try {
			var img = prefs.curFile.split(".");
			img.pop();
			imageBank = haxe.Json.parse(sys.io.File.getContent(img.join(".") + ".img"));
		} catch( e : Dynamic ) {
			imageBank = null;
		}
		curSavedData = quickSave();
		initContent();
	}
	
	function save( history = true ) {
		if( history ) {
			var sdata = quickSave();
			if( sdata != curSavedData ) {
				if( curSavedData != null ) {
					this.history.push(curSavedData);
					this.redo = [];
				}
				curSavedData = sdata;
			}
		}
		if( prefs.curFile == null )
			return;
		var save = [];
		for( s in this.data.sheets ) {
			for( c in s.columns ) {
				save.push(c.type);
				if( c.typeStr == null ) c.typeStr = haxe.Serializer.run(c.type);
				c.type = null;
			}
		}
		sys.io.File.saveContent(prefs.curFile, untyped haxe.Json.stringify(data, null, "\t"));
		for( s in this.data.sheets )
			for( c in s.columns )
				c.type = save.shift();
	}
	
	function saveImages() {
		if( prefs.curFile == null )
			return;
		var img = prefs.curFile.split(".");
		img.pop();
		var path = img.join(".") + ".img";
		if( imageBank == null )
			sys.FileSystem.deleteFile(path);
		else
			sys.io.File.saveContent(path, untyped haxe.Json.stringify(imageBank, null, "\t"));
	}
	
	function quickSave() {
		return haxe.Serializer.run({ d : data, o : openedList });
	}

	function quickLoad(sdata) {
		var t = haxe.Unserializer.run(sdata);
		data = t.d;
		openedList = t.o;
	}
	
	function error( msg ) {
		js.Lib.alert(msg);
	}
	
	function makeSheet( s : Data.Sheet ) {
		var sdat = {
			s : s,
			index : new Map(),
			all : [],
		};
		var cid = null;
		for( c in s.columns )
			if( c.type == TId ) {
				for( l in s.lines ) {
					var v = Reflect.field(l, c.name);
					if( v != null && v != "" ) {
						var disp = v;
						if( s.props.displayColumn != null ) {
							disp = Reflect.field(l, s.props.displayColumn);
							if( disp == null || disp == "" ) disp = "#"+v;
						}
						var o = { id : v, disp:disp, obj : l };
						if( sdat.index.get(v) == null )
							sdat.index.set(v, o);
						sdat.all.push(o);
					}
				}
				break;
			}
		this.smap.set(s.name, sdat);
	}
	
	function valueHtml( c : Data.Column, v : Dynamic, sheet : Data.Sheet, obj : Dynamic ) : String {
		if( v == null ) {
			if( c.opt )
				return "&nbsp;";
			return '<span class="error">#NULL</span>';
		}
		return switch( c.type ) {
		case TInt, TFloat:
			v + "";
		case TId:
			v == "" ? '<span class="error">#MISSING</span>' : (smap.get(sheet.name).index.get(v).obj == obj ? v : '<span class="error">#DUP($v)</span>');
		case TString:
			v == "" ? "&nbsp;" : StringTools.htmlEscape(v);
		case TRef(sname):
			if( v == "" )
				'<span class="error">#MISSING</span>';
			else {
				var s = smap.get(sname);
				var i = s.index.get(v);
				i == null ? '<span class="error">#REF($v)</span>' : StringTools.htmlEscape(i.disp);
			}
		case TBool:
			v?"Y":"N";
		case TEnum(values):
			values[v];
		case TImage:
			if( v == "" )
				'<span class="error">#MISSING</span>'
			else {
				var data = Reflect.field(imageBank, v);
				if( data == null )
					'<span class="error">#NOTFOUND($v)</span>'
				else
					'<img src="$data"/>';
			}
		case TList:
			var a : Array<Dynamic> = v;
			var ps = getPseudoSheet(sheet, c);
			var out : Array<Dynamic> = [];
			for( v in a ) {
				var vals = [];
				for( c in ps.columns )
					switch( c.type ) {
					case TList:
						continue;
					default:
						vals.push(valueHtml(c, Reflect.field(v, c.name), ps, v));
					}
				out.push(vals.length == 1 ? vals[0] : vals);
			}
			Std.string(out);
		}
	}
	
	function popupLine( sheet : Data.Sheet, index : Int ) {
		var n = new Menu();
		var nup = new MenuItem( { label : "Move Up" } );
		var ndown = new MenuItem( { label : "Move Down" } );
		var nins = new MenuItem( { label : "Insert" } );
		var ndel = new MenuItem( { label : "Delete" } );
		var nsep = new MenuItem( { label : "Separator", type : MenuItemType.checkbox } );
		for( m in [nup, ndown, nins, ndel, nsep] )
			n.append(m);
		var hasSep = Lambda.has(sheet.separators, index);
		nsep.checked = hasSep;
		nins.click = function() {
			newLine(sheet, index);
		};
		nup.click = function() {
			moveLine(sheet, index, -1);
		};
		ndown.click = function() {
			moveLine(sheet, index, 1);
		};
		ndel.click = function() {
			deleteLine(sheet,index);
			refresh();
			save();
		};
		nsep.click = function() {
			if( hasSep )
				sheet.separators.remove(index);
			else {
				sheet.separators.push(index);
				sheet.separators.sort(Reflect.compare);
			}
			refresh();
			save();
		};
		if( sheet.props.hide )
			nsep.enabled = false;
		n.popup(mousePos.x, mousePos.y);
	}
	
	function popupColumn( sheet : Data.Sheet, c : Data.Column ) {
		var n = new Menu();
		var nedit = new MenuItem( { label : "Edit" } );
		var nins = new MenuItem( { label : "Add Column" } );
		var nleft = new MenuItem( { label : "Move Left" } );
		var nright = new MenuItem( { label : "Move Right" } );
		var ndel = new MenuItem( { label : "Delete" } );
		var ndisp = new MenuItem( { label : "Display Column", type : MenuItemType.checkbox } );
		for( m in [nedit, nins, nleft, nright, ndel, ndisp] )
			n.append(m);
		ndisp.checked = sheet.props.displayColumn == c.name;
		nedit.click = function() {
			newColumn(sheet.name, c);
		};
		nleft.click = function() {
			var index = Lambda.indexOf(sheet.columns, c);
			if( index > 0 ) {
				sheet.columns.remove(c);
				sheet.columns.insert(index - 1, c);
				refresh();
				save();
			}
		};
		nright.click = function() {
			var index = Lambda.indexOf(sheet.columns, c);
			if( index < sheet.columns.length - 1 ) {
				sheet.columns.remove(c);
				sheet.columns.insert(index + 1, c);
				refresh();
				save();
			}
		}
		ndel.click = function() {
			deleteColumn(sheet, c.name);
		};
		ndisp.click = function() {
			if( sheet.props.displayColumn == c.name ) {
				sheet.props.displayColumn = null;
			} else {
				sheet.props.displayColumn = c.name;
			}
			makeSheet(sheet);
			refresh();
			save();
		};
		nins.click = function() {
			newColumn(sheet.name);
		};
		n.popup(mousePos.x, mousePos.y);
	}
	
	function editCell( c : Data.Column, v : js.JQuery, sheet : Data.Sheet, index : Int ) {
		var obj = sheet.lines[index];
		var val : Dynamic = Reflect.field(obj, c.name);
		inline function getValue() {
			return valueHtml(c, val, sheet, obj);
		}
		inline function changed() {
			this.changed(sheet, c);
		}
		var html = getValue();
		if( v.hasClass("edit") ) return;
		function editDone() {
			v.html(html);
			v.removeClass("edit");
		}
		switch( c.type ) {
		case TInt, TFloat, TString, TId:
			v.empty();
			var i = J("<input>");
			v.addClass("edit");
			i.appendTo(v);
			if( val != null ) i.val(""+val);
			i.keydown(function(e:js.JQuery.JqEvent) {
				switch( e.keyCode ) {
				case 27:
					editDone();
				case 13:
					i.blur();
				case 9:
					i.blur();
					var n = v.next("td");
					while( n.hasClass("t_bool") || n.hasClass("t_enum") || n.hasClass("t_ref") )
						n = n.next("td");
					n.click();
					e.preventDefault();
				case 46: // delete
					var val2 = getDefault(c);
					if( val2 != val ) {
						val = val2;
						if( val == null )
							Reflect.deleteField(obj, c.name);
						else
							Reflect.setField(obj, c.name, val);
					}
					changed();
					html = getValue();
					editDone();
				}
				e.stopPropagation();
			});
			i.blur(function(_) {
				var nv = i.val();
				if( nv == "" && c.opt ) {
					if( val != null ) {
						val = html = null;
						Reflect.deleteField(obj, c.name);
						changed();
					}
				} else {
					var val2 : Dynamic = switch( c.type ) {
					case TInt:
						Std.parseInt(nv);
					case TFloat:
						var f = Std.parseFloat(nv);
						if( Math.isNaN(f) ) null else f;
					case TId:
						r_id.match(nv) ? nv : null;
					default:
						nv;
					}
					if( val2 != val && val2 != null ) {
						val = val2;
						Reflect.setField(obj, c.name, val);
						changed();
						html = getValue();
					}
				}
				editDone();
			});
			i.focus();
		case TEnum(values):
			v.empty();
			var s = J("<select>");
			v.addClass("edit");
			for( i in 0...values.length )
				J("<option>").attr("value", "" + i).attr(val == i ? "selected" : "_sel", "selected").text(values[i]).appendTo(s);
			if( c.opt )
				J("<option>").attr("value","-1").text("--- None ---").prependTo(s);
			v.append(s);
			s.change(function(_) {
				val = Std.parseInt(s.val());
				if( val < 0 ) {
					val = null;
					Reflect.deleteField(obj, c.name);
				} else
					Reflect.setField(obj, c.name, val);
				html = getValue();
				changed();
				editDone();
			});
			s.blur(function(_) {
				editDone();
			});
			s.focus();
			var event : Dynamic = cast js.Browser.document.createEvent('MouseEvents');
			event.initMouseEvent('mousedown', true, true, js.Browser.window);
			s[0].dispatchEvent(event);
		case TRef(sname):
			var sdat = smap.get(sname);
			if( sdat == null ) return;

			v.empty();
			var s = J("<select>");
			v.addClass("edit");
			for( l in sdat.all )
				J("<option>").attr("value", "" + l.id).attr(val == l.id ? "selected" : "_sel", "selected").text(l.disp).appendTo(s);
			if( c.opt )
				J("<option>").attr("value", "").text("--- None ---").prependTo(s);
			v.append(s);
			s.change(function(_) {
				val = s.val();
				if( val == "" ) {
					val = null;
					Reflect.deleteField(obj, c.name);
				} else
					Reflect.setField(obj, c.name, val);
				html = getValue();
				changed();
				editDone();
			});
			s.blur(function(_) {
				editDone();
			});
			s.focus();
			var event : Dynamic = cast js.Browser.document.createEvent('MouseEvents');
			event.initMouseEvent('mousedown', true, true, js.Browser.window);
			s[0].dispatchEvent(event);
		case TBool:
			val = !val;
			Reflect.setField(obj, c.name, val);
			v.html(getValue());
			changed();
		case TImage:
			var i = J("<input>").attr("type", "file").css("display","none").change(function(e) {
				var j = JTHIS;
				var file = j.val();
				var ext = file.split(".").pop().toLowerCase();
				if( ext == "jpeg" ) ext = "jpg";
				if( ext != "png" && ext != "gif" && ext != "jpg" ) {
					error("Unsupported image extension " + ext);
					return;
				}
				var bytes = sys.io.File.getBytes(file);
				var md5 = haxe.crypto.Md5.make(bytes).toHex();
				if( imageBank == null ) imageBank = { };
				if( !Reflect.hasField(imageBank, md5) ) {
					var data = "data:image/" + ext + ";base64," + new haxe.crypto.BaseCode(haxe.io.Bytes.ofString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")).encodeBytes(bytes).toString();
					Reflect.setField(imageBank, md5, data);
				}
				val = md5;
				Reflect.setField(obj, c.name, val);
				v.html(getValue());
				changed();
				j.remove();
			});
			i.appendTo(J("body"));
			i.click();
		case TList:
			throw "assert";
		}
	}
	
	function refresh() {
		fillTable(J("#content"), viewSheet);
	}
	
	function getPath( sheet : Data.Sheet ) {
		return sheet.path == null ? sheet.name : sheet.path;
	}
	
	function fillTable( content : js.JQuery, sheet : Data.Sheet ) {
		if( sheet.columns.length == 0 ) {
			content.html('<a href="javascript:_.newColumn(\'${sheet.name}\')">Add a column</a>');
			return;
		}
		
		var todo = [];
		var cols = J("<tr>").addClass("head");
		var types = [for( t in Type.getEnumConstructs(Data.ColumnType) ) t.substr(1).toLowerCase()];
		
		J("<td>").addClass("start").appendTo(cols);
		
		content.attr("sheet", getPath(sheet));
		content.unbind("click");
		content.click(function(e) {
			curSheet = sheet;
			e.stopPropagation();
		});

		var lines = [for( i in 0...sheet.lines.length ) {
			var l = J("<tr>");
			l.data("index", i);
			var head = J("<td>").addClass("start").text("" + i);
			head.click(function(e:js.JQuery.JqEvent) {
				if( !e.ctrlKey  )
					curSheet = null;
				curSheet = sheet;
				l.toggleClass("selected");
				e.stopPropagation();
			});
			l.mousedown(function(e) {
				if( e.which == 3 ) {
					head.click();
					haxe.Timer.delay(popupLine.bind(sheet,i),1);
					e.preventDefault();
					return;
				}
			});
			head.appendTo(l);
			l;
		}];
		
		for( c in sheet.columns ) {
			var col = J("<td>");
			col.html(c.name);
			col.css("width", c.size == null ? Std.int(100 / sheet.columns.length) + "%" : c.size + "%");
			if( sheet.props.displayColumn == c.name )
				col.addClass("display");
			col.mousedown(function(e) {
				if( e.which == 3 ) {
					haxe.Timer.delay(popupColumn.bind(sheet,c),1);
					e.preventDefault();
					return;
				}
			});
			cols.append(col);
			var ctype = "t_" + types[Type.enumIndex(c.type)];
			for( index in 0...sheet.lines.length ) {
				var obj = sheet.lines[index];
				var val : Dynamic = Reflect.field(obj,c.name);
				var v = J("<td>").addClass(ctype);
				var l = lines[index];
				v.appendTo(l);
				var html = valueHtml(c, val, sheet, obj);
				v.html(html);
				switch( c.type ) {
				case TImage:
					v.click(function(e) {
						J(".selected").removeClass("selected");
						v.addClass("selected");
						e.stopPropagation();
					});
					v.change(function(_) {
						if( Reflect.field(obj,c.name) != null ) {
							Reflect.deleteField(obj, c.name);
							refresh();
							save();
						}
					});
					v.dblclick(function(_) editCell(c, v, sheet, index));
				case TList:
					var key = getPath(sheet) + "@" + c.name + ":" + index;
					v.click(function(e) {
						var next = l.next("tr.list");
						if( next.length > 0 ) {
							if( next.data("name") == c.name ) {
								next.dblclick();
								return;
							}
							next.dblclick();
						}
						next = J("<tr>").addClass("list").data("name", c.name);
						J("<td>").appendTo(next);
						var cell = J("<td>").attr("colspan", "" + (sheet.columns.length)).appendTo(next);
						var content = J("<table>").appendTo(cell);
						var psheet = getPseudoSheet(sheet, c);
						psheet = {
							columns : psheet.columns, // SHARE
							props : psheet.props, // SHARE
							name : psheet.name, // same
							path : getPath(sheet)+":"+index, // unique
							lines : Reflect.field(obj, c.name), // ref
							separators : [], // none
						};
						curSheet = psheet; // set current
						fillTable(content, psheet);
						next.insertAfter(l);
						v.html("...");
						openedList.set(key,true);
						next.dblclick(function(e) {
							val = Reflect.field(obj, c.name);
							html = valueHtml(c, val, sheet, obj);
							v.html(html);
							next.remove();
							openedList.remove(key);
							e.stopPropagation();
						});
						e.stopPropagation();
					});
					if( openedList.get(key) )
						todo.push(function() v.click());
				default:
					v.click(function() editCell(c, v, sheet, index));
				}
			}
		}
		content.empty();
		content.append(cols);

		var snext = 0;
		for( i in 0...lines.length ) {
			content.append(lines[i]);
			if( sheet.separators[snext] == i ) {
				J("<tr>").addClass("separator").append('<td colspan="${sheet.columns.length+1}">').appendTo(content);
				snext++;
			}
		}
		for( t in todo ) t();
	}
	
	function selectSheet( s : Data.Sheet ) {
		viewSheet = curSheet = s;
		prefs.curSheet = Lambda.indexOf(data.sheets, s);
		J("#sheets li").removeClass("active").filter("#sheet_" + prefs.curSheet).addClass("active");
		refresh();
	}
	
	function newSheet() {
		J("#newsheet").show();
	}
	
	inline function getSheet( name : String ) {
		return smap.get(name).s;
	}
	
	inline function getPseudoSheet( sheet : Data.Sheet, c : Data.Column ) {
		return getSheet(sheet.name + "@" + c.name);
	}
	
	function deleteColumn( sheet : Data.Sheet, ?cname) {
		if( cname == null )
			cname = J("#newcol form [name=ref]").val();
		for( c in sheet.columns )
			if( c.name == cname ) {
				sheet.columns.remove(c);
				for( o in sheet.lines )
					Reflect.deleteField(o, c.name);
				if( sheet.props.displayColumn == c.name ) {
					sheet.props.displayColumn = null;
					makeSheet(sheet);
				}
				if( c.type == TList )
					data.sheets.remove(getPseudoSheet(sheet,c));
			}
		J("#newcol").hide();
		refresh();
		save();
	}
	
	function deleteLine( sheet : Data.Sheet, index : Int ) {
		sheet.lines.splice(index, 1);
		var prev = -1, toRemove = null;
		for( i in 0...sheet.separators.length ) {
			var s = sheet.separators[i];
			if( s >= index ) {
				if( prev == s - 1 ) toRemove = prev;
				sheet.separators[i] = s - 1;
			} else
				prev = s;
		}
		// prevent duplicates
		if( toRemove != null )
			sheet.separators.remove(toRemove);
	}
	
	function newColumn( ?sheetName : String, ?ref : Data.Column ) {
		var form = J("#newcol form");
		
		var sheets = J("[name=sheet]");
		sheets.empty();
		for( i in 0...data.sheets.length ) {
			var s = data.sheets[i];
			if( s.props.hide ) continue;
			J("<option>").attr("value", "" + i).text(s.name).appendTo(sheets);
		}

		form.removeClass("edit").removeClass("create");
		
		if( ref != null ) {
			form.addClass("edit");
			form.find("[name=name]").val(ref.name);
			form.find("[name=type]").val(ref.type.getName().substr(1).toLowerCase()).change();
			form.find("[name=opt]").attr("checked", cast ref.opt);
			form.find("[name=ref]").val(ref.name);
			switch( ref.type ) {
			case TEnum(values):
				form.find("[name=values]").val(values.join(","));
			case TRef(sname):
				form.find("[name=sheet]").val(sname);
			default:
			}
		} else {
			form.addClass("create");
			form.find("input").not("[type=submit]").val("");
		}
		form.find("[name=sheetRef]").val(sheetName == null ? "" : sheetName);
		
		J("#newcol").show();
	}
	
	function newLine( sheet : Data.Sheet, index : Null<Int> ) {
		var o = {
		};
		for( c in sheet.columns ) {
			var d = getDefault(c);
			if( d != null )
				Reflect.setField(o, c.name, d);
		}
		if( index == null )
			sheet.lines.push(o);
		else {
			for( i in 0...sheet.separators.length ) {
				var s = sheet.separators[i];
				if( s >= index ) sheet.separators[i] = s + 1;
			}
			sheet.lines.insert(index + 1, o);
		}
		refresh();
		save();
		if( index != null )
			selectLine(sheet, index + 1);
	}
		
	function createSheet( name : String ) {
		name = StringTools.trim(name);
		if( name == "" )
			return;
		J("#newsheet").hide();
		var s : Data.Sheet = {
			name : name,
			columns : [],
			lines : [],
			separators : [],
			props : {
			},
		};
		prefs.curSheet = data.sheets.length - 1;
		data.sheets.push(s);
		initContent();
		save();
	}
	
	function createColumn() {
		
		var v : Dynamic<String> = { };
		var cols = J("#col_form input, #col_form select").not("[type=submit]");
		for( i in cols )
			Reflect.setField(v, i.attr("name"), i.attr("type") == "checkbox" ? (i.is(":checked")?"on":null) : i.val());

		var sheet = viewSheet;
		var refColumn = null;
		
		if( v.sheetRef != "" )
			sheet = getSheet(v.sheetRef);
		
		if( v.ref != "" ) {
			for( c in sheet.columns )
				if( c.name == v.ref )
					refColumn = c;
		}
	
		var t : Data.ColumnType = switch( v.type ) {
		case "id":
			if( refColumn == null )
				for( c in sheet.columns )
					if( c.type == TId ) {
						error("Only one ID allowed");
						return;
					}
			TId;
		case "int": TInt;
		case "float": TFloat;
		case "string": TString;
		case "bool": TBool;
		case "enum":
			var vals = StringTools.trim(v.values).split(",");
			if( vals.length == 0 ) {
				error("Missing value list");
				return;
			}
			TEnum([for( f in vals ) StringTools.trim(f)]);
		case "ref":
			var s = data.sheets[Std.parseInt(v.sheet)];
			if( s == null ) {
				error("Sheet not found");
				return;
			}
			TRef(s.name);
		case "image":
			TImage;
		case "list":
			TList;
		default:
			return;
		}
		var c : Data.Column = {
			type : t,
			typeStr : null,
			opt : v.opt == "on",
			name : v.name,
			size : null,
		};
		
		if( refColumn != null ) {
			// modify
			
			var old = refColumn;
			if( old.name != c.name ) {
				for( o in sheet.lines ) {
					var v = Reflect.field(o, old.name);
					Reflect.deleteField(o, old.name);
					if( v != null )
						Reflect.setField(o, c.name, v);
				}
				if( old.type == TList ) {
					var s = getPseudoSheet(sheet, old);
					s.name = sheet.name + "@" + c.name;
				}
				old.name = c.name;
			}
			
			if( !old.type.equals(c.type) ) {
				var conv : Dynamic -> Dynamic = null;
				switch( [old.type, c.type] ) {
				case [TInt, TFloat]:
					// nothing
				case [TId | TRef(_), TString]:
					// nothing
				case [TString, (TId | TRef(_))]:
					var r_invalid = ~/[^A-Za-z0-9_]/g;
					conv = function(r:String) return r_invalid.replace(r, "_");
				case [TBool, (TInt | TFloat)]:
					conv = function(b) return b ? 1 : 0;
				case [TString, TInt]:
					conv = Std.parseInt;
				case [TString, TFloat]:
					conv = Std.parseFloat;
				case [TString, TBool]:
					conv = function(s) return s != "";
				case [TString, TEnum(values)]:
					var map = new Map();
					for( i in 0...values.length )
						map.set(values[i].toLowerCase(), i);
					conv = function(s:String) return map.get(s.toLowerCase());
				case [TFloat, TInt]:
					conv = Std.int;
				case [(TInt | TFloat | TBool), TString]:
					conv = Std.string;
				case [(TFloat|TInt), TBool]:
					conv = function(v:Float) return v != 0;
				case [TEnum(values1), TEnum(values2)]:
					if( values1.length != values2.length ) {
						var map = [];
						for( v in values1 ) {
							var pos = Lambda.indexOf(values2, v);
							if( pos < 0 ) map.push(null) else map.push(pos);
						}
						conv = function(i) return map[i];
					} else
						conv = null; // assume rename
				case [TInt, TEnum(values)]:
					conv = function(i) return if( i < 0 || i >= values.length ) null else i;
				case [TEnum(values), TInt]:
					// nothing
				default:
					error("Cannot convert " + old.type.getName().substr(1) + " to " + c.type.getName().substr(1));
					return;
				}
				if( conv != null )
					for( o in sheet.lines ) {
						var v = Reflect.field(o, c.name);
						if( v != null ) {
							v = conv(v);
							if( v != null ) Reflect.setField(o, c.name, v) else Reflect.deleteField(o, c.name);
						}
					}
				old.type = c.type;
				old.typeStr = null;
			}
			
			if( old.opt != c.opt ) {
				if( old.opt ) {
					for( o in sheet.lines ) {
						var v = Reflect.field(o, c.name);
						if( v == null ) {
							v = getDefault(c);
							if( v != null ) Reflect.setField(o, c.name, v);
						}
					}
				} else {
					switch( old.type ) {
					case TEnum(_):
						// first choice should not be removed
					default:
						var def = getDefault(old);
						for( o in sheet.lines ) {
							var v = Reflect.field(o, c.name);
							if( v == def )
								Reflect.deleteField(o, c.name);
						}
					}
				}
				old.opt = c.opt;
			}
			makeSheet(sheet);
				
		} else {
			// create
			for( c2 in sheet.columns )
				if( c2.name == c.name ) {
					error("Column already exists");
					return;
				}
			sheet.columns.push(c);
			for( i in sheet.lines ) {
				var def = getDefault(c);
				if( def != null ) Reflect.setField(i, c.name, def);
			}
			if( c.type == TList ) {
				// create an hidden sheet for the model
				var s : Data.Sheet = {
					name : sheet.name + "@" + c.name,
					props : { hide : true },
					separators : [],
					lines : [],
					columns : [],
				};
				data.sheets.push(s);
				makeSheet(s);
			}
		}
		
		J("#newcol").hide();
		for( c in cols )
			c.val("");
		refresh();
		save();
	}
	
	function initContent() {
		smap = new Map();
		for( s in data.sheets )
			makeSheet(s);
		var sheets = J("ul#sheets");
		sheets.children().remove();
		for( i in 0...data.sheets.length ) {
			var s = data.sheets[i];
			if( s.props.hide ) continue;
			J("<li>").text(s.name).attr("id", "sheet_" + i).appendTo(sheets).click(selectSheet.bind(s));
		}
		if( data.sheets.length == 0 ) {
			J("#content").html("<a href='javascript:_.newSheet()'>Create a sheet</a>");
			return;
		}
		var s = data.sheets[prefs.curSheet];
		if( s == null ) s = data.sheets[0];
		selectSheet(s);
	}
	
	function cleanImages() {
		if( imageBank == null )
			return;
		var used = new Map();
		for( s in data.sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TImage:
					for( obj in s.lines ) {
						var v = Reflect.field(obj, c.name);
						if( v != null ) used.set(v, true);
					}
				default:
				}
		for( f in Reflect.fields(imageBank) )
			if( !used.get(f) )
				Reflect.deleteField(imageBank, f);
	}

	function initMenu() {
		var menu = Menu.createWindowMenu();
		var mfile = new MenuItem({ label : "File" });
		var mfiles = new Menu();
		var mnew = new MenuItem( { label : "New" } );
		var mopen = new MenuItem( { label : "Open..." } );
		var msave = new MenuItem( { label : "Save As..." } );
		var mclean = new MenuItem( { label : "Clean Images" } );
		var mhelp = new MenuItem( { label : "Help" } );
		var mdebug = new MenuItem( { label : "Dev" } );
		mnew.click = function() {
			prefs.curFile = null;
			load(true);
		};
		mdebug.click = function() window.showDevTools();
		mopen.click = function() {
			var i = J("<input>").attr("type", "file").css("display","none").change(function(e) {
				var j = JTHIS;
				prefs.curFile = j.val();
				load();
				j.remove();
			});
			i.appendTo(J("body"));
			i.click();
		};
		msave.click = function() {
			var i = J("<input>").attr("type", "file").attr("nwsaveas","new.cas").css("display","none").change(function(e) {
				var j = JTHIS;
				prefs.curFile = j.val();
				save();
				j.remove();
			});
			i.appendTo(J("body"));
			i.click();
		};
		mhelp.click = function() {
			J("#help").show();
		};
		mclean.click = function() {
			if( imageBank == null ) {
				error("No image bank");
				return;
			}
			var count = Reflect.fields(imageBank).length;
			cleanImages();
			var count2 = Reflect.fields(imageBank).length;
			error((count - count2) + " unused images removed");
			if( count2 == 0 ) imageBank = null;
			refresh();
			saveImages();
		};
		mfiles.append(mnew);
		mfiles.append(mopen);
		mfiles.append(msave);
		mfiles.append(mclean);
		mfile.submenu = mfiles;
		menu.append(mfile);
		menu.append(mhelp);
		menu.append(mdebug);
		window.menu = menu;
		window.moveTo(prefs.windowPos.x, prefs.windowPos.y);
		window.resizeTo(prefs.windowPos.w, prefs.windowPos.h);
		window.show();
		if( prefs.windowPos.max ) window.maximize();
		window.on('close', function() {
			if( !prefs.windowPos.max )
				prefs.windowPos = {
					x : window.x,
					y : window.y,
					w : window.width,
					h : window.height,
					max : false,
				};
			savePrefs();
			window.close(true);
		});
		window.on('maximize', function() {
			prefs.windowPos.max = true;
		});
		window.on('unmaximize', function() {
			prefs.windowPos.max = false;
		});
	}
	
	function savePrefs() {
		js.Browser.getLocalStorage().setItem("prefs", haxe.Serializer.run(prefs));
	}
	
	static function main() {
		var m = new Main();
		Reflect.setField(js.Browser.window, "_", m);
	}

}
