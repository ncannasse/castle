import cdb.Data;

import js.JQuery.JQueryHelper.*;
import nodejs.webkit.Menu;
import nodejs.webkit.MenuItem;
import nodejs.webkit.MenuItemType;

class Main extends Model {

	var window : nodejs.webkit.Window;
	var viewSheet : Sheet;
	var curSheet(default,set) : Sheet;
	var mousePos : { x : Int, y : Int };
	var typesStr : String;
	
	function new() {
		super();
		window = nodejs.webkit.Window.get();
		initMenu();
		mousePos = { x : 0, y : 0 };
		window.window.addEventListener("keydown", onKey);
		window.window.addEventListener("mousemove", onMouseMove);
		J("body").click(function(_) {
			J(".selected").removeClass("selected");
		});
		load(true);
	}
	
	function set_curSheet( s : Sheet ) {
		if( curSheet != s ) J(".selected").removeClass("selected");
		return curSheet = s;
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
			J(".selected.deletable").change();
			var indexes = [for( i in J(".selected") ) { i.data("index"); } ];
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
		case 9 if( e.shiftKey): // Shift+TAB
			var sheets = data.sheets.filter(function(s) return !s.props.hide);
			var s = sheets[(Lambda.indexOf(sheets, viewSheet) + 1) % sheets.length];
			if( s != null ) selectSheet(s);
		default:
		}
	}

	function getLine( sheet : Sheet, index : Int ) {
		return J(J("table[sheet='"+getPath(sheet)+"'] > tbody > tr").not(".head,.separator,.list")[index]);
	}
	
	function selectLine( sheet : Sheet, index : Int ) {
		getLine(sheet, index).addClass("selected");
	}
	
	override function moveLine( sheet : Sheet, index : Int, delta : Int ) {
		// remove opened list
		getLine(sheet, index).next("tr.list").change();
		var index = super.moveLine(sheet, index, delta);
		if( index != null ) {
			refresh();
			save();
			selectLine(sheet, index);
		}
		return index;
	}
	
	function changed( sheet : Sheet, c : Column, index : Int ) {
		save();
		switch( c.type ) {
		case TId:
			makeSheet(sheet);
		case TImage:
			saveImages();
		default:
			if( sheet.props.displayColumn == c.name ) {
				var obj = sheet.lines[index];
				var s = smap.get(sheet.name);
				for( cid in sheet.columns )
					if( cid.type == TId ) {
						var id = Reflect.field(obj, cid.name);
						if( id != null ) {
							var disp = Reflect.field(obj, c.name);
							if( disp == null ) disp = "#" + id;
							s.index.get(id).disp = disp;
						}
					}
			}
		}
	}

	function error( msg ) {
		js.Lib.alert(msg);
	}
	
	function setErrorMessage( ?msg ) {
		if( msg == null )
			J(".errorMsg").hide();
		else
			J(".errorMsg").text(msg).show();
	}
	
	function valueHtml( c : Column, v : Dynamic, sheet : Sheet, obj : Dynamic ) : String {
		if( v == null ) {
			if( c.opt )
				return "&nbsp;";
			return '<span class="error">#NULL</span>';
		}
		return switch( c.type ) {
		case TInt, TFloat:
			switch( c.display ) {
			case Percent:
				(Math.round(v * 10000)/100) + "%";
			default:
				v + "";
			}
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
		case TCustom(name):
			var t = tmap.get(name);
			var a : Array<Dynamic> = v;
			var cas = t.cases[a[0]];
			var str = cas.name;
			if( cas.args.length > 0 ) {
				str += "(";
				var out = [];
				var pos = 1;
				for( i in 1...a.length )
					out.push(valueHtml(cas.args[i-1], a[i], sheet, this));
				str += out.join(",");
				str += ")";
			}
			str;
		}
	}
	
	function popupLine( sheet : Sheet, index : Int ) {
		var n = new Menu();
		var nup = new MenuItem( { label : "Move Up" } );
		var ndown = new MenuItem( { label : "Move Down" } );
		var nins = new MenuItem( { label : "Insert" } );
		var ndel = new MenuItem( { label : "Delete" } );
		var nsep = new MenuItem( { label : "Separator", type : MenuItemType.checkbox } );
		for( m in [nup, ndown, nins, ndel, nsep] )
			n.append(m);
		var sepIndex = Lambda.indexOf(sheet.separators, index);
		nsep.checked = sepIndex >= 0;
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
			if( sepIndex >= 0 ) {
				sheet.separators.splice(sepIndex, 1);
				if( sheet.props.separatorTitles != null ) sheet.props.separatorTitles.splice(sepIndex, 1);
			} else {
				sepIndex = sheet.separators.length;
				for( i in 0...sheet.separators.length )
					if( sheet.separators[i] > index ) {
						sepIndex = i;
						break;
					}
				sheet.separators.insert(sepIndex, index);
				if( sheet.props.separatorTitles != null && sheet.props.separatorTitles.length > sepIndex )
					sheet.props.separatorTitles.insert(sepIndex, null);
			}
			refresh();
			save();
		};
		if( sheet.props.hide )
			nsep.enabled = false;
		n.popup(mousePos.x, mousePos.y);
	}
	
	function popupColumn( sheet : Sheet, c : Column ) {
		var n = new Menu();
		var nedit = new MenuItem( { label : "Edit" } );
		var nins = new MenuItem( { label : "Add Column" } );
		var nleft = new MenuItem( { label : "Move Left" } );
		var nright = new MenuItem( { label : "Move Right" } );
		var ndel = new MenuItem( { label : "Delete" } );
		var ndisp = new MenuItem( { label : "Display Column", type : MenuItemType.checkbox } );
		for( m in [nedit, nins, nleft, nright, ndel, ndisp] )
			n.append(m);
		
		if( c.type == TId || c.type == TString ) {
			var conv = new MenuItem( { label : "Convert" } );
			var cm = new Menu();
			for( k in [
				{ n : "lowercase", f : function(s:String) return s.toLowerCase() },
				{ n : "UPPERCASE", f : function(s:String) return s.toUpperCase() },
				{ n : "UpperIdent", f : function(s:String) return s.substr(0,1).toUpperCase() + s.substr(1) },
				{ n : "lowerIdent", f : function(s:String) return s.substr(0, 1).toLowerCase() + s.substr(1) },
			] ) {
				var m = new MenuItem( { label : k.n } );
				m.click = function() {
					var refMap = new Map();
					for( obj in getSheetLines(sheet) ) {
						var t = Reflect.field(obj, c.name);
						if( t != null && t != "" ) {
							var t2 = k.f(t);
							if( t2 == null && !c.opt ) t2 = "";
							if( t2 == null )
								Reflect.deleteField(obj, c.name);
							else {
								Reflect.setField(obj, c.name, t2);
								if( t2 != "" )
									refMap.set(t, t2);
							}
						}
					}
					if( c.type == TId )
						updateRefs(sheet, refMap);
						
					makeSheet(sheet); // might have changed ID or DISP
					refresh();
					save();
				};
				cm.append(m);
			}
			conv.submenu = cm;
			n.append(conv);
		}
		
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
	
	
	function popupSheet( s : Sheet ) {
		var n = new Menu();
		var nins = new MenuItem( { label : "Add Sheet" } );
		var nleft = new MenuItem( { label : "Move Left" } );
		var nright = new MenuItem( { label : "Move Right" } );
		var ndel = new MenuItem( { label : "Delete" } );
		for( m in [nins, nleft, nright, ndel] )
			n.append(m);
		nleft.click = function() {
			var index = Lambda.indexOf(data.sheets, s);
			if( index > 0 ) {
				data.sheets.remove(s);
				data.sheets.insert(index - 1, s);
				prefs.curSheet = index - 1;
				initContent();
				save();
			}
		};
		nright.click = function() {
			var index = Lambda.indexOf(data.sheets, s);
			if( index < data.sheets.length - 1 ) {
				data.sheets.remove(s);
				data.sheets.insert(index + 1, s);
				prefs.curSheet = index + 1;
				initContent();
				save();
			}
		}
		ndel.click = function() {
			for( c in s.columns )
				switch( c.type ) {
				case TList:
					data.sheets.remove(getPseudoSheet(s, c));
				default:
				}
			data.sheets.remove(s);
			mapType(function(t) {
				return switch( t ) {
				case TRef(r) if( r == s.name ): TString;
				default: t;
				}
			});
			initContent();
			save();
		};
		nins.click = function() {
			newSheet();
		};
		n.popup(mousePos.x, mousePos.y);
	}
	
	function editCell( c : Column, v : js.JQuery, sheet : Sheet, index : Int ) {
		var obj = sheet.lines[index];
		var val : Dynamic = Reflect.field(obj, c.name);
		inline function getValue() {
			return valueHtml(c, val, sheet, obj);
		}
		inline function changed() {
			this.changed(sheet, c, index);
		}
		var html = getValue();
		if( v.hasClass("edit") ) return;
		function editDone() {
			v.html(html);
			v.removeClass("edit");
			setErrorMessage();
		}
		switch( c.type ) {
		case TInt, TFloat, TString, TId, TCustom(_):
			v.empty();
			var i = J("<input>");
			v.addClass("edit");
			i.appendTo(v);
			if( val != null )
				switch( c.type ) {
				case TCustom(t):
					i.val(typeValToString(tmap.get(t),val));
				default:
					i.val(""+val);
				}
			i.change(function(e) e.stopPropagation());
			i.keydown(function(e:js.JQuery.JqEvent) {
				function moveCell(dx, dy) {
					i.blur();
					var n;
					if( dy == 0 ) {
						if( dx > 0 ) {
							n = v.next("td");
							while( n.hasClass("t_bool") || n.hasClass("t_enum") || n.hasClass("t_ref") )
								n = n.next("td");
						} else {
							n = v.prev("td");
							while( n.hasClass("t_bool") || n.hasClass("t_enum") || n.hasClass("t_ref") )
								n = n.prev("td");
						}
					} else {
						var index = v.parent().children("td").index(cast v);
						if( dy > 0 ) {
							n = v.parent().next("tr");
							while( n.hasClass("separator") || n.hasClass("head") )
								n = n.next("tr");
						} else {
							n = v.parent().prev("tr");
							while( n.hasClass("separator") || n.hasClass("head") )
								n = n.prev("tr");
						}
						n = J(n.children("td")[index]);
					}
					n.click();
					e.preventDefault();
					
				}
				switch( e.keyCode ) {
				case 27:
					editDone();
				case 13:
					i.blur();
				case 9:
					moveCell(e.shiftKey ? -1 : 1, 0);
				case 38, 40: // up/down
					moveCell(0, e.keyCode == 38 ? -1 : 1);
				case 37, 39: // left/right
					if( e.ctrlKey )
						moveCell(e.keyCode == 37 ? -1 : 1, 0);
				case 46: // delete
					/* disable, not very friendly
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
					*/
				default:
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
						r_ident.match(nv) ? nv : null;
					case TCustom(t):
						try parseTypeVal(tmap.get(t), nv) catch( e : Dynamic ) null;
					default:
						nv;
					}
					if( val2 != val && val2 != null ) {

						if( c.type == TId && val != null ) {
							var m = new Map();
							m.set(val, val2);
							updateRefs(sheet, m);
						}
						
						val = val2;
						Reflect.setField(obj, c.name, val);
						changed();
						html = getValue();
					}
				}
				editDone();
			});
			switch( c.type ) {
			case TCustom(t):
				var t = tmap.get(t);
				i.keyup(function(_) {
					var str = i.val();
					try {
						if( str != "" )
							parseTypeVal(t, str);
						setErrorMessage();
						i.removeClass("error");
					} catch( msg : String ) {
						setErrorMessage(msg);
						i.addClass("error");
					}
				});
			default:
			}
			i.focus();
			i.select();
		case TEnum(values):
			v.empty();
			var s = J("<select>");
			v.addClass("edit");
			for( i in 0...values.length )
				J("<option>").attr("value", "" + i).attr(val == i ? "selected" : "_sel", "selected").text(values[i]).appendTo(s);
			if( c.opt )
				J("<option>").attr("value","-1").text("--- None ---").prependTo(s);
			v.append(s);
			s.change(function(e) {
				val = Std.parseInt(s.val());
				if( val < 0 ) {
					val = null;
					Reflect.deleteField(obj, c.name);
				} else
					Reflect.setField(obj, c.name, val);
				html = getValue();
				changed();
				editDone();
				e.stopPropagation();
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
			v.addClass("edit");
			
			// TODO if too many items, use autocomplete
			
			var s = J("<select>");
			for( l in sdat.all )
				J("<option>").attr("value", "" + l.id).attr(val == l.id ? "selected" : "_sel", "selected").text(l.disp).appendTo(s);
			if( c.opt || val == null || val == "" )
				J("<option>").attr("value", "").text("--- None ---").prependTo(s);
			v.append(s);
			s.change(function(e) {
				val = s.val();
				if( val == "" ) {
					val = null;
					Reflect.deleteField(obj, c.name);
				} else
					Reflect.setField(obj, c.name, val);
				html = getValue();
				changed();
				editDone();
				e.stopPropagation();
			});
			s.blur(function(_) {
				editDone();
			});
			s.focus();
			var event : Dynamic = cast js.Browser.document.createEvent('MouseEvents');
			event.initMouseEvent('mousedown', true, true, js.Browser.window);
			s[0].dispatchEvent(event);
			
		case TBool:
			if( c.opt && val == false ) {
				val = null;
				Reflect.deleteField(obj, c.name);
			} else {
				val = !val;
				Reflect.setField(obj, c.name, val);
			}
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
		var t = J("<table>");
		fillTable(t, viewSheet);
		var content = J("#content");
		content.empty();
		t.appendTo(content);
	}
	
	function fillTable( content : js.JQuery, sheet : Sheet ) {
		if( sheet.columns.length == 0 ) {
			content.html('<a href="javascript:_.newColumn(\'${sheet.name}\')">Add a column</a>');
			return;
		}
		
		var todo = [];
		var inTodo = false;
		var cols = J("<tr>").addClass("head");
		var types = [for( t in Type.getEnumConstructs(ColumnType) ) t.substr(1).toLowerCase()];
		
		J("<td>").addClass("start").appendTo(cols).click(function(_) {
			if( sheet.props.hide )
				content.change();
			else
				J("tr.list table").change();
		});
		
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
			col.css("width", Std.int(100 / sheet.columns.length) + "%");
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
					v.addClass("deletable");
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
								next.change();
								return;
							}
							next.change();
						}
						next = J("<tr>").addClass("list").data("name", c.name);
						J("<td>").appendTo(next);
						var cell = J("<td>").attr("colspan", "" + (sheet.columns.length)).appendTo(next);
						var div = J("<div>").appendTo(cell);
						if( !inTodo )
							div.hide();
						var content = J("<table>").appendTo(div);
						var psheet = getPseudoSheet(sheet, c);
						if( val == null ) {
							val = [];
							Reflect.setField(obj, c.name, val);
						}
						psheet = {
							columns : psheet.columns, // SHARE
							props : psheet.props, // SHARE
							name : psheet.name, // same
							path : getPath(sheet) + ":" + index, // unique
							lines : val, // ref
							separators : [], // none
						};
						curSheet = psheet; // set current
						fillTable(content, psheet);
						next.insertAfter(l);
						v.html("...");
						openedList.set(key,true);
						next.change(function(e) {
							if( c.opt && val.length == 0 ) {
								val = null;
								Reflect.deleteField(obj, c.name);
							}
							html = valueHtml(c, val, sheet, obj);
							v.html(html);
							div.slideUp(100, function() next.remove());
							openedList.remove(key);
							e.stopPropagation();
						});
						if( !inTodo )
							div.slideDown(100);
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
			if( sheet.separators[snext] == i ) {
				var sep = J("<tr>").addClass("separator").append('<td colspan="${sheet.columns.length+1}">').appendTo(content);
				var content = sep.find("td");
				var title = if( sheet.props.separatorTitles != null ) sheet.props.separatorTitles[snext] else null;
				if( title != null ) content.text(title);
				var pos = snext;
				sep.dblclick(function(e) {
					content.empty();
					J("<input>").appendTo(content).focus().val(title == null ? "" : title).blur(function(_) {
						title = JTHIS.val();
						JTHIS.remove();
						content.text(title);
						var titles = sheet.props.separatorTitles;
						if( titles == null ) titles = [];
						while( titles.length < pos )
							titles.push(null);
						titles[pos] = title == "" ? null : title;
						while( titles[titles.length - 1] == null && titles.length > 0 )
							titles.pop();
						if( titles.length == 0 ) titles = null;
						sheet.props.separatorTitles = titles;
						save();
					}).keyup(function(e) {
						if( e.keyCode == 13 ) JTHIS.blur();
					});
				});
				snext++;
			}
			content.append(lines[i]);
		}
		
		inTodo = true;
		for( t in todo ) t();
		inTodo = false;
	}
	
	function selectSheet( s : Sheet ) {
		viewSheet = curSheet = s;
		prefs.curSheet = Lambda.indexOf(data.sheets, s);
		J("#sheets li").removeClass("active").filter("#sheet_" + prefs.curSheet).addClass("active");
		refresh();
	}
	
	function newSheet() {
		J("#newsheet").show();
	}

	override function deleteColumn( sheet : Sheet, ?cname) {
		if( cname == null )
			cname = J("#newcol form [name=ref]").val();
		if( !super.deleteColumn(sheet, cname) )
			return false;
		J("#newcol").hide();
		refresh();
		save();
		return true;
	}
	
	function editTypes() {
		if( typesStr == null ) {
			var tl = [];
			for( t in data.customTypes )
				tl.push("enum " + t.name + " {\n" + typeCasesToString(t, "\t") + "\n}");
			typesStr = tl.join("\n\n");
		}
		var content = J("#content");
		content.html(J("#editTypes").html());
		var text = content.find("textarea");
		var apply = J(content.find("input.button")[0]);
		var cancel = J(content.find("input.button")[1]);
		var types : Array<CustomType>;
		text.change(function(_) {
			var nstr = text.val();
			if( nstr == typesStr ) return;
			typesStr = nstr;
			var errors = [];
			var t = StringTools.trim(typesStr);
			var r = ~/^enum[ \r\n\t]+([A-Za-z0-9_]+)[ \r\n\t]*\{([^}]*)\}/;
			var oldTMap = tmap;
			var descs = [];
			tmap = new Map();
			types = [];
			while( r.match(t) ) {
				var name = r.matched(1);
				var desc = r.matched(2);
				if( tmap.get(name) != null )
					errors.push("Duplicate type " + name);
				var td = { name : name, cases : [] } ;
				tmap.set(name, td);
				descs.push(desc);
				types.push(td);
				t = StringTools.trim(r.matchedRight());
			}
			for( t in types ) {
				try
					t.cases = parseTypeCases(descs.shift())
				catch( msg : Dynamic )
					errors.push(msg);
			}
			tmap = oldTMap;
			if( t != "" )
				errors.push("Invalid " + StringTools.htmlEscape(t));
			setErrorMessage(errors.length == 0 ? null : errors.join("<br>"));
			if( errors.length == 0 ) apply.removeAttr("disabled") else apply.attr("disabled","");
		});
		text.keydown(function(e) {
			if( e.keyCode == 9 ) { // TAB
				e.preventDefault();
				new js.Selection(cast text[0]).insert("\t", "", "");
			}
			e.stopPropagation();
		});
		text.keyup(function(e) {
			text.change();
			e.stopPropagation();
		});
		text.val(typesStr);
		cancel.click(function(_) {
			typesStr = null;
			setErrorMessage();
			// prevent partial changes being made
			quickLoad(curSavedData);
			initContent();
		});
		apply.click(function(_) {
			var tpairs = makePairs(data.customTypes, types);
			// check if we can remove some types used in sheets
			for( p in tpairs )
				if( p.b == null ) {
					var t = p.a;
					for( s in data.sheets )
						for( c in s.columns )
							switch( c.type ) {
							case TCustom(name) if( name == t.name ):
								error("Type "+name+" used by " + s.name + "@" + c.name+" cannot be removed");
								return;
							default:
							}
				}
			// add new types
			for( t in types )
				if( !Lambda.exists(tpairs,function(p) return p.b == t) )
					data.customTypes.push(t);
			// update existing types
			for( p in tpairs ) {
				if( p.b == null )
					data.customTypes.remove(p.a);
				else
					try updateType(p.a, p.b) catch( msg : String ) {
						error("Error while updating " + p.b.name + " : " + msg);
						return;
					}
			}
			// full rebuild
			initContent();
			typesStr = null;
			save();
		});
		typesStr = null;
		text.change();
	}
	
	function newColumn( ?sheetName : String, ?ref : Column ) {
		var form = J("#newcol form");
		
		var sheets = J("[name=sheet]");
		sheets.empty();
		for( i in 0...data.sheets.length ) {
			var s = data.sheets[i];
			if( s.props.hide ) continue;
			J("<option>").attr("value", "" + i).text(s.name).appendTo(sheets);
		}
		
		var types = J("[name=ctype]");
		types.empty();
		types.unbind("change");
		types.change(function(_) {
			J("#col_options").toggleClass("t_edit",types.val() != "");
		});
		J("<option>").attr("value", "").text("--- Select ---").appendTo(types);
		for( t in data.customTypes )
			J("<option>").attr("value", "" + t.name).text(t.name).appendTo(types);

		form.removeClass("edit").removeClass("create");
		
		if( ref != null ) {
			form.addClass("edit");
			form.find("[name=name]").val(ref.name);
			form.find("[name=type]").val(ref.type.getName().substr(1).toLowerCase()).change();
			if( ref.opt )
				form.find("[name=req]").removeAttr("checked");
			else
				form.find("[name=req]").attr("checked", "");
			form.find("[name=ref]").val(ref.name);
			form.find("[name=display]").val(ref.display == null ? "0" : Std.string(ref.display));
			switch( ref.type ) {
			case TEnum(values):
				form.find("[name=values]").val(values.join(","));
			case TRef(sname):
				form.find("[name=sheet]").val(sname);
			case TCustom(name):
				form.find("[name=ctype]").val(name);
			default:
			}
		} else {
			form.addClass("create");
			form.find("input").not("[type=submit]").val("");
			form.find("[name=req]").attr("checked", "");
		}
		form.find("[name=sheetRef]").val(sheetName == null ? "" : sheetName);
		types.change();
		
		J("#newcol").show();
	}
	
	override function newLine( sheet : Sheet, ?index : Int ) {
		super.newLine(sheet,index);
		refresh();
		save();
		if( index != null ) {
			curSheet = sheet;
			selectLine(sheet, index + 1);
		}
	}
	
	function insertLine() {
		newLine(curSheet);
	}
		
	function createSheet( name : String ) {
		name = StringTools.trim(name);
		if( !r_ident.match(name) ) {
			error("Invalid sheet name");
			return;
		}
		// name already exists
		for( s in data.sheets )
			if( s.name == name ) {
				error("Sheet name already in use");
				return;
			}
		J("#newsheet").hide();
		var s : Sheet = {
			name : name,
			columns : [],
			lines : [],
			separators : [],
			props : {
			},
		};
		prefs.curSheet = data.sheets.length;
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
	
		var t : ColumnType = switch( v.type ) {
		case "id": TId;
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
		case "custom":
			var t = tmap.get(v.ctype);
			if( t == null ) {
				error("Type not found");
				return;
			}
			TCustom(t.name);
		default:
			return;
		}
		var c : Column = {
			type : t,
			typeStr : null,
			name : v.name,
		};
		if( v.req != "on" ) c.opt = true;
		if( v.display != "0" ) c.display = cast Std.parseInt(v.display);
		
		if( refColumn != null ) {
			var err = super.updateColumn(sheet, refColumn, c);
			if( err != null ) {
				// might have partial change
				refresh();
				save();
				error(err);
				return;
			}
		} else {
			var err = super.addColumn(sheet, c);
			if( err != null ) {
				error(err);
				return;
			}
		}
		
		J("#newcol").hide();
		for( c in cols )
			c.val("");
		refresh();
		save();
	}
	
	override function initContent() {
		super.initContent();
		var sheets = J("ul#sheets");
		sheets.children().remove();
		for( i in 0...data.sheets.length ) {
			var s = data.sheets[i];
			if( s.props.hide ) continue;
			var li = J("<li>");
			li.text(s.name).attr("id", "sheet_" + i).appendTo(sheets).click(selectSheet.bind(s)).dblclick(function(_) {
				li.empty();
				J("<input>").val(s.name).appendTo(li).focus().blur(function(_) {
					li.text(s.name);
					var name = JTHIS.val();
					if( !r_ident.match(name) ) {
						error("Invalid sheet name");
						return;
					}
					var f = smap.get(name);
					if( f != null ) {
						if( f.s != s ) error("Sheet name already in use");
						return;
					}
					var old = s.name;
					s.name = name;
					
					mapType(function(t) {
						return switch( t ) {
						case TRef(o) if( o == old ):
							TRef(name);
						default:
							t;
						}
					});
					
					for( s in data.sheets )
						if( StringTools.startsWith(s.name, old + "@") )
							s.name = name + "@" + s.name.substr(old.length + 1);
					
					initContent();
					save();
				}).keydown(function(e) {
					if( e.keyCode == 13 ) JTHIS.blur();
					e.stopPropagation();
				});
			}).mousedown(function(e) {
				if( e.which == 3 ) {
					haxe.Timer.delay(popupSheet.bind(s),1);
					e.stopPropagation();
				}
			});
		}
		if( data.sheets.length == 0 ) {
			J("#content").html("<a href='javascript:_.newSheet()'>Create a sheet</a>");
			return;
		}
		var s = data.sheets[prefs.curSheet];
		if( s == null ) s = data.sheets[0];
		selectSheet(s);
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
			var i = J("<input>").attr("type", "file").attr("nwsaveas","new.cdb").css("display","none").change(function(e) {
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
	
	static function main() {
		var m = new Main();
		Reflect.setField(js.Browser.window, "_", m);
	}

}
