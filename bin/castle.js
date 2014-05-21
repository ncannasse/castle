(function () { "use strict";
var $hxClasses = {},$estr = function() { return js.Boot.__string_rec(this,''); };
function $extend(from, fields) {
	function Inherit() {} Inherit.prototype = from; var proto = new Inherit();
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var EReg = function(r,opt) {
	opt = opt.split("u").join("");
	this.r = new RegExp(r,opt);
};
$hxClasses["EReg"] = EReg;
EReg.__name__ = ["EReg"];
EReg.prototype = {
	match: function(s) {
		if(this.r.global) this.r.lastIndex = 0;
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,matched: function(n) {
		if(this.r.m != null && n >= 0 && n < this.r.m.length) return this.r.m[n]; else throw "EReg::matched";
	}
	,matchedRight: function() {
		if(this.r.m == null) throw "No string matched";
		var sz = this.r.m.index + this.r.m[0].length;
		return this.r.s.substr(sz,this.r.s.length - sz);
	}
	,split: function(s) {
		var d = "#__delim__#";
		return s.replace(this.r,d).split(d);
	}
	,replace: function(s,by) {
		return s.replace(this.r,by);
	}
	,__class__: EReg
};
var HxOverrides = function() { };
$hxClasses["HxOverrides"] = HxOverrides;
HxOverrides.__name__ = ["HxOverrides"];
HxOverrides.dateStr = function(date) {
	var m = date.getMonth() + 1;
	var d = date.getDate();
	var h = date.getHours();
	var mi = date.getMinutes();
	var s = date.getSeconds();
	return date.getFullYear() + "-" + (m < 10?"0" + m:"" + m) + "-" + (d < 10?"0" + d:"" + d) + " " + (h < 10?"0" + h:"" + h) + ":" + (mi < 10?"0" + mi:"" + mi) + ":" + (s < 10?"0" + s:"" + s);
};
HxOverrides.strDate = function(s) {
	var _g = s.length;
	switch(_g) {
	case 8:
		var k = s.split(":");
		var d = new Date();
		d.setTime(0);
		d.setUTCHours(k[0]);
		d.setUTCMinutes(k[1]);
		d.setUTCSeconds(k[2]);
		return d;
	case 10:
		var k1 = s.split("-");
		return new Date(k1[0],k1[1] - 1,k1[2],0,0,0);
	case 19:
		var k2 = s.split(" ");
		var y = k2[0].split("-");
		var t = k2[1].split(":");
		return new Date(y[0],y[1] - 1,y[2],t[0],t[1],t[2]);
	default:
		throw "Invalid date format : " + s;
	}
};
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) return undefined;
	return x;
};
HxOverrides.substr = function(s,pos,len) {
	if(pos != null && pos != 0 && len != null && len < 0) return "";
	if(len == null) len = s.length;
	if(pos < 0) {
		pos = s.length + pos;
		if(pos < 0) pos = 0;
	} else if(len < 0) len = s.length + len - pos;
	return s.substr(pos,len);
};
HxOverrides.indexOf = function(a,obj,i) {
	var len = a.length;
	if(i < 0) {
		i += len;
		if(i < 0) i = 0;
	}
	while(i < len) {
		if(a[i] === obj) return i;
		i++;
	}
	return -1;
};
HxOverrides.remove = function(a,obj) {
	var i = HxOverrides.indexOf(a,obj,0);
	if(i == -1) return false;
	a.splice(i,1);
	return true;
};
HxOverrides.iter = function(a) {
	return { cur : 0, arr : a, hasNext : function() {
		return this.cur < this.arr.length;
	}, next : function() {
		return this.arr[this.cur++];
	}};
};
var Lambda = function() { };
$hxClasses["Lambda"] = Lambda;
Lambda.__name__ = ["Lambda"];
Lambda.list = function(it) {
	var l = new List();
	var $it0 = $iterator(it)();
	while( $it0.hasNext() ) {
		var i = $it0.next();
		l.add(i);
	}
	return l;
};
Lambda.exists = function(it,f) {
	var $it0 = $iterator(it)();
	while( $it0.hasNext() ) {
		var x = $it0.next();
		if(f(x)) return true;
	}
	return false;
};
Lambda.indexOf = function(it,v) {
	var i = 0;
	var $it0 = $iterator(it)();
	while( $it0.hasNext() ) {
		var v2 = $it0.next();
		if(v == v2) return i;
		i++;
	}
	return -1;
};
Lambda.find = function(it,f) {
	var $it0 = $iterator(it)();
	while( $it0.hasNext() ) {
		var v = $it0.next();
		if(f(v)) return v;
	}
	return null;
};
var Level = function(model,sheet,index) {
	this.zoomView = 1.;
	this.sheet = sheet;
	this.sheetPath = model.getPath(sheet);
	this.index = index;
	this.obj = sheet.lines[index];
	this.model = model;
	this.layers = [];
	this.props = sheet.props.levelProps;
	if(this.props.zoom == null) this.props.zoom = 16;
	this.zoom = this.props.zoom;
	var lprops = new haxe.ds.StringMap();
	if(this.props.layers == null) this.props.layers = [];
	var _g = 0;
	var _g1 = this.props.layers;
	while(_g < _g1.length) {
		var ld = _g1[_g];
		++_g;
		lprops.set(ld.l,ld);
	}
	var title = "";
	var _g2 = 0;
	var _g11 = sheet.columns;
	while(_g2 < _g11.length) {
		var c = _g11[_g2];
		++_g2;
		var val = Reflect.field(this.obj,c.name);
		var _g21 = c.name;
		switch(_g21) {
		case "width":
			this.width = val;
			break;
		case "height":
			this.height = val;
			break;
		default:
		}
		{
			var _g22 = c.type;
			switch(_g22[1]) {
			case 0:
				title = val;
				break;
			case 12:
				var type = _g22[2];
				var p = lprops.get(c.name);
				if(p == null) {
					p = { l : c.name, p : { alpha : 1.}};
					this.props.layers.push(p);
				}
				lprops.remove(c.name);
				var l = new LayerData(this,c.name,model.smap.get(type).s,val,p.p);
				this.layers.push(l);
				break;
			default:
			}
		}
	}
	var $it0 = lprops.iterator();
	while( $it0.hasNext() ) {
		var c1 = $it0.next();
		HxOverrides.remove(this.props.layers,c1);
	}
	if(sheet.props.displayColumn != null) {
		var t = Reflect.field(this.obj,sheet.props.displayColumn);
		if(t != null) title = t;
	}
	this.setup();
	this.draw();
	var layer = this.layers[0];
	var state;
	try {
		state = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(this.sheetPath));
	} catch( e ) {
		state = null;
	}
	if(state != null) {
		var _g3 = 0;
		var _g12 = this.layers;
		while(_g3 < _g12.length) {
			var l1 = _g12[_g3];
			++_g3;
			if(l1.name == state.curLayer) {
				layer = l1;
				break;
			}
		}
		this.zoomView = state.zoomView;
	}
	this.setCursor(layer);
	this.updateZoom();
};
$hxClasses["Level"] = Level;
Level.__name__ = ["Level"];
Level.prototype = {
	toColor: function(v) {
		return "#" + StringTools.hex(v,6);
	}
	,setup: function() {
		var _g2 = this;
		var page = new js.JQuery("#content");
		page.html("");
		this.content = ((function($this) {
			var $r;
			var html = new js.JQuery("#levelContent").html();
			$r = new js.JQuery(html);
			return $r;
		}(this))).appendTo(page);
		var menu = this.content.find(".menu");
		var _g = 0;
		var _g1 = this.layers;
		while(_g < _g1.length) {
			var l = [_g1[_g]];
			++_g;
			var td = [new js.JQuery("<div class='item layer'>").appendTo(menu)];
			l[0].comp = td[0];
			if(!l[0].visible) td[0].addClass("hidden");
			td[0].click((function(l) {
				return function(_) {
					_g2.setCursor(l[0]);
				};
			})(l));
			new js.JQuery("<span>").text(l[0].name).appendTo(td[0]);
			if(l[0].images != null) {
				var isel = [new js.JQuery("<div class='img'>").appendTo(td[0])];
				isel[0].append(new js.JQuery(l[0].images[l[0].current]));
				isel[0].click((function(isel,td,l) {
					return function(e) {
						var list = new js.JQuery("<div class='imglist'>");
						var _g3 = 0;
						var _g21 = l[0].images.length;
						while(_g3 < _g21) {
							var i = [_g3++];
							list.append(new js.JQuery("<img>").attr("src",l[0].images[i[0]].src).click((function(i,isel,l) {
								return function(_1) {
									isel[0].html("");
									isel[0].append(new js.JQuery(l[0].images[i[0]]));
									l[0].set_current(i[0]);
									_g2.setCursor(l[0]);
								};
							})(i,isel,l)));
						}
						td[0].append(list);
						var remove = (function() {
							return function() {
								list.detach();
								((function($this) {
									var $r;
									var html1 = window;
									$r = new js.JQuery(html1);
									return $r;
								}(this))).unbind("click");
							};
						})();
						((function($this) {
							var $r;
							var html2 = window;
							$r = new js.JQuery(html2);
							return $r;
						}(this))).bind("click",(function() {
							return function(_2) {
								remove();
							};
						})());
						e.stopPropagation();
					};
				})(isel,td,l));
				continue;
			}
			var id = Level.UID++;
			var t = ((function($this) {
				var $r;
				var html3 = "<input type=\"text\" id=\"_" + Level.UID++ + "\">";
				$r = new js.JQuery(html3);
				return $r;
			}(this))).appendTo(td[0]);
			t.spectrum({ color : this.toColor(l[0].colors[l[0].current]), clickoutFiresChange : true, showButtons : false, showPaletteOnly : true, showPalette : true, palette : (function($this) {
				var $r;
				var _g22 = [];
				{
					var _g31 = 0;
					var _g4 = l[0].colors;
					while(_g31 < _g4.length) {
						var c = _g4[_g31];
						++_g31;
						_g22.push($this.toColor(c));
					}
				}
				$r = _g22;
				return $r;
			}(this)), change : (function(l) {
				return function(e1) {
					var color = Std.parseInt("0x" + e1.toHex());
					var _g41 = 0;
					var _g32 = l[0].colors.length;
					while(_g41 < _g32) {
						var i1 = _g41++;
						if(l[0].colors[i1] == color) {
							l[0].set_current(i1);
							_g2.setCursor(l[0]);
							return;
						}
					}
					_g2.setCursor(l[0]);
				};
			})(l)});
		}
		var canvas = this.content.find("canvas");
		canvas.attr("width",this.width * this.zoom + "px");
		canvas.attr("height",this.height * this.zoom + "px");
		var scroll = this.content.find(".scroll");
		var scont = new js.JQuery(".scrollContent");
		var win = nodejs.webkit.Window.get();
		var onResize = function(_3) {
			scroll.css("height",win.height - 195 + "px");
		};
		win.on("resize",onResize);
		onResize(null);
		scroll.bind("mousewheel",function(e2) {
			var d = e2.originalEvent.wheelDelta;
			if(d > 0) _g2.zoomView *= 1.2; else _g2.zoomView /= 1.2;
			_g2.savePrefs();
			e2.preventDefault();
			e2.stopPropagation();
			_g2.updateZoom();
		});
		this.cursor = this.content.find("#cursor");
		this.cursor.hide();
		var _this = Std.instance(canvas[0],HTMLCanvasElement);
		this.ctx = _this.getContext("2d");
		scont.mouseleave(function(_4) {
			_g2.curPos = null;
			_g2.cursor.hide();
		});
		scont.mousemove(function(e3) {
			var off = canvas.parent().offset();
			var cx = (e3.pageX - off.left) / (_g2.zoom * _g2.zoomView) | 0;
			var cy = (e3.pageY - off.top) / (_g2.zoom * _g2.zoomView) | 0;
			var delta;
			if(_g2.currentLayer.images != null) delta = 0; else delta = -1;
			if(cx < _g2.width && cy < _g2.height) {
				_g2.cursor.show();
				_g2.cursor.css({ marginLeft : (cx * _g2.zoom * _g2.zoomView + delta | 0) + "px", marginTop : (cy * _g2.zoom * _g2.zoomView + delta | 0) + "px"});
				_g2.curPos = { x : cx, y : cy};
				if(_g2.mouseDown) _g2.set(cx,cy);
			} else {
				_g2.cursor.hide();
				_g2.curPos = null;
			}
		});
		var onMouseUp = function(_5) {
			_g2.mouseDown = false;
			if(_g2.needSave) _g2.save();
		};
		scroll.mousedown(function(e4) {
			var _g5 = e4.which;
			switch(_g5) {
			case 1:
				_g2.mouseDown = true;
				if(_g2.curPos != null) _g2.set(_g2.curPos.x,_g2.curPos.y);
				break;
			case 3:
				if(_g2.curPos == null) return;
				var i2 = _g2.layers.length - 1;
				while(i2 >= 0) {
					var l1 = _g2.layers[i2--];
					var k = l1.data[_g2.curPos.x + _g2.curPos.y * _g2.width];
					if(k == 0 && i2 >= 0) continue;
					l1.set_current(k);
					_g2.setCursor(l1);
					break;
				}
				break;
			}
		});
		scroll.mouseleave(onMouseUp);
		scroll.mouseup(onMouseUp);
	}
	,updateZoom: function() {
		this.content.find("canvas").css({ width : (this.width * this.zoom * this.zoomView | 0) + "px", height : (this.height * this.zoom * this.zoomView | 0) + "px"});
		this.setCursor(this.currentLayer);
	}
	,onKey: function(e) {
		var _g1 = this;
		if(e.ctrlKey || this.curPos == null) return;
		var _g = e.keyCode;
		switch(_g) {
		case 80:
			var x = this.curPos.x;
			var y = this.curPos.y;
			if(this.currentLayer.data[x + y * this.width] == this.currentLayer.current) return;
			var fillRec;
			var fillRec1 = null;
			fillRec1 = function(x1,y1,k) {
				if(_g1.currentLayer.data[x1 + y1 * _g1.width] != k) return;
				_g1.currentLayer.data[x1 + y1 * _g1.width] = _g1.currentLayer.current;
				if(x1 > 0) fillRec1(x1 - 1,y1,k);
				if(y1 > 0) fillRec1(x1,y1 - 1,k);
				if(x1 < _g1.width - 1) fillRec1(x1 + 1,y1,k);
				if(y1 < _g1.height - 1) fillRec1(x1,y1 + 1,k);
			};
			fillRec = fillRec1;
			fillRec(x,y,this.currentLayer.data[x + y * this.width]);
			this.save();
			this.draw();
			break;
		default:
		}
	}
	,set: function(x,y) {
		if(this.currentLayer.data[x + y * this.width] == this.currentLayer.current) return;
		this.currentLayer.data[x + y * this.width] = this.currentLayer.current;
		this.currentLayer.dirty = true;
		this.save();
		this.draw();
	}
	,draw: function() {
		this.ctx.fillStyle = "black";
		this.ctx.fillRect(0,0,this.width * this.zoom,this.height * this.zoom);
		var first = true;
		var _g = 0;
		var _g1 = this.layers;
		while(_g < _g1.length) {
			var l = _g1[_g];
			++_g;
			this.ctx.globalAlpha = l.props.alpha;
			if(l.visible) {
				var _g3 = 0;
				var _g2 = this.width;
				while(_g3 < _g2) {
					var y = _g3++;
					var _g5 = 0;
					var _g4 = this.height;
					while(_g5 < _g4) {
						var x = _g5++;
						var k = l.data[x + y * this.width];
						if(k == 0 && !first) continue;
						if(l.images != null) {
							this.ctx.drawImage(l.images[k],x * this.zoom,y * this.zoom);
							continue;
						}
						this.ctx.fillStyle = this.toColor(l.colors[k]);
						this.ctx.fillRect(x * this.zoom,y * this.zoom,this.zoom,this.zoom);
					}
				}
			}
			first = false;
		}
	}
	,save: function() {
		if(this.mouseDown) {
			this.needSave = true;
			return;
		}
		this.needSave = false;
		var changed = false;
		var _g = 0;
		var _g1 = this.layers;
		while(_g < _g1.length) {
			var l = _g1[_g];
			++_g;
			if(l.dirty) {
				l.dirty = false;
				Reflect.setField(this.obj,l.name,l.getData());
			}
		}
		this.model.save();
	}
	,savePrefs: function() {
		var state = { zoomView : this.zoomView, curLayer : this.currentLayer.name};
		js.Browser.getLocalStorage().setItem(this.sheetPath,haxe.Serializer.run(state));
	}
	,setVisible: function(b) {
		this.currentLayer.set_visible(b);
		this.draw();
	}
	,setAlpha: function(v) {
		this.currentLayer.props.alpha = Std.parseInt(v) / 100;
		this.model.save(false);
		this.draw();
	}
	,setCursor: function(l) {
		new js.JQuery(".menu .item.selected").removeClass("selected");
		l.comp.addClass("selected");
		var old = this.currentLayer;
		this.currentLayer = l;
		if(old != l) {
			this.savePrefs();
			new js.JQuery("[name=alpha]").val(Std.string(l.props.alpha * 100 | 0));
			new js.JQuery("[name=visible]").prop("checked",l.visible);
		}
		var size = this.zoom * this.zoomView | 0;
		if(l.images != null) this.cursor.css({ background : "url('" + l.images[l.current].src + "')", backgroundSize : "cover", width : size + "px", height : size + "px", border : "none"}); else {
			var c = l.colors[l.current];
			var lum = ((c & 255) + (c >> 8 & 255) + (c >> 16 & 255)) / 765;
			this.cursor.css({ background : "#" + StringTools.hex(c,6), width : size + 2 + "px", height : size + 2 + "px", border : "1px solid " + (lum < 0.25?"white":"black")});
		}
	}
	,__class__: Level
};
var LayerData = function(level,name,s,val,p) {
	this.current = 0;
	this.visible = false;
	this.level = level;
	this.name = name;
	this.sheet = s;
	this.props = p;
	if(s.lines.length > 256) throw "Too many lines";
	if(val == null || val == "") {
		var _g = [];
		var _g2 = 0;
		var _g1 = level.width * level.height;
		while(_g2 < _g1) {
			var x = _g2++;
			_g.push(0);
		}
		this.data = _g;
	} else {
		var a = haxe.crypto.Base64.decode(val);
		if(a.length != level.width * level.height) throw "Invalid layer data";
		var _g11 = [];
		var _g3 = 0;
		var _g21 = level.width * level.height;
		while(_g3 < _g21) {
			var i = _g3++;
			_g11.push(a.b[i]);
		}
		this.data = _g11;
	}
	var idCol = null;
	var _g12 = 0;
	var _g22 = s.columns;
	while(_g12 < _g22.length) {
		var c = _g22[_g12];
		++_g12;
		var _g31 = c.type;
		switch(_g31[1]) {
		case 11:
			var _g4 = [];
			var _g5 = 0;
			var _g6 = s.lines;
			while(_g5 < _g6.length) {
				var o = _g6[_g5];
				++_g5;
				_g4.push((function($this) {
					var $r;
					var c1 = Reflect.field(o,c.name);
					$r = c1 == null?0:c1;
					return $r;
				}(this)));
			}
			this.colors = _g4;
			break;
		case 7:
			this.images = [];
			var canvas;
			var _this = window.document;
			canvas = _this.createElement("canvas");
			var size = level.zoom;
			canvas.setAttribute("width",size + "px");
			canvas.setAttribute("height",size + "px");
			var ctx = canvas.getContext("2d");
			var _g51 = 0;
			var _g41 = s.lines.length;
			while(_g51 < _g41) {
				var idx = _g51++;
				var key = Reflect.field(s.lines[idx],c.name);
				var idat = level.model.getImageData(key);
				var i1 = [(function($this) {
					var $r;
					var _this1 = window.document;
					$r = _this1.createElement("img");
					return $r;
				}(this))];
				this.images[idx] = i1[0];
				if(idat == null) {
					ctx.fillStyle = "rgba(0,0,0,0)";
					ctx.fillRect(0,0,size,size);
					ctx.fillStyle = "white";
					ctx.fillText("#" + idx,0,12);
					i1[0].src = ctx.canvas.toDataURL();
					continue;
				}
				i1[0].src = idat;
				i1[0].onload = (function(i1) {
					return function(_) {
						if(i1[0].parentNode != null && i1[0].parentNode.nodeName.toLowerCase() == "body") i1[0].parentNode.removeChild(i1[0]);
					};
				})(i1);
				window.document.body.appendChild(i1[0]);
			}
			break;
		case 0:
			idCol = c;
			break;
		default:
		}
	}
	this.names = [];
	var _g23 = 0;
	var _g13 = s.lines.length;
	while(_g23 < _g13) {
		var index = _g23++;
		var o1 = s.lines[index];
		var n;
		if(s.props.displayColumn != null) n = Reflect.field(o1,s.props.displayColumn); else n = null;
		if((n == null || n == "") && idCol != null) n = Reflect.field(o1,idCol.name);
		if(n == null || n == "") n = "#" + index;
		this.names.push(n);
	}
	var state;
	try {
		state = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(level.sheetPath + ":" + name));
	} catch( e ) {
		state = null;
	}
	if(state != null) {
		this.set_visible(state.visible);
		if(state.current < this.names.length) this.set_current(state.current);
	}
};
$hxClasses["LayerData"] = LayerData;
LayerData.__name__ = ["LayerData"];
LayerData.prototype = {
	set_visible: function(v) {
		this.visible = v;
		if(this.comp != null) this.comp.toggleClass("hidden",!this.visible);
		this.saveState();
		return v;
	}
	,set_current: function(v) {
		this.current = v;
		this.saveState();
		return v;
	}
	,saveState: function() {
		var s = { current : this.current, visible : this.visible};
		js.Browser.getLocalStorage().setItem(this.level.sheetPath + ":" + this.name,haxe.Serializer.run(s));
	}
	,getData: function() {
		var b = haxe.io.Bytes.alloc(this.level.width * this.level.height);
		var p = 0;
		var _g1 = 0;
		var _g = this.level.height;
		while(_g1 < _g) {
			var y = _g1++;
			var _g3 = 0;
			var _g2 = this.level.width;
			while(_g3 < _g2) {
				var x = _g3++;
				b.b[p] = this.data[p];
				p++;
			}
		}
		return haxe.crypto.Base64.encode(b);
	}
	,__class__: LayerData
};
var List = function() {
	this.length = 0;
};
$hxClasses["List"] = List;
List.__name__ = ["List"];
List.prototype = {
	add: function(item) {
		var x = [item];
		if(this.h == null) this.h = x; else this.q[1] = x;
		this.q = x;
		this.length++;
	}
	,remove: function(v) {
		var prev = null;
		var l = this.h;
		while(l != null) {
			if(l[0] == v) {
				if(prev == null) this.h = l[1]; else prev[1] = l[1];
				if(this.q == l) this.q = prev;
				this.length--;
				return true;
			}
			prev = l;
			l = l[1];
		}
		return false;
	}
	,iterator: function() {
		return { h : this.h, hasNext : function() {
			return this.h != null;
		}, next : function() {
			if(this.h == null) return null;
			var x = this.h[0];
			this.h = this.h[1];
			return x;
		}};
	}
	,__class__: List
};
var K = function() { };
$hxClasses["K"] = K;
K.__name__ = ["K"];
var Model = function() {
	this.openedList = new haxe.ds.StringMap();
	this.r_ident = new EReg("^[A-Za-z_][A-Za-z0-9_]*$","");
	this.prefs = { windowPos : { x : 50, y : 50, w : 800, h : 600, max : false}, curFile : null, curSheet : 0};
	try {
		this.prefs = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem("prefs"));
	} catch( e ) {
	}
};
$hxClasses["Model"] = Model;
Model.__name__ = ["Model"];
Model.prototype = {
	getImageData: function(key) {
		return Reflect.field(this.imageBank,key);
	}
	,getSheet: function(name) {
		return this.smap.get(name).s;
	}
	,getPseudoSheet: function(sheet,c) {
		return this.smap.get(sheet.name + "@" + c.name).s;
	}
	,getParentSheet: function(sheet) {
		if(!sheet.props.hide) return null;
		var parts = sheet.name.split("@");
		var colName = parts.pop();
		return { s : this.getSheet(parts.join("@")), c : colName};
	}
	,getSheetLines: function(sheet) {
		var p = this.getParentSheet(sheet);
		if(p == null) return sheet.lines;
		var all = [];
		var _g = 0;
		var _g1 = this.getSheetLines(p.s);
		while(_g < _g1.length) {
			var obj = _g1[_g];
			++_g;
			var v = Reflect.field(obj,p.c);
			if(v != null) {
				var _g2 = 0;
				while(_g2 < v.length) {
					var v1 = v[_g2];
					++_g2;
					all.push(v1);
				}
			}
		}
		return all;
	}
	,getSheetObjects: function(sheet) {
		var p = this.getParentSheet(sheet);
		if(p == null) {
			var _g = [];
			var _g2 = 0;
			var _g1 = sheet.lines.length;
			while(_g2 < _g1) {
				var i = _g2++;
				_g.push({ path : [sheet.lines[i]], indexes : [i]});
			}
			return _g;
		}
		var all = [];
		var _g11 = 0;
		var _g21 = this.getSheetObjects(p.s);
		while(_g11 < _g21.length) {
			var obj = _g21[_g11];
			++_g11;
			var v = Reflect.field(obj.path[obj.path.length - 1],p.c);
			if(v != null) {
				var _g4 = 0;
				var _g3 = v.length;
				while(_g4 < _g3) {
					var i1 = _g4++;
					var sobj = v[i1];
					var p1 = obj.path.slice();
					var idx = obj.indexes.slice();
					p1.push(sobj);
					idx.push(i1);
					all.push({ path : p1, indexes : idx});
				}
			}
		}
		return all;
	}
	,newLine: function(sheet,index) {
		var o = { };
		var _g = 0;
		var _g1 = sheet.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			var d = this.getDefault(c);
			if(d != null) o[c.name] = d;
		}
		if(index == null) sheet.lines.push(o); else {
			var _g11 = 0;
			var _g2 = sheet.separators.length;
			while(_g11 < _g2) {
				var i = _g11++;
				var s = sheet.separators[i];
				if(s > index) sheet.separators[i] = s + 1;
			}
			sheet.lines.splice(index + 1,0,o);
			this.changeLineOrder(sheet,(function($this) {
				var $r;
				var _g3 = [];
				{
					var _g21 = 0;
					var _g12 = sheet.lines.length;
					while(_g21 < _g12) {
						var i1 = _g21++;
						_g3.push(i1 <= index?i1:i1 + 1);
					}
				}
				$r = _g3;
				return $r;
			}(this)));
		}
	}
	,getPath: function(sheet) {
		if(sheet.path == null) return sheet.name; else return sheet.path;
	}
	,getDefault: function(c) {
		if(c.opt) return null;
		{
			var _g = c.type;
			switch(_g[1]) {
			case 3:case 4:case 5:case 10:case 11:
				return 0;
			case 1:case 0:case 6:case 7:case 12:
				return "";
			case 2:
				return false;
			case 8:
				return [];
			case 9:
				return null;
			}
		}
	}
	,hasColumn: function(s,name,types) {
		var _g = 0;
		var _g1 = s.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			if(c.name == name) {
				if(types != null) {
					var _g2 = 0;
					while(_g2 < types.length) {
						var t = types[_g2];
						++_g2;
						if(Type.enumEq(c.type,t)) return true;
					}
					return false;
				}
				return true;
			}
		}
		return false;
	}
	,save: function(history) {
		if(history == null) history = true;
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			var _g2 = 0;
			var _g3 = Reflect.fields(s.props);
			while(_g2 < _g3.length) {
				var p = _g3[_g2];
				++_g2;
				var v = Reflect.field(s.props,p);
				if(v == null || v == false) Reflect.deleteField(s.props,p);
			}
			if(s.props.hasIndex) {
				var lines = this.getSheetLines(s);
				var _g31 = 0;
				var _g21 = lines.length;
				while(_g31 < _g21) {
					var i = _g31++;
					lines[i].index = i;
				}
			}
			if(s.props.hasGroup) {
				var lines1 = this.getSheetLines(s);
				var gid = 0;
				var sindex = 0;
				var titles = s.props.separatorTitles;
				if(titles != null) {
					if(s.separators[sindex] == 0 && titles[sindex] != null) sindex++;
					var _g32 = 0;
					var _g22 = lines1.length;
					while(_g32 < _g22) {
						var i1 = _g32++;
						if(s.separators[sindex] == i1) {
							if(titles[sindex] != null) gid++;
							sindex++;
						}
						lines1[i1].group = gid;
					}
				}
			}
		}
		if(history) {
			var sdata = this.quickSave();
			if(sdata != this.curSavedData) {
				if(this.curSavedData != null) {
					this.history.push(this.curSavedData);
					this.redo = [];
				}
				this.curSavedData = sdata;
			}
		}
		if(this.prefs.curFile == null) return;
		var save = [];
		var _g4 = 0;
		var _g11 = this.data.sheets;
		while(_g4 < _g11.length) {
			var s1 = _g11[_g4];
			++_g4;
			var _g23 = 0;
			var _g33 = s1.columns;
			while(_g23 < _g33.length) {
				var c = _g33[_g23];
				++_g23;
				save.push(c.type);
				if(c.typeStr == null) c.typeStr = cdb.Parser.saveType(c.type);
				Reflect.deleteField(c,"type");
			}
		}
		var _g5 = 0;
		var _g12 = this.data.customTypes;
		while(_g5 < _g12.length) {
			var t = _g12[_g5];
			++_g5;
			var _g24 = 0;
			var _g34 = t.cases;
			while(_g24 < _g34.length) {
				var c1 = _g34[_g24];
				++_g24;
				var _g41 = 0;
				var _g51 = c1.args;
				while(_g41 < _g51.length) {
					var a = _g51[_g41];
					++_g41;
					save.push(a.type);
					if(a.typeStr == null) a.typeStr = cdb.Parser.saveType(a.type);
					Reflect.deleteField(a,"type");
				}
			}
		}
		sys.io.File.saveContent(this.prefs.curFile,js.Node.stringify(this.data,null,"\t"));
		var _g6 = 0;
		var _g13 = this.data.sheets;
		while(_g6 < _g13.length) {
			var s2 = _g13[_g6];
			++_g6;
			var _g25 = 0;
			var _g35 = s2.columns;
			while(_g25 < _g35.length) {
				var c2 = _g35[_g25];
				++_g25;
				c2.type = save.shift();
			}
		}
		var _g7 = 0;
		var _g14 = this.data.customTypes;
		while(_g7 < _g14.length) {
			var t1 = _g14[_g7];
			++_g7;
			var _g26 = 0;
			var _g36 = t1.cases;
			while(_g26 < _g36.length) {
				var c3 = _g36[_g26];
				++_g26;
				var _g42 = 0;
				var _g52 = c3.args;
				while(_g42 < _g52.length) {
					var a1 = _g52[_g42];
					++_g42;
					a1.type = save.shift();
				}
			}
		}
	}
	,saveImages: function() {
		if(this.prefs.curFile == null) return;
		var img = this.prefs.curFile.split(".");
		img.pop();
		var path = img.join(".") + ".img";
		if(this.imageBank == null) js.Node.require("fs").unlinkSync(path); else sys.io.File.saveContent(path,js.Node.stringify(this.imageBank,null,"\t"));
	}
	,quickSave: function() {
		return haxe.Serializer.run({ d : this.data, o : this.openedList});
	}
	,quickLoad: function(sdata) {
		var t = haxe.Unserializer.run(sdata);
		this.data = t.d;
		this.openedList = t.o;
	}
	,moveLine: function(sheet,index,delta) {
		if(delta < 0 && index > 0) {
			var l = sheet.lines[index];
			sheet.lines.splice(index,1);
			sheet.lines.splice(index - 1,0,l);
			var arr;
			var _g = [];
			var _g2 = 0;
			var _g1 = sheet.lines.length;
			while(_g2 < _g1) {
				var i = _g2++;
				_g.push(i);
			}
			arr = _g;
			arr[index] = index - 1;
			arr[index - 1] = index;
			this.changeLineOrder(sheet,arr);
			return index - 1;
		} else if(delta > 0 && sheet != null && index < sheet.lines.length - 1) {
			var l1 = sheet.lines[index];
			sheet.lines.splice(index,1);
			sheet.lines.splice(index + 1,0,l1);
			var arr1;
			var _g3 = [];
			var _g21 = 0;
			var _g11 = sheet.lines.length;
			while(_g21 < _g11) {
				var i1 = _g21++;
				_g3.push(i1);
			}
			arr1 = _g3;
			arr1[index] = index + 1;
			arr1[index + 1] = index;
			this.changeLineOrder(sheet,arr1);
			return index + 1;
		}
		return null;
	}
	,deleteLine: function(sheet,index) {
		var arr;
		var _g = [];
		var _g2 = 0;
		var _g1 = sheet.lines.length;
		while(_g2 < _g1) {
			var i = _g2++;
			_g.push(i < index?i:i - 1);
		}
		arr = _g;
		arr[index] = -1;
		this.changeLineOrder(sheet,arr);
		sheet.lines.splice(index,1);
		var prev = -1;
		var toRemove = null;
		var _g21 = 0;
		var _g11 = sheet.separators.length;
		while(_g21 < _g11) {
			var i1 = _g21++;
			var s = sheet.separators[i1];
			if(s > index) {
				if(prev == s) toRemove = i1;
				sheet.separators[i1] = s - 1;
			} else prev = s;
		}
		if(toRemove != null) {
			sheet.separators.splice(toRemove,1);
			if(sheet.props.separatorTitles != null) sheet.props.separatorTitles.splice(toRemove,1);
		}
	}
	,deleteColumn: function(sheet,cname) {
		var _g = 0;
		var _g1 = sheet.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			if(c.name == cname) {
				HxOverrides.remove(sheet.columns,c);
				var _g2 = 0;
				var _g3 = this.getSheetLines(sheet);
				while(_g2 < _g3.length) {
					var o = _g3[_g2];
					++_g2;
					Reflect.deleteField(o,c.name);
				}
				if(sheet.props.displayColumn == c.name) {
					sheet.props.displayColumn = null;
					this.makeSheet(sheet);
				}
				if(c.type == cdb.ColumnType.TList) this.deleteSheet(this.smap.get(sheet.name + "@" + c.name).s);
				return true;
			}
		}
		return false;
	}
	,deleteSheet: function(sheet) {
		HxOverrides.remove(this.data.sheets,sheet);
		this.smap.remove(sheet.name);
		var _g = 0;
		var _g1 = sheet.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			var _g2 = c.type;
			switch(_g2[1]) {
			case 8:
				this.deleteSheet(this.smap.get(sheet.name + "@" + c.name).s);
				break;
			default:
			}
		}
		this.mapType(function(t) {
			switch(t[1]) {
			case 6:
				var r = t[2];
				if(r == sheet.name) return cdb.ColumnType.TString; else return t;
				break;
			case 12:
				var r = t[2];
				if(r == sheet.name) return cdb.ColumnType.TString; else return t;
				break;
			default:
				return t;
			}
		});
	}
	,addColumn: function(sheet,c,index) {
		var _g = 0;
		var _g1 = sheet.columns;
		while(_g < _g1.length) {
			var c2 = _g1[_g];
			++_g;
			if(c2.name == c.name) return "Column already exists"; else if(c2.type == cdb.ColumnType.TId && c.type == cdb.ColumnType.TId) return "Only one ID allowed";
		}
		if(c.name == "index" && sheet.props.hasIndex) return "Sheet already has an index";
		if(c.name == "group" && sheet.props.hasGroup) return "Sheet already has a group";
		if(index == null) sheet.columns.push(c); else sheet.columns.splice(index,0,c);
		var _g2 = 0;
		var _g11 = this.getSheetLines(sheet);
		while(_g2 < _g11.length) {
			var i = _g11[_g2];
			++_g2;
			var def = this.getDefault(c);
			if(def != null) i[c.name] = def;
		}
		if(c.type == cdb.ColumnType.TList) {
			var s = { name : sheet.name + "@" + c.name, props : { hide : true}, separators : [], lines : [], columns : []};
			this.data.sheets.push(s);
			this.makeSheet(s);
		}
		return null;
	}
	,getConvFunction: function(old,t) {
		var conv = null;
		if(Type.enumEq(old,t)) return { f : null};
		switch(old[1]) {
		case 3:
			switch(t[1]) {
			case 4:
				break;
			case 1:
				conv = Std.string;
				break;
			case 2:
				conv = function(v) {
					return v != 0;
				};
				break;
			case 5:
				var values = t[2];
				conv = function(i) {
					if(i < 0 || i >= values.length) return null; else return i;
				};
				break;
			case 11:
				conv = function(i1) {
					return i1;
				};
				break;
			default:
				return null;
			}
			break;
		case 0:case 6:case 12:
			switch(t[1]) {
			case 1:
				break;
			default:
				return null;
			}
			break;
		case 1:
			switch(t[1]) {
			case 0:case 6:case 12:
				var r_invalid = new EReg("[^A-Za-z0-9_]","g");
				conv = function(r) {
					return r_invalid.replace(r,"_");
				};
				break;
			case 3:
				conv = Std.parseInt;
				break;
			case 4:
				conv = function(str) {
					var f = Std.parseFloat(str);
					if(isNaN(f)) return null; else return f;
				};
				break;
			case 2:
				conv = function(s) {
					return s != "";
				};
				break;
			case 5:
				var values1 = t[2];
				var map = new haxe.ds.StringMap();
				var _g1 = 0;
				var _g = values1.length;
				while(_g1 < _g) {
					var i2 = _g1++;
					var key = values1[i2].toLowerCase();
					map.set(key,i2);
				}
				conv = function(s1) {
					var key1 = s1.toLowerCase();
					return map.get(key1);
				};
				break;
			default:
				return null;
			}
			break;
		case 2:
			switch(t[1]) {
			case 3:case 4:
				conv = function(b) {
					if(b) return 1; else return 0;
				};
				break;
			case 1:
				conv = Std.string;
				break;
			default:
				return null;
			}
			break;
		case 4:
			switch(t[1]) {
			case 3:
				conv = Std["int"];
				break;
			case 1:
				conv = Std.string;
				break;
			case 2:
				conv = function(v) {
					return v != 0;
				};
				break;
			default:
				return null;
			}
			break;
		case 5:
			switch(t[1]) {
			case 5:
				var values11 = old[2];
				var values2 = t[2];
				var map1 = [];
				var _g2 = 0;
				var _g3 = this.makePairs((function($this) {
					var $r;
					var _g4 = [];
					{
						var _g21 = 0;
						var _g11 = values11.length;
						while(_g21 < _g11) {
							var i3 = _g21++;
							_g4.push({ name : values11[i3], i : i3});
						}
					}
					$r = _g4;
					return $r;
				}(this)),(function($this) {
					var $r;
					var _g12 = [];
					{
						var _g31 = 0;
						var _g22 = values2.length;
						while(_g31 < _g22) {
							var i4 = _g31++;
							_g12.push({ name : values2[i4], i : i4});
						}
					}
					$r = _g12;
					return $r;
				}(this)));
				while(_g2 < _g3.length) {
					var p = _g3[_g2];
					++_g2;
					if(p.b == null) continue;
					map1[p.a.i] = p.b.i;
				}
				conv = function(i5) {
					return map1[i5];
				};
				break;
			case 3:
				var values3 = old[2];
				break;
			case 10:
				var val1 = old[2];
				var val2 = t[2];
				if(Std.string(val1) == Std.string(val2)) conv = function(i6) {
					return 1 << i6;
				}; else return null;
				break;
			default:
				return null;
			}
			break;
		case 10:
			switch(t[1]) {
			case 10:
				var values12 = old[2];
				var values21 = t[2];
				var map2 = [];
				var _g23 = 0;
				var _g32 = this.makePairs((function($this) {
					var $r;
					var _g5 = [];
					{
						var _g24 = 0;
						var _g13 = values12.length;
						while(_g24 < _g13) {
							var i7 = _g24++;
							_g5.push({ name : values12[i7], i : i7});
						}
					}
					$r = _g5;
					return $r;
				}(this)),(function($this) {
					var $r;
					var _g14 = [];
					{
						var _g33 = 0;
						var _g25 = values21.length;
						while(_g33 < _g25) {
							var i8 = _g33++;
							_g14.push({ name : values21[i8], i : i8});
						}
					}
					$r = _g14;
					return $r;
				}(this)));
				while(_g23 < _g32.length) {
					var p1 = _g32[_g23];
					++_g23;
					if(p1.b == null) continue;
					map2[p1.a.i] = p1.b.i;
				}
				conv = function(i9) {
					var out = 0;
					var k = 0;
					while(i9 >= 1 << k) {
						if(map2[k] != null && (i9 & 1 << k) != 0) out |= 1 << map2[k];
						k++;
					}
					return out;
				};
				break;
			case 3:
				var values4 = old[2];
				break;
			default:
				return null;
			}
			break;
		case 11:
			switch(t[1]) {
			case 3:
				conv = function(i1) {
					return i1;
				};
				break;
			default:
				return null;
			}
			break;
		default:
			return null;
		}
		return { f : conv};
	}
	,updateColumn: function(sheet,old,c) {
		var _g = this;
		if(old.name != c.name) {
			var _g1 = 0;
			var _g11 = sheet.columns;
			while(_g1 < _g11.length) {
				var c2 = _g11[_g1];
				++_g1;
				if(c2.name == c.name) return "Column name already used";
			}
			if(c.name == "index" && sheet.props.hasIndex) return "Sheet already has an index";
			if(c.name == "group" && sheet.props.hasGroup) return "Sheet already has a group";
			var _g2 = 0;
			var _g12 = this.getSheetLines(sheet);
			while(_g2 < _g12.length) {
				var o = _g12[_g2];
				++_g2;
				var v = Reflect.field(o,old.name);
				Reflect.deleteField(o,old.name);
				if(v != null) o[c.name] = v;
			}
			var renameRec;
			var renameRec1 = null;
			renameRec1 = function(sheet1,col) {
				var s = _g.smap.get(sheet1.name + "@" + col.name).s;
				s.name = sheet1.name + "@" + c.name;
				var _g13 = 0;
				var _g21 = s.columns;
				while(_g13 < _g21.length) {
					var c1 = _g21[_g13];
					++_g13;
					if(c1.type == cdb.ColumnType.TList) renameRec1(s,c1);
				}
				_g.makeSheet(s);
			};
			renameRec = renameRec1;
			if(old.type == cdb.ColumnType.TList) renameRec(sheet,old);
			old.name = c.name;
		}
		if(!Type.enumEq(old.type,c.type)) {
			var conv = this.getConvFunction(old.type,c.type);
			if(conv == null) return "Cannot convert " + this.typeStr(old.type) + " to " + this.typeStr(c.type);
			var conv1 = conv.f;
			if(conv1 != null) {
				var _g3 = 0;
				var _g14 = this.getSheetLines(sheet);
				while(_g3 < _g14.length) {
					var o1 = _g14[_g3];
					++_g3;
					var v1 = Reflect.field(o1,c.name);
					if(v1 != null) {
						v1 = conv1(v1);
						if(v1 != null) o1[c.name] = v1; else Reflect.deleteField(o1,c.name);
					}
				}
			}
			old.type = c.type;
			old.typeStr = null;
		}
		if(old.opt != c.opt) {
			if(old.opt) {
				var _g4 = 0;
				var _g15 = this.getSheetLines(sheet);
				while(_g4 < _g15.length) {
					var o2 = _g15[_g4];
					++_g4;
					var v2 = Reflect.field(o2,c.name);
					if(v2 == null) {
						v2 = this.getDefault(c);
						if(v2 != null) o2[c.name] = v2;
					}
				}
			} else {
				var _g5 = old.type;
				switch(_g5[1]) {
				case 5:
					break;
				default:
					var def = this.getDefault(old);
					var _g16 = 0;
					var _g22 = this.getSheetLines(sheet);
					while(_g16 < _g22.length) {
						var o3 = _g22[_g16];
						++_g16;
						var v3 = Reflect.field(o3,c.name);
						var _g31 = c.type;
						switch(_g31[1]) {
						case 8:
							var v4 = v3;
							if(v4.length == 0) Reflect.deleteField(o3,c.name);
							break;
						default:
							if(v3 == def) Reflect.deleteField(o3,c.name);
						}
					}
				}
			}
			old.opt = c.opt;
		}
		if(c.display == null) Reflect.deleteField(old,"display"); else old.display = c.display;
		this.makeSheet(sheet);
		return null;
	}
	,load: function(noError) {
		if(noError == null) noError = false;
		this.history = [];
		this.redo = [];
		try {
			this.data = cdb.Parser.parse(sys.io.File.getContent(this.prefs.curFile));
		} catch( e ) {
			if(!noError) js.Lib.alert(e);
			this.prefs.curFile = null;
			this.prefs.curSheet = 0;
			this.data = { sheets : [], customTypes : []};
		}
		try {
			var img = this.prefs.curFile.split(".");
			img.pop();
			this.imageBank = haxe.Json.parse(sys.io.File.getContent(img.join(".") + ".img"));
		} catch( e1 ) {
			this.imageBank = null;
		}
		this.curSavedData = this.quickSave();
		this.initContent();
	}
	,initContent: function() {
		this.smap = new haxe.ds.StringMap();
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			this.makeSheet(s);
		}
		this.tmap = new haxe.ds.StringMap();
		var _g2 = 0;
		var _g11 = this.data.customTypes;
		while(_g2 < _g11.length) {
			var t = _g11[_g2];
			++_g2;
			this.tmap.set(t.name,t);
		}
	}
	,sortById: function(a,b) {
		if(a.disp > b.disp) return 1; else return -1;
	}
	,makeSheet: function(s) {
		var sdat = { s : s, index : new haxe.ds.StringMap(), all : []};
		var cid = null;
		var lines = this.getSheetLines(s);
		var _g = 0;
		var _g1 = s.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			if(c.type == cdb.ColumnType.TId) {
				var _g2 = 0;
				while(_g2 < lines.length) {
					var l = lines[_g2];
					++_g2;
					var v = Reflect.field(l,c.name);
					if(v != null && v != "") {
						var disp = v;
						if(s.props.displayColumn != null) {
							disp = Reflect.field(l,s.props.displayColumn);
							if(disp == null || disp == "") disp = "#" + v;
						}
						var o = { id : v, disp : disp, obj : l};
						if(sdat.index.get(v) == null) sdat.index.set(v,o);
						sdat.all.push(o);
					}
				}
				sdat.all.sort($bind(this,this.sortById));
				break;
			}
		}
		this.smap.set(s.name,sdat);
	}
	,cleanImages: function() {
		if(this.imageBank == null) return;
		var used = new haxe.ds.StringMap();
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			var _g2 = 0;
			var _g3 = s.columns;
			while(_g2 < _g3.length) {
				var c = _g3[_g2];
				++_g2;
				var _g4 = c.type;
				switch(_g4[1]) {
				case 7:
					var _g5 = 0;
					var _g6 = this.getSheetLines(s);
					while(_g5 < _g6.length) {
						var obj = _g6[_g5];
						++_g5;
						var v = Reflect.field(obj,c.name);
						if(v != null) used.set(v,true);
					}
					break;
				default:
				}
			}
		}
		var _g7 = 0;
		var _g11 = Reflect.fields(this.imageBank);
		while(_g7 < _g11.length) {
			var f = _g11[_g7];
			++_g7;
			if(!used.get(f)) Reflect.deleteField(this.imageBank,f);
		}
	}
	,savePrefs: function() {
		js.Browser.getLocalStorage().setItem("prefs",haxe.Serializer.run(this.prefs));
	}
	,objToString: function(sheet,obj,esc) {
		if(esc == null) esc = false;
		if(obj == null) return "null";
		var fl = [];
		var _g = 0;
		var _g1 = sheet.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			var v = Reflect.field(obj,c.name);
			if(v == null) continue;
			fl.push(c.name + " : " + this.colToString(sheet,c,v,esc));
		}
		if(fl.length == 0) return "{}";
		return "{ " + fl.join(", ") + " }";
	}
	,colToString: function(sheet,c,v,esc) {
		if(esc == null) esc = false;
		if(v == null) return "null";
		var _g = c.type;
		switch(_g[1]) {
		case 8:
			var a = v;
			if(a.length == 0) return "[]";
			var s = this.smap.get(sheet.name + "@" + c.name).s;
			return "[ " + ((function($this) {
				var $r;
				var _g1 = [];
				{
					var _g2 = 0;
					while(_g2 < a.length) {
						var v1 = a[_g2];
						++_g2;
						_g1.push($this.objToString(s,v1,esc));
					}
				}
				$r = _g1;
				return $r;
			}(this))).join(", ") + " ]";
		default:
			return this.valToString(c.type,v,esc);
		}
	}
	,valToString: function(t,val,esc) {
		if(esc == null) esc = false;
		if(val == null) return "null";
		switch(t[1]) {
		case 3:case 4:case 2:case 7:
			return Std.string(val);
		case 0:case 6:case 12:
			if(esc) return "\"" + Std.string(val) + "\""; else return val;
			break;
		case 1:
			var val1 = val;
			if(new EReg("^[A-Za-z0-9_]+$","g").match(val1) && !esc) return val1; else return "\"" + val1.split("\\").join("\\\\").split("\"").join("\\\"") + "\"";
			break;
		case 5:
			var values = t[2];
			return this.valToString(cdb.ColumnType.TString,values[val],esc);
		case 8:
			return "????";
		case 9:
			var t1 = t[2];
			return this.typeValToString(this.tmap.get(t1),val,esc);
		case 10:
			var values1 = t[2];
			var v = val;
			var flags = [];
			var _g1 = 0;
			var _g = values1.length;
			while(_g1 < _g) {
				var i = _g1++;
				if((v & 1 << i) != 0) flags.push(this.valToString(cdb.ColumnType.TString,values1[i],esc));
			}
			return Std.string(flags);
		case 11:
			var s = "#" + StringTools.hex(val,6);
			if(esc) return "\"" + s + "\""; else return s;
			break;
		}
	}
	,typeValToString: function(t,val,esc) {
		if(esc == null) esc = false;
		var c = t.cases[val[0]];
		var str = c.name;
		if(c.args.length > 0) {
			str += "(";
			var out = [];
			var _g1 = 1;
			var _g = val.length;
			while(_g1 < _g) {
				var i = _g1++;
				out.push(this.valToString(c.args[i - 1].type,val[i],esc));
			}
			str += out.join(",");
			str += ")";
		}
		return str;
	}
	,typeStr: function(t) {
		switch(t[1]) {
		case 6:
			var n = t[2];
			return n;
		case 9:
			var n = t[2];
			return n;
		default:
			var _this = Std.string(t);
			return HxOverrides.substr(_this,1,null);
		}
	}
	,parseVal: function(t,val) {
		switch(t[1]) {
		case 3:
			if(new EReg("^-?[0-9]+$","").match(val)) return Std.parseInt(val);
			break;
		case 1:
			if(HxOverrides.cca(val,0) == 34) {
				var esc = false;
				var p = 0;
				try {
					while(true) {
						if(p == val.length) throw "Unclosed \"";
						var c;
						var index = p++;
						c = HxOverrides.cca(val,index);
						if(esc) esc = false; else if(c != null) switch(c) {
						case 34:
							if(p < val.length) throw "Invalid content after string '" + val + "'";
							throw "__break__";
							break;
						case 47:
							esc = true;
							break;
						}
					}
				} catch( e ) { if( e != "__break__" ) throw e; }
			} else if(new EReg("^[A-Za-z0-9_]+$","").match(val)) return val;
			throw "String requires quotes '" + val + "'";
			break;
		case 2:
			if(val == "true") return true;
			if(val == "false") return false;
			break;
		case 4:
			var f = Std.parseFloat(val);
			if(!isNaN(f)) return f;
			break;
		case 9:
			var t1 = t[2];
			return this.parseTypeVal(this.tmap.get(t1),val);
		case 6:
			var t2 = t[2];
			var r = this.smap.get(t2).index.get(val);
			if(r == null) throw val + " is not a known " + t2 + " id";
			return r.id;
		case 11:
			if(val.charAt(0) == "#") val = "0x" + HxOverrides.substr(val,1,null);
			if(new EReg("^-?[0-9]+$","").match(val) || new EReg("^0x[0-9A-Fa-f]+$","").match(val)) return Std.parseInt(val);
			break;
		default:
		}
		throw "'" + val + "' should be " + this.typeStr(t);
	}
	,parseTypeVal: function(t,val) {
		if(t == null || val == null) throw "Missing val/type";
		val = StringTools.trim(val);
		var missingCloseParent = false;
		var pos = val.indexOf("(");
		var id;
		var args = null;
		if(pos < 0) {
			id = val;
			args = [];
		} else {
			id = HxOverrides.substr(val,0,pos);
			val = HxOverrides.substr(val,pos + 1,null);
			if(StringTools.endsWith(val,")")) val = HxOverrides.substr(val,0,val.length - 1); else missingCloseParent = true;
			args = [];
			var p = 0;
			var start = 0;
			var pc = 0;
			while(p < val.length) {
				var _g;
				var index = p++;
				_g = HxOverrides.cca(val,index);
				if(_g != null) switch(_g) {
				case 40:
					pc++;
					break;
				case 41:
					if(pc == 0) throw "Extra )";
					pc--;
					break;
				case 34:
					var esc = false;
					try {
						while(true) {
							if(p == val.length) throw "Unclosed \"";
							var c;
							var index1 = p++;
							c = HxOverrides.cca(val,index1);
							if(esc) esc = false; else if(c != null) switch(c) {
							case 34:
								throw "__break__";
								break;
							case 47:
								esc = true;
								break;
							}
						}
					} catch( e ) { if( e != "__break__" ) throw e; }
					break;
				case 44:
					if(pc == 0) {
						args.push(HxOverrides.substr(val,start,p - start - 1));
						start = p;
					}
					break;
				default:
				} else {
				}
			}
			if(pc > 0) missingCloseParent = true;
			if(p > start || start > 0 && p == start) args.push(HxOverrides.substr(val,start,p - start));
		}
		var _g1 = 0;
		var _g2 = t.cases.length;
		while(_g1 < _g2) {
			var i = _g1++;
			var c1 = t.cases[i];
			if(c1.name == id) {
				var vals = [i];
				var _g21 = 0;
				var _g3 = c1.args;
				while(_g21 < _g3.length) {
					var a = _g3[_g21];
					++_g21;
					var v = args.shift();
					if(v == null) {
						if(a.opt) vals.push(null); else throw "Missing argument " + a.name + " : " + this.typeStr(a.type);
					} else {
						v = StringTools.trim(v);
						if(a.opt && v == "null") {
							vals.push(null);
							continue;
						}
						var val1;
						try {
							val1 = this.parseVal(a.type,v);
						} catch( e ) {
							if( js.Boot.__instanceof(e,String) ) {
								throw e + " for " + a.name;
							} else throw(e);
						}
						vals.push(val1);
					}
				}
				if(args.length > 0) throw "Extra argument '" + args.shift() + "'";
				if(missingCloseParent) throw "Missing )";
				while(vals[vals.length - 1] == null) vals.pop();
				return vals;
			}
		}
		throw "Unkown value '" + id + "'";
		return null;
	}
	,parseType: function(tstr) {
		switch(tstr) {
		case "Int":
			return cdb.ColumnType.TInt;
		case "Float":
			return cdb.ColumnType.TFloat;
		case "Bool":
			return cdb.ColumnType.TBool;
		case "String":
			return cdb.ColumnType.TString;
		default:
			if(this.tmap.exists(tstr)) return cdb.ColumnType.TCustom(tstr); else if(this.smap.exists(tstr)) return cdb.ColumnType.TRef(tstr); else {
				if(StringTools.endsWith(tstr,">")) {
					var tname = tstr.split("<").shift();
					var tparam;
					var _this = HxOverrides.substr(tstr,tname.length + 1,null);
					tparam = HxOverrides.substr(_this,0,-1);
				}
				throw "Unknown type " + tstr;
			}
		}
	}
	,typeCasesToString: function(t,prefix) {
		if(prefix == null) prefix = "";
		var arr = [];
		var _g = 0;
		var _g1 = t.cases;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			var str = c.name;
			if(c.args.length > 0) {
				str += "( ";
				var out = [];
				var _g2 = 0;
				var _g3 = c.args;
				while(_g2 < _g3.length) {
					var a = _g3[_g2];
					++_g2;
					var k = "";
					if(a.opt) k += "?";
					k += a.name + " : " + this.typeStr(a.type);
					out.push(k);
				}
				str += out.join(", ");
				str += " )";
			}
			str += ";";
			arr.push(prefix + str);
		}
		return arr.join("\n");
	}
	,parseTypeCases: function(def) {
		var cases = [];
		var cmap = new haxe.ds.StringMap();
		var _g = 0;
		var _g1 = new EReg("[\n;]","g").split(def);
		while(_g < _g1.length) {
			var line = _g1[_g];
			++_g;
			var line1 = StringTools.trim(line);
			if(line1 == "") continue;
			if(HxOverrides.cca(line1,line1.length - 1) == 59) line1 = HxOverrides.substr(line1,1,null);
			var pos = line1.indexOf("(");
			var name = null;
			var args = [];
			if(pos < 0) name = line1; else {
				name = HxOverrides.substr(line1,0,pos);
				line1 = HxOverrides.substr(line1,pos + 1,null);
				if(HxOverrides.cca(line1,line1.length - 1) != 41) throw "Missing closing parent in " + line1;
				line1 = HxOverrides.substr(line1,0,line1.length - 1);
				var _g2 = 0;
				var _g3 = line1.split(",");
				while(_g2 < _g3.length) {
					var arg = _g3[_g2];
					++_g2;
					var tname = arg.split(":");
					if(tname.length != 2) throw "Required name:type in '" + arg + "'";
					var opt = false;
					var id = StringTools.trim(tname[0]);
					if(id.charAt(0) == "?") {
						opt = true;
						id = StringTools.trim(HxOverrides.substr(id,1,null));
					}
					var t = StringTools.trim(tname[1]);
					if(!this.r_ident.match(id)) throw "Invalid identifier " + id;
					var c = { name : id, type : this.parseType(t), typeStr : null};
					if(opt) c.opt = true;
					args.push(c);
				}
			}
			if(!this.r_ident.match(name)) throw "Invalid identifier " + line1;
			if(cmap.exists(name)) throw "Duplicate identifier " + name;
			cmap.set(name,true);
			cases.push({ name : name, args : args});
		}
		return cases;
	}
	,makePairs: function(oldA,newA) {
		var pairs = [];
		var oldL = Lambda.list(oldA);
		var newL = Lambda.list(newA);
		var _g = 0;
		while(_g < oldA.length) {
			var a = oldA[_g];
			++_g;
			var $it0 = newL.iterator();
			while( $it0.hasNext() ) {
				var b = $it0.next();
				if(a.name == b.name) {
					pairs.push({ a : a, b : b});
					oldL.remove(a);
					newL.remove(b);
					break;
				}
			}
		}
		var $it1 = oldL.iterator();
		while( $it1.hasNext() ) {
			var a1 = $it1.next();
			var $it2 = newL.iterator();
			while( $it2.hasNext() ) {
				var b1 = $it2.next();
				if(Lambda.indexOf(oldA,a1) == Lambda.indexOf(newA,b1)) {
					pairs.push({ a : a1, b : b1});
					oldL.remove(a1);
					newL.remove(b1);
					break;
				}
			}
		}
		var $it3 = oldL.iterator();
		while( $it3.hasNext() ) {
			var a2 = $it3.next();
			pairs.push({ a : a2, b : null});
		}
		return pairs;
	}
	,mapType: function(callb) {
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			var _g2 = 0;
			var _g3 = s.columns;
			while(_g2 < _g3.length) {
				var c = _g3[_g2];
				++_g2;
				var t = callb(c.type);
				if(t != c.type) {
					c.type = t;
					c.typeStr = null;
				}
			}
		}
		var _g4 = 0;
		var _g11 = this.data.customTypes;
		while(_g4 < _g11.length) {
			var t1 = _g11[_g4];
			++_g4;
			var _g21 = 0;
			var _g31 = t1.cases;
			while(_g21 < _g31.length) {
				var c1 = _g31[_g21];
				++_g21;
				var _g41 = 0;
				var _g5 = c1.args;
				while(_g41 < _g5.length) {
					var a = _g5[_g41];
					++_g41;
					var t2 = callb(a.type);
					if(t2 != a.type) {
						a.type = t2;
						a.typeStr = null;
					}
				}
			}
		}
	}
	,changeLineOrder: function(sheet,remap) {
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			var _g2 = 0;
			var _g3 = s.columns;
			while(_g2 < _g3.length) {
				var c = _g3[_g2];
				++_g2;
				{
					var _g4 = c.type;
					switch(_g4[1]) {
					case 12:
						var t = _g4[2];
						if(t == sheet.name) {
							var _g5 = 0;
							var _g6 = this.getSheetLines(s);
							while(_g5 < _g6.length) {
								var obj = _g6[_g5];
								++_g5;
								var ldat = Reflect.field(obj,c.name);
								if(ldat == null || ldat == "") continue;
								var d = haxe.crypto.Base64.decode(ldat);
								var _g8 = 0;
								var _g7 = d.length;
								while(_g8 < _g7) {
									var i = _g8++;
									var r = remap[d.b[i]];
									if(r < 0) r = 0;
									d.b[i] = r;
								}
								ldat = haxe.crypto.Base64.encode(d);
								obj[c.name] = ldat;
							}
						} else {
						}
						break;
					default:
					}
				}
			}
		}
	}
	,updateRefs: function(sheet,refMap) {
		var _g3 = this;
		var convertTypeRec;
		var convertTypeRec1 = null;
		convertTypeRec1 = function(t,o) {
			var c = t.cases[o[0]];
			var _g1 = 0;
			var _g = o.length - 1;
			while(_g1 < _g) {
				var i = _g1++;
				var v = o[i + 1];
				if(v == null) continue;
				{
					var _g2 = c.args[i].type;
					switch(_g2[1]) {
					case 6:
						var n = _g2[2];
						if(n == sheet.name) {
							var v1;
							var key = v;
							v1 = refMap.get(key);
							if(v1 == null) continue;
							o[i + 1] = v1;
						} else {
						}
						break;
					case 9:
						var name = _g2[2];
						convertTypeRec1(_g3.tmap.get(name),v);
						break;
					default:
					}
				}
			}
		};
		convertTypeRec = convertTypeRec1;
		var _g4 = 0;
		var _g11 = this.data.sheets;
		while(_g4 < _g11.length) {
			var s = _g11[_g4];
			++_g4;
			var _g21 = 0;
			var _g31 = s.columns;
			while(_g21 < _g31.length) {
				var c1 = _g31[_g21];
				++_g21;
				{
					var _g41 = c1.type;
					switch(_g41[1]) {
					case 6:
						var n1 = _g41[2];
						if(n1 == sheet.name) {
							var _g5 = 0;
							var _g6 = this.getSheetLines(s);
							while(_g5 < _g6.length) {
								var obj = _g6[_g5];
								++_g5;
								var id = Reflect.field(obj,c1.name);
								if(id == null) continue;
								id = refMap.get(id);
								if(id == null) continue;
								obj[c1.name] = id;
							}
						} else {
						}
						break;
					case 9:
						var t1 = _g41[2];
						var _g51 = 0;
						var _g61 = this.getSheetLines(s);
						while(_g51 < _g61.length) {
							var obj1 = _g61[_g51];
							++_g51;
							var o1 = Reflect.field(obj1,c1.name);
							if(o1 == null) continue;
							convertTypeRec(this.tmap.get(t1),o1);
						}
						break;
					default:
					}
				}
			}
		}
	}
	,updateType: function(old,t) {
		var _g2 = this;
		var casesPairs = this.makePairs(old.cases,t.cases);
		var convMap = [];
		var _g = 0;
		while(_g < casesPairs.length) {
			var p = casesPairs[_g];
			++_g;
			if(p.b == null) continue;
			var id = Lambda.indexOf(t.cases,p.b);
			var conv = { def : [id], args : []};
			var args = this.makePairs(p.a.args,p.b.args);
			var _g1 = 0;
			while(_g1 < args.length) {
				var a = args[_g1];
				++_g1;
				if(a.b == null) {
					conv.args[Lambda.indexOf(p.a.args,a.a)] = (function() {
						return function(_) {
							return null;
						};
					})();
					continue;
				}
				var b = [a.b];
				var a1 = a.a;
				var c = this.getConvFunction(a1.type,b[0].type);
				if(c == null) throw "Cannot convert " + p.a.name + "." + a1.name + ":" + this.typeStr(a1.type) + " to " + p.b.name + "." + b[0].name + ":" + this.typeStr(b[0].type);
				var f = [c.f];
				if(f[0] == null) f[0] = (function() {
					return function(x) {
						return x;
					};
				})();
				if(a1.opt != b[0].opt) {
					var oldf = [f[0]];
					if(a1.opt) f[0] = (function(oldf,b) {
						return function(v) {
							v = oldf[0](v);
							if(v == null) return _g2.getDefault(b[0]); else return v;
						};
					})(oldf,b); else {
						var def = [this.getDefault(a1)];
						f[0] = (function(def,oldf) {
							return function(v1) {
								if(v1 == def[0]) return null; else return oldf[0](v1);
							};
						})(def,oldf);
					}
				}
				var index = [Lambda.indexOf(p.b.args,b[0])];
				conv.args[Lambda.indexOf(p.a.args,a1)] = (function(index,f,b) {
					return function(v2) {
						v2 = f[0](v2);
						if(v2 == null && b[0].opt) return null; else return { index : index[0], v : v2};
					};
				})(index,f,b);
			}
			var _g11 = 0;
			var _g21 = p.b.args;
			while(_g11 < _g21.length) {
				var b1 = _g21[_g11];
				++_g11;
				conv.def.push(this.getDefault(b1));
			}
			while(conv.def[conv.def.length - 1] == null) conv.def.pop();
			convMap[Lambda.indexOf(old.cases,p.a)] = conv;
		}
		var convertTypeRec;
		var convertTypeRec1 = null;
		convertTypeRec1 = function(t1,v3) {
			if(t1 == null) return null;
			if(t1 == old) {
				var conv1 = convMap[v3[0]];
				if(conv1 == null) return null;
				var out = conv1.def.slice();
				var _g12 = 0;
				var _g3 = conv1.args.length;
				while(_g12 < _g3) {
					var i = _g12++;
					var v4 = conv1.args[i](v3[i + 1]);
					if(v4 == null) continue;
					out[v4.index + 1] = v4.v;
				}
				return out;
			}
			var c1 = t1.cases[v3[0]];
			var _g13 = 0;
			var _g4 = c1.args.length;
			while(_g13 < _g4) {
				var i1 = _g13++;
				{
					var _g22 = c1.args[i1].type;
					switch(_g22[1]) {
					case 9:
						var tname = _g22[2];
						var av = v3[i1 + 1];
						if(av != null) v3[i1 + 1] = convertTypeRec1(_g2.tmap.get(tname),av);
						break;
					default:
					}
				}
			}
			return v3;
		};
		convertTypeRec = convertTypeRec1;
		var _g5 = 0;
		var _g14 = this.data.sheets;
		while(_g5 < _g14.length) {
			var s = _g14[_g5];
			++_g5;
			var _g23 = 0;
			var _g31 = s.columns;
			while(_g23 < _g31.length) {
				var c2 = _g31[_g23];
				++_g23;
				{
					var _g41 = c2.type;
					switch(_g41[1]) {
					case 9:
						var tname1 = _g41[2];
						var t2 = this.tmap.get(tname1);
						var _g51 = 0;
						var _g6 = this.getSheetLines(s);
						while(_g51 < _g6.length) {
							var obj = _g6[_g51];
							++_g51;
							var v5 = Reflect.field(obj,c2.name);
							if(v5 != null) {
								v5 = convertTypeRec(t2,v5);
								if(v5 == null) Reflect.deleteField(obj,c2.name); else obj[c2.name] = v5;
							}
						}
						if(tname1 == old.name && t.name != old.name) {
							c2.type = cdb.ColumnType.TCustom(t.name);
							c2.typeStr = null;
						}
						break;
					default:
					}
				}
			}
		}
		if(t.name != old.name) {
			var _g7 = 0;
			var _g15 = this.data.customTypes;
			while(_g7 < _g15.length) {
				var t21 = _g15[_g7];
				++_g7;
				var _g24 = 0;
				var _g32 = t21.cases;
				while(_g24 < _g32.length) {
					var c3 = _g32[_g24];
					++_g24;
					var _g42 = 0;
					var _g52 = c3.args;
					while(_g42 < _g52.length) {
						var a2 = _g52[_g42];
						++_g42;
						{
							var _g61 = a2.type;
							switch(_g61[1]) {
							case 9:
								var n = _g61[2];
								if(n == old.name) {
									a2.type = cdb.ColumnType.TCustom(t.name);
									a2.typeStr = null;
								} else {
								}
								break;
							default:
							}
						}
					}
				}
			}
			this.tmap.remove(old.name);
			old.name = t.name;
			this.tmap.set(old.name,old);
		}
		old.cases = t.cases;
	}
	,__class__: Model
};
var Main = function() {
	Model.call(this);
	this.window = nodejs.webkit.Window.get();
	this.initMenu();
	this.mousePos = { x : 0, y : 0};
	this.sheetCursors = new haxe.ds.StringMap();
	this.window.window.addEventListener("keydown",$bind(this,this.onKey));
	this.window.window.addEventListener("keypress",$bind(this,this.onKeyPress));
	this.window.window.addEventListener("mousemove",$bind(this,this.onMouseMove));
	new js.JQuery(".modal").keypress(function(e) {
		e.stopPropagation();
	}).keydown(function(e1) {
		e1.stopPropagation();
	});
	this.cursor = { s : null, x : 0, y : 0};
	this.load(true);
	var t = new haxe.Timer(1000);
	t.run = $bind(this,this.checkTime);
};
$hxClasses["Main"] = Main;
Main.__name__ = ["Main"];
Main.main = function() {
	var m = new Main();
	Reflect.setField(window,"_",m);
};
Main.__super__ = Model;
Main.prototype = $extend(Model.prototype,{
	onMouseMove: function(e) {
		this.mousePos.x = e.clientX;
		this.mousePos.y = e.clientY;
	}
	,setClipBoard: function(schema,data) {
		this.clipboard = { text : Std.string((function($this) {
			var $r;
			var _g = [];
			{
				var _g1 = 0;
				while(_g1 < data.length) {
					var o = data[_g1];
					++_g1;
					_g.push($this.objToString($this.cursor.s,o,true));
				}
			}
			$r = _g;
			return $r;
		}(this))), data : data, schema : schema};
		nodejs.webkit.Clipboard.get().set(this.clipboard.text,"text");
	}
	,moveCursor: function(dx,dy,shift,ctrl) {
		if(this.cursor.s == null) return;
		if(this.cursor.x == -1 && ctrl) {
			if(dy != 0) this.moveLine(this.cursor.s,this.cursor.y,dy);
			this.updateCursor();
			return;
		}
		if(dx < 0 && this.cursor.x >= 0) this.cursor.x--;
		if(dy < 0 && this.cursor.y > 0) this.cursor.y--;
		if(dx > 0 && this.cursor.x < this.cursor.s.columns.length - 1) this.cursor.x++;
		if(dy > 0 && this.cursor.y < this.cursor.s.lines.length - 1) this.cursor.y++;
		this.cursor.select = null;
		this.updateCursor();
	}
	,onKeyPress: function(e) {
		if(!e.ctrlKey) new js.JQuery(".cursor").not(".edit").dblclick();
	}
	,getSelection: function() {
		if(this.cursor.s == null) return null;
		var x1;
		if(this.cursor.x < 0) x1 = 0; else x1 = this.cursor.x;
		var x2;
		if(this.cursor.x < 0) x2 = this.cursor.s.columns.length - 1; else if(this.cursor.select != null) x2 = this.cursor.select.x; else x2 = x1;
		var y1 = this.cursor.y;
		var y2;
		if(this.cursor.select != null) y2 = this.cursor.select.y; else y2 = y1;
		if(x2 < x1) {
			var tmp = x2;
			x2 = x1;
			x1 = tmp;
		}
		if(y2 < y1) {
			var tmp1 = y2;
			y2 = y1;
			y1 = tmp1;
		}
		return { x1 : x1, x2 : x2, y1 : y1, y2 : y2};
	}
	,onKey: function(e) {
		var _g = e.keyCode;
		switch(_g) {
		case 45:
			if(this.cursor.s != null) this.newLine(this.cursor.s,this.cursor.y);
			break;
		case 46:
			if(this.level == null) {
				new js.JQuery(".selected.deletable").change();
				if(this.cursor.s != null) {
					if(this.cursor.x < 0) {
						var s = this.getSelection();
						var y = s.y2;
						while(y >= s.y1) {
							this.deleteLine(this.cursor.s,y);
							y--;
						}
						this.cursor.y = s.y1;
						this.cursor.select = null;
					} else {
						var s1 = this.getSelection();
						var _g2 = s1.y1;
						var _g1 = s1.y2 + 1;
						while(_g2 < _g1) {
							var y1 = _g2++;
							var obj = this.cursor.s.lines[y1];
							var _g4 = s1.x1;
							var _g3 = s1.x2 + 1;
							while(_g4 < _g3) {
								var x = _g4++;
								var c = this.cursor.s.columns[x];
								var def = this.getDefault(c);
								if(def == null) Reflect.deleteField(obj,c.name); else obj[c.name] = def;
							}
						}
					}
				}
				this.refresh();
				this.save();
			} else {
			}
			break;
		case 38:
			this.moveCursor(0,-1,e.shiftKey,e.ctrlKey);
			e.preventDefault();
			break;
		case 40:
			this.moveCursor(0,1,e.shiftKey,e.ctrlKey);
			e.preventDefault();
			break;
		case 37:
			this.moveCursor(-1,0,e.shiftKey,e.ctrlKey);
			break;
		case 39:
			this.moveCursor(1,0,e.shiftKey,e.ctrlKey);
			break;
		case 90:
			if(e.ctrlKey) {
				if(this.history.length > 0) {
					this.redo.push(this.curSavedData);
					this.curSavedData = this.history.pop();
					this.quickLoad(this.curSavedData);
					this.initContent();
					this.save(false);
				}
			} else {
			}
			break;
		case 89:
			if(e.ctrlKey) {
				if(this.redo.length > 0) {
					this.history.push(this.curSavedData);
					this.curSavedData = this.redo.pop();
					this.quickLoad(this.curSavedData);
					this.initContent();
					this.save(false);
				}
			} else {
			}
			break;
		case 67:
			if(e.ctrlKey) {
				if(this.cursor.s != null) {
					var s2 = this.getSelection();
					var data = [];
					var _g21 = s2.y1;
					var _g11 = s2.y2 + 1;
					while(_g21 < _g11) {
						var y2 = _g21++;
						var obj1 = this.cursor.s.lines[y2];
						var out = { };
						var _g41 = s2.x1;
						var _g31 = s2.x2 + 1;
						while(_g41 < _g31) {
							var x1 = _g41++;
							var c1 = this.cursor.s.columns[x1];
							var v = Reflect.field(obj1,c1.name);
							if(v != null) out[c1.name] = v;
						}
						data.push(out);
					}
					this.setClipBoard((function($this) {
						var $r;
						var _g12 = [];
						{
							var _g32 = s2.x1;
							var _g22 = s2.x2 + 1;
							while(_g32 < _g22) {
								var x2 = _g32++;
								_g12.push($this.cursor.s.columns[x2]);
							}
						}
						$r = _g12;
						return $r;
					}(this)),data);
				}
			} else {
			}
			break;
		case 88:
			if(e.ctrlKey) {
				this.onKey({ keyCode : 67, ctrlKey : true});
				this.onKey({ keyCode : 46});
			} else {
			}
			break;
		case 86:
			if(e.ctrlKey) {
				if(this.cursor.s == null || this.clipboard == null || nodejs.webkit.Clipboard.get().get("text") != this.clipboard.text) return;
				var sheet = this.cursor.s;
				var posX;
				if(this.cursor.x < 0) posX = 0; else posX = this.cursor.x;
				var posY = this.cursor.y;
				var _g13 = 0;
				var _g23 = this.clipboard.data;
				while(_g13 < _g23.length) {
					var obj11 = _g23[_g13];
					++_g13;
					if(posY == sheet.lines.length) Model.prototype.newLine.call(this,sheet);
					var obj2 = sheet.lines[posY];
					var _g42 = 0;
					var _g33 = this.clipboard.schema.length;
					while(_g42 < _g33) {
						var cid = _g42++;
						var c11 = this.clipboard.schema[cid];
						var c2 = sheet.columns[cid + posX];
						if(c2 == null) continue;
						var f = this.getConvFunction(c11.type,c2.type);
						var v1 = Reflect.field(obj11,c11.name);
						if(f == null) v1 = this.getDefault(c2); else if(f.f != null) v1 = f.f(v1);
						if(v1 == null && !c2.opt) v1 = this.getDefault(c2);
						if(v1 == null) Reflect.deleteField(obj2,c2.name); else obj2[c2.name] = v1;
					}
					posY++;
				}
				this.makeSheet(sheet);
				this.refresh();
				this.save();
			} else {
			}
			break;
		case 9:
			if(e.ctrlKey) {
				var sheets = this.data.sheets.filter(function(s3) {
					return !s3.props.hide;
				});
				var s4 = sheets[(Lambda.indexOf(sheets,this.viewSheet) + 1) % sheets.length];
				if(s4 != null) this.selectSheet(s4);
			} else this.moveCursor(e.shiftKey?-1:1,0,false,false);
			break;
		case 27:
			if(this.cursor.s != null && this.cursor.s.parent != null) {
				var p = this.cursor.s.parent;
				this.setCursor(p.sheet,p.column,p.line);
				new js.JQuery(".cursor").click();
			} else if(this.cursor.select != null) {
				this.cursor.select = null;
				this.updateCursor();
			}
			break;
		case 113:
			new js.JQuery(".cursor").not(".edit").dblclick();
			break;
		case 114:
			if(this.cursor.s != null) this.showReferences(this.cursor.s,this.cursor.y);
			break;
		case 115:
			if(this.cursor.s != null && this.cursor.x >= 0) {
				var c3 = this.cursor.s.columns[this.cursor.x];
				var id = Reflect.field(this.cursor.s.lines[this.cursor.y],c3.name);
				{
					var _g14 = c3.type;
					switch(_g14[1]) {
					case 6:
						var s5 = _g14[2];
						var sd = this.smap.get(s5);
						if(sd != null) {
							var k = sd.index.get(id);
							if(k != null) {
								var index = Lambda.indexOf(sd.s.lines,k.obj);
								if(index >= 0) {
									this.sheetCursors.set(s5,{ s : sd.s, x : 0, y : index});
									this.selectSheet(sd.s);
								}
							}
						}
						break;
					default:
					}
				}
			}
			break;
		default:
		}
		if(this.level != null) this.level.onKey(e);
	}
	,getLine: function(sheet,index) {
		return ((function($this) {
			var $r;
			var html = "table[sheet='" + $this.getPath(sheet) + "'] > tbody > tr";
			$r = new js.JQuery(html);
			return $r;
		}(this))).not(".head,.separator,.list").eq(index);
	}
	,showReferences: function(sheet,index) {
		var _g3 = this;
		var id = null;
		var _g = 0;
		var _g1 = sheet.columns;
		try {
			while(_g < _g1.length) {
				var c = _g1[_g];
				++_g;
				var _g2 = c.type;
				switch(_g2[1]) {
				case 0:
					id = Reflect.field(sheet.lines[index],c.name);
					throw "__break__";
					break;
				default:
				}
			}
		} catch( e ) { if( e != "__break__" ) throw e; }
		if(id == "" || id == null) return;
		var results = [];
		var _g4 = 0;
		var _g11 = this.data.sheets;
		while(_g4 < _g11.length) {
			var s = _g11[_g4];
			++_g4;
			var _g21 = 0;
			var _g31 = s.columns;
			while(_g21 < _g31.length) {
				var c1 = _g31[_g21];
				++_g21;
				{
					var _g41 = c1.type;
					switch(_g41[1]) {
					case 6:
						var sname = _g41[2];
						if(sname == sheet.name) {
							var sheets = [];
							var p = { s : s, c : c1.name, id : null};
							while(true) {
								var _g5 = 0;
								var _g6 = p.s.columns;
								try {
									while(_g5 < _g6.length) {
										var c2 = _g6[_g5];
										++_g5;
										var _g7 = c2.type;
										switch(_g7[1]) {
										case 0:
											p.id = c2.name;
											throw "__break__";
											break;
										default:
										}
									}
								} catch( e ) { if( e != "__break__" ) throw e; }
								sheets.unshift(p);
								var p2 = this.getParentSheet(p.s);
								if(p2 == null) break;
								p = { s : p2.s, c : p2.c, id : null};
							}
							var _g51 = 0;
							var _g61 = this.getSheetObjects(s);
							while(_g51 < _g61.length) {
								var o = _g61[_g51];
								++_g51;
								var obj = o.path[o.path.length - 1];
								if(Reflect.field(obj,c1.name) == id) results.push({ s : sheets, o : o});
							}
						} else {
						}
						break;
					case 9:
						var tname = _g41[2];
						break;
					default:
					}
				}
			}
		}
		if(results.length == 0) {
			this.setErrorMessage(id + " not found");
			haxe.Timer.delay((function(f) {
				return function() {
					return f();
				};
			})($bind(this,this.setErrorMessage)),500);
			return;
		}
		var line = this.getLine(sheet,index);
		line.next("tr.list").change();
		var res = new js.JQuery("<tr>").addClass("list");
		new js.JQuery("<td>").appendTo(res);
		var cell = new js.JQuery("<td>").attr("colspan","" + sheet.columns.length).appendTo(res);
		var div = new js.JQuery("<div>").appendTo(cell);
		div.hide();
		var content = new js.JQuery("<table>").appendTo(div);
		var cols = new js.JQuery("<tr>").addClass("head");
		new js.JQuery("<td>").addClass("start").appendTo(cols).click(function(_) {
			res.change();
		});
		var _g8 = 0;
		var _g12 = ["path","id"];
		while(_g8 < _g12.length) {
			var name = _g12[_g8];
			++_g8;
			new js.JQuery("<td>").text(name).appendTo(cols);
		}
		content.append(cols);
		var index1 = 0;
		var _g9 = 0;
		while(_g9 < results.length) {
			var rs = [results[_g9]];
			++_g9;
			var l = new js.JQuery("<tr>").appendTo(content).addClass("clickable");
			new js.JQuery("<td>").text("" + index1++).appendTo(l);
			var slast = [rs[0].s[rs[0].s.length - 1]];
			new js.JQuery("<td>").text(slast[0].s.name.split("@").join(".") + "." + slast[0].c).appendTo(l);
			var path = [];
			var _g22 = 0;
			var _g13 = rs[0].s.length;
			while(_g22 < _g13) {
				var i = _g22++;
				var s1 = rs[0].s[i];
				var oid = Reflect.field(rs[0].o.path[i],s1.id);
				if(oid == null || oid == "") path.push(s1.s.name.split("@").pop() + "[" + rs[0].o.indexes[i] + "]"); else path.push(oid);
			}
			new js.JQuery("<td>").text(path.join(".")).appendTo(l);
			l.click((function(slast,rs) {
				return function(e) {
					var key = null;
					var _g23 = 0;
					var _g14 = rs[0].s.length - 1;
					while(_g23 < _g14) {
						var i1 = _g23++;
						var p1 = rs[0].s[i1];
						key = _g3.getPath(p1.s) + "@" + p1.c + ":" + rs[0].o.indexes[i1];
						_g3.openedList.set(key,true);
					}
					var starget = rs[0].s[0].s;
					_g3.sheetCursors.set(starget.name,{ s : { name : slast[0].s.name, path : key, separators : [], lines : [], columns : [], props : { }}, x : -1, y : rs[0].o.indexes[rs[0].o.indexes.length - 1]});
					_g3.selectSheet(starget);
					e.stopPropagation();
				};
			})(slast,rs));
		}
		res.change(function(e1) {
			div.slideUp(100,function() {
				res.remove();
			});
			e1.stopPropagation();
		});
		res.insertAfter(line);
		div.slideDown(100);
	}
	,moveLine: function(sheet,index,delta) {
		this.getLine(sheet,index).next("tr.list").change();
		var index1 = Model.prototype.moveLine.call(this,sheet,index,delta);
		if(index1 != null) {
			this.setCursor(sheet,-1,index1,null,false);
			this.refresh();
			this.save();
		}
		return index1;
	}
	,changed: function(sheet,c,index) {
		this.save();
		var _g = c.type;
		switch(_g[1]) {
		case 0:
			this.makeSheet(sheet);
			break;
		case 7:
			this.saveImages();
			break;
		default:
			if(sheet.props.displayColumn == c.name) {
				var obj = sheet.lines[index];
				var s = this.smap.get(sheet.name);
				var _g1 = 0;
				var _g2 = sheet.columns;
				while(_g1 < _g2.length) {
					var cid = _g2[_g1];
					++_g1;
					if(cid.type == cdb.ColumnType.TId) {
						var id = Reflect.field(obj,cid.name);
						if(id != null) {
							var disp = Reflect.field(obj,c.name);
							if(disp == null) disp = "#" + id;
							s.index.get(id).disp = disp;
						}
					}
				}
			}
		}
	}
	,error: function(msg) {
		js.Lib.alert(msg);
	}
	,setErrorMessage: function(msg) {
		if(msg == null) new js.JQuery(".errorMsg").hide(); else new js.JQuery(".errorMsg").text(msg).show();
	}
	,valueHtml: function(c,v,sheet,obj) {
		if(v == null) {
			if(c.opt) return "&nbsp;";
			return "<span class=\"error\">#NULL</span>";
		}
		{
			var _g = c.type;
			switch(_g[1]) {
			case 3:case 4:
				var _g1 = c.display;
				switch(_g1) {
				case 1:
					return Math.round(v * 10000) / 100 + "%";
				default:
					return Std.string(v) + "";
				}
				break;
			case 0:
				if(v == "") return "<span class=\"error\">#MISSING</span>"; else if(((function($this) {
					var $r;
					var key = v;
					$r = $this.smap.get(sheet.name).index.get(key);
					return $r;
				}(this))).obj == obj) return v; else return "<span class=\"error\">#DUP(" + Std.string(v) + ")</span>";
				break;
			case 1:
				if(v == "") return "&nbsp;"; else return StringTools.htmlEscape(v);
				break;
			case 6:
				var sname = _g[2];
				if(v == "") return "<span class=\"error\">#MISSING</span>"; else {
					var s = this.smap.get(sname);
					var i;
					var key1 = v;
					i = s.index.get(key1);
					if(i == null) return "<span class=\"error\">#REF(" + Std.string(v) + ")</span>"; else return StringTools.htmlEscape(i.disp);
				}
				break;
			case 2:
				if(v) return "Y"; else return "N";
				break;
			case 5:
				var values = _g[2];
				return values[v];
			case 7:
				if(v == "") return "<span class=\"error\">#MISSING</span>"; else {
					var data = Reflect.field(this.imageBank,v);
					if(data == null) return "<span class=\"error\">#NOTFOUND(" + Std.string(v) + ")</span>"; else return "<img src=\"" + data + "\"/>";
				}
				break;
			case 8:
				var a = v;
				var ps = this.smap.get(sheet.name + "@" + c.name).s;
				var out = [];
				var _g11 = 0;
				while(_g11 < a.length) {
					var v1 = a[_g11];
					++_g11;
					var vals = [];
					var _g2 = 0;
					var _g3 = ps.columns;
					while(_g2 < _g3.length) {
						var c1 = _g3[_g2];
						++_g2;
						var _g4 = c1.type;
						switch(_g4[1]) {
						case 8:
							continue;
							break;
						default:
							vals.push(this.valueHtml(c1,Reflect.field(v1,c1.name),ps,v1));
						}
					}
					out.push(vals.length == 1?vals[0]:vals);
				}
				return Std.string(out);
			case 9:
				var name = _g[2];
				var t = this.tmap.get(name);
				var a1 = v;
				var cas = t.cases[a1[0]];
				var str = cas.name;
				if(cas.args.length > 0) {
					str += "(";
					var out1 = [];
					var pos = 1;
					var _g21 = 1;
					var _g12 = a1.length;
					while(_g21 < _g12) {
						var i1 = _g21++;
						out1.push(this.valueHtml(cas.args[i1 - 1],a1[i1],sheet,this));
					}
					str += out1.join(",");
					str += ")";
				}
				return str;
			case 10:
				var values1 = _g[2];
				var v2 = v;
				var flags = [];
				var _g22 = 0;
				var _g13 = values1.length;
				while(_g22 < _g13) {
					var i2 = _g22++;
					if((v2 & 1 << i2) != 0) flags.push(StringTools.htmlEscape(values1[i2]));
				}
				if(flags.length == 0) return String.fromCharCode(8709); else return flags.join("|");
				break;
			case 11:
				var id = Main.UID++;
				return "<input type=\"text\" id=\"_c" + id + "\"/><script>$(\"#_c" + id + "\").spectrum({ color : \"#" + StringTools.hex(v,6) + "\", showInput: true, clickoutFiresChange : true, showButtons: false, change : function(e) { _.colorChangeEvent(e,$(this),\"" + c.name + "\"); } })</script>";
			case 12:
				return "";
			}
		}
	}
	,colorChangeEvent: function(value,comp,col) {
		var color = Std.parseInt("0x" + value.toHex());
		var line = comp.parent().parent();
		var idx = line.data("index");
		var sheet = this.getSheet(line.parent().parent().attr("sheet"));
		var obj = sheet.lines[idx];
		obj[col] = color;
		this.save();
	}
	,popupLine: function(sheet,index) {
		var _g = this;
		var n = new nodejs.webkit.Menu();
		var nup = new nodejs.webkit.MenuItem({ label : "Move Up"});
		var ndown = new nodejs.webkit.MenuItem({ label : "Move Down"});
		var nins = new nodejs.webkit.MenuItem({ label : "Insert"});
		var ndel = new nodejs.webkit.MenuItem({ label : "Delete"});
		var nsep = new nodejs.webkit.MenuItem({ label : "Separator", type : "checkbox"});
		var nref = new nodejs.webkit.MenuItem({ label : "Show References"});
		var _g1 = 0;
		var _g11 = [nup,ndown,nins,ndel,nsep,nref];
		while(_g1 < _g11.length) {
			var m = _g11[_g1];
			++_g1;
			n.append(m);
		}
		var sepIndex = Lambda.indexOf(sheet.separators,index);
		nsep.checked = sepIndex >= 0;
		nins.click = function() {
			_g.newLine(sheet,index);
		};
		nup.click = function() {
			_g.moveLine(sheet,index,-1);
		};
		ndown.click = function() {
			_g.moveLine(sheet,index,1);
		};
		ndel.click = function() {
			_g.deleteLine(sheet,index);
			_g.refresh();
			_g.save();
		};
		nsep.click = function() {
			if(sepIndex >= 0) {
				sheet.separators.splice(sepIndex,1);
				if(sheet.props.separatorTitles != null) sheet.props.separatorTitles.splice(sepIndex,1);
			} else {
				sepIndex = sheet.separators.length;
				var _g12 = 0;
				var _g2 = sheet.separators.length;
				while(_g12 < _g2) {
					var i = _g12++;
					if(sheet.separators[i] > index) {
						sepIndex = i;
						break;
					}
				}
				sheet.separators.splice(sepIndex,0,index);
				if(sheet.props.separatorTitles != null && sheet.props.separatorTitles.length > sepIndex) sheet.props.separatorTitles.splice(sepIndex,0,null);
			}
			_g.refresh();
			_g.save();
		};
		nref.click = function() {
			_g.showReferences(sheet,index);
		};
		if(sheet.props.hide) nsep.enabled = false;
		n.popup(this.mousePos.x,this.mousePos.y);
	}
	,popupColumn: function(sheet,c) {
		var _g4 = this;
		var n = new nodejs.webkit.Menu();
		var nedit = new nodejs.webkit.MenuItem({ label : "Edit"});
		var nins = new nodejs.webkit.MenuItem({ label : "Add Column"});
		var nleft = new nodejs.webkit.MenuItem({ label : "Move Left"});
		var nright = new nodejs.webkit.MenuItem({ label : "Move Right"});
		var ndel = new nodejs.webkit.MenuItem({ label : "Delete"});
		var ndisp = new nodejs.webkit.MenuItem({ label : "Display Column", type : "checkbox"});
		var _g = 0;
		var _g1 = [nedit,nins,nleft,nright,ndel,ndisp];
		while(_g < _g1.length) {
			var m = _g1[_g];
			++_g;
			n.append(m);
		}
		{
			var _g2 = c.type;
			switch(_g2[1]) {
			case 0:case 1:case 5:case 10:
				var conv = new nodejs.webkit.MenuItem({ label : "Convert"});
				var cm = new nodejs.webkit.Menu();
				var _g11 = 0;
				var _g21 = [{ n : "lowercase", f : function(s) {
					return s.toLowerCase();
				}},{ n : "UPPERCASE", f : function(s1) {
					return s1.toUpperCase();
				}},{ n : "UpperIdent", f : function(s2) {
					return HxOverrides.substr(s2,0,1).toUpperCase() + HxOverrides.substr(s2,1,null);
				}},{ n : "lowerIdent", f : function(s3) {
					return HxOverrides.substr(s3,0,1).toLowerCase() + HxOverrides.substr(s3,1,null);
				}}];
				while(_g11 < _g21.length) {
					var k = [_g21[_g11]];
					++_g11;
					var m1 = new nodejs.webkit.MenuItem({ label : k[0].n});
					m1.click = (function(k) {
						return function() {
							{
								var _g3 = c.type;
								switch(_g3[1]) {
								case 5:
									var values = _g3[2];
									var _g5 = 0;
									var _g41 = values.length;
									while(_g5 < _g41) {
										var i = _g5++;
										values[i] = k[0].f(values[i]);
									}
									break;
								case 10:
									var values = _g3[2];
									var _g5 = 0;
									var _g41 = values.length;
									while(_g5 < _g41) {
										var i = _g5++;
										values[i] = k[0].f(values[i]);
									}
									break;
								default:
									var refMap = new haxe.ds.StringMap();
									var _g51 = 0;
									var _g6 = _g4.getSheetLines(sheet);
									while(_g51 < _g6.length) {
										var obj = _g6[_g51];
										++_g51;
										var t = Reflect.field(obj,c.name);
										if(t != null && t != "") {
											var t2 = k[0].f(t);
											if(t2 == null && !c.opt) t2 = "";
											if(t2 == null) Reflect.deleteField(obj,c.name); else {
												obj[c.name] = t2;
												if(t2 != "") refMap.set(t,t2);
											}
										}
									}
									if(c.type == cdb.ColumnType.TId) _g4.updateRefs(sheet,refMap);
									_g4.makeSheet(sheet);
								}
							}
							_g4.refresh();
							_g4.save();
						};
					})(k);
					cm.append(m1);
				}
				conv.submenu = cm;
				n.append(conv);
				break;
			case 3:case 4:
				var conv1 = new nodejs.webkit.MenuItem({ label : "Convert"});
				var cm1 = new nodejs.webkit.Menu();
				var _g12 = 0;
				var _g22 = [{ n : "* 10", f : function(s4) {
					return s4 * 10;
				}},{ n : "/ 10", f : function(s5) {
					return s5 / 10;
				}},{ n : "+ 1", f : function(s6) {
					return s6 + 1;
				}},{ n : "- 1", f : function(s7) {
					return s7 - 1;
				}}];
				while(_g12 < _g22.length) {
					var k1 = [_g22[_g12]];
					++_g12;
					var m2 = new nodejs.webkit.MenuItem({ label : k1[0].n});
					m2.click = (function(k1) {
						return function() {
							var _g31 = 0;
							var _g52 = _g4.getSheetLines(sheet);
							while(_g31 < _g52.length) {
								var obj1 = _g52[_g31];
								++_g31;
								var t1 = Reflect.field(obj1,c.name);
								if(t1 != null) {
									var t21 = k1[0].f(t1);
									if(c.type == cdb.ColumnType.TInt) t21 = t21 | 0;
									obj1[c.name] = t21;
								}
							}
							_g4.refresh();
							_g4.save();
						};
					})(k1);
					cm1.append(m2);
				}
				conv1.submenu = cm1;
				n.append(conv1);
				break;
			default:
			}
		}
		ndisp.checked = sheet.props.displayColumn == c.name;
		nedit.click = function() {
			_g4.newColumn(sheet.name,c);
		};
		nleft.click = function() {
			var index = Lambda.indexOf(sheet.columns,c);
			if(index > 0) {
				HxOverrides.remove(sheet.columns,c);
				sheet.columns.splice(index - 1,0,c);
				_g4.refresh();
				_g4.save();
			}
		};
		nright.click = function() {
			var index1 = Lambda.indexOf(sheet.columns,c);
			if(index1 < sheet.columns.length - 1) {
				HxOverrides.remove(sheet.columns,c);
				sheet.columns.splice(index1 + 1,0,c);
				_g4.refresh();
				_g4.save();
			}
		};
		ndel.click = function() {
			_g4.deleteColumn(sheet,c.name);
		};
		ndisp.click = function() {
			if(sheet.props.displayColumn == c.name) sheet.props.displayColumn = null; else sheet.props.displayColumn = c.name;
			_g4.makeSheet(sheet);
			_g4.refresh();
			_g4.save();
		};
		nins.click = function() {
			_g4.newColumn(sheet.name,null,Lambda.indexOf(sheet.columns,c) + 1);
		};
		n.popup(this.mousePos.x,this.mousePos.y);
	}
	,popupSheet: function(s,li) {
		var _g = this;
		var n = new nodejs.webkit.Menu();
		var nins = new nodejs.webkit.MenuItem({ label : "Add Sheet"});
		var nleft = new nodejs.webkit.MenuItem({ label : "Move Left"});
		var nright = new nodejs.webkit.MenuItem({ label : "Move Right"});
		var nren = new nodejs.webkit.MenuItem({ label : "Rename"});
		var ndel = new nodejs.webkit.MenuItem({ label : "Delete"});
		var nindex = new nodejs.webkit.MenuItem({ label : "Add Index", type : "checkbox"});
		var ngroup = new nodejs.webkit.MenuItem({ label : "Add Group", type : "checkbox"});
		var _g1 = 0;
		var _g11 = [nins,nleft,nright,nren,ndel,nindex,ngroup];
		while(_g1 < _g11.length) {
			var m = _g11[_g1];
			++_g1;
			n.append(m);
		}
		nleft.click = function() {
			var index = Lambda.indexOf(_g.data.sheets,s);
			if(index > 0) {
				HxOverrides.remove(_g.data.sheets,s);
				_g.data.sheets.splice(index - 1,0,s);
				_g.prefs.curSheet = index - 1;
				_g.initContent();
				_g.save();
			}
		};
		nright.click = function() {
			var index1 = Lambda.indexOf(_g.data.sheets,s);
			if(index1 < _g.data.sheets.length - 1) {
				HxOverrides.remove(_g.data.sheets,s);
				_g.data.sheets.splice(index1 + 1,0,s);
				_g.prefs.curSheet = index1 + 1;
				_g.initContent();
				_g.save();
			}
		};
		ndel.click = function() {
			_g.deleteSheet(s);
			_g.initContent();
			_g.save();
		};
		nins.click = function() {
			_g.newSheet();
		};
		nindex.checked = s.props.hasIndex;
		nindex.click = function() {
			if(s.props.hasIndex) {
				var _g12 = 0;
				var _g2 = _g.getSheetLines(s);
				while(_g12 < _g2.length) {
					var o = _g2[_g12];
					++_g12;
					Reflect.deleteField(o,"index");
				}
				s.props.hasIndex = false;
			} else {
				var _g3 = 0;
				var _g13 = s.columns;
				while(_g3 < _g13.length) {
					var c = _g13[_g3];
					++_g3;
					if(c.name == "index") {
						_g.error("Column 'index' already exists");
						return;
					}
				}
				s.props.hasIndex = true;
			}
			_g.save();
		};
		ngroup.checked = s.props.hasGroup;
		ngroup.click = function() {
			if(s.props.hasGroup) {
				var _g14 = 0;
				var _g21 = _g.getSheetLines(s);
				while(_g14 < _g21.length) {
					var o1 = _g21[_g14];
					++_g14;
					Reflect.deleteField(o1,"group");
				}
				s.props.hasGroup = false;
			} else {
				var _g4 = 0;
				var _g15 = s.columns;
				while(_g4 < _g15.length) {
					var c1 = _g15[_g4];
					++_g4;
					if(c1.name == "group") {
						_g.error("Column 'group' already exists");
						return;
					}
				}
				s.props.hasGroup = true;
			}
			_g.save();
		};
		nren.click = function() {
			li.dblclick();
		};
		if(s.props.levelProps != null || this.hasColumn(s,"width",[cdb.ColumnType.TInt]) && this.hasColumn(s,"height",[cdb.ColumnType.TInt])) {
			var nlevel = new nodejs.webkit.MenuItem({ label : "Level", type : "checkbox"});
			nlevel.checked = s.props.levelProps != null;
			n.append(nlevel);
			nlevel.click = function() {
				if(s.props.levelProps != null) Reflect.deleteField(s.props,"levelProps"); else s.props.levelProps = { };
				_g.save();
				_g.refresh();
			};
		}
		n.popup(this.mousePos.x,this.mousePos.y);
	}
	,editCell: function(c,v,sheet,index) {
		var _g = this;
		var obj = sheet.lines[index];
		var val = Reflect.field(obj,c.name);
		var html = _g.valueHtml(c,val,sheet,obj);
		if(v.hasClass("edit")) return;
		var editDone = function() {
			v.html(html);
			v.removeClass("edit");
			_g.setErrorMessage();
		};
		{
			var _g1 = c.type;
			switch(_g1[1]) {
			case 3:case 4:case 1:case 0:case 9:
				v.empty();
				var i = new js.JQuery("<input>");
				v.addClass("edit");
				i.appendTo(v);
				if(val != null) {
					var _g11 = c.type;
					switch(_g11[1]) {
					case 9:
						var t = _g11[2];
						i.val(this.typeValToString(this.tmap.get(t),val));
						break;
					default:
						i.val("" + Std.string(val));
					}
				}
				i.change(function(e) {
					e.stopPropagation();
				});
				i.keydown(function(e1) {
					var _g12 = e1.keyCode;
					switch(_g12) {
					case 27:
						editDone();
						break;
					case 13:
						i.blur();
						e1.preventDefault();
						break;
					case 38:case 40:
						i.blur();
						return;
					case 9:
						i.blur();
						_g.moveCursor(e1.shiftKey?-1:1,0,false,false);
						haxe.Timer.delay(function() {
							new js.JQuery(".cursor").dblclick();
						},1);
						e1.preventDefault();
						break;
					default:
					}
					e1.stopPropagation();
				});
				i.blur(function(_) {
					var nv = i.val();
					if(nv == "" && c.opt) {
						if(val != null) {
							val = html = null;
							Reflect.deleteField(obj,c.name);
							_g.changed(sheet,c,index);
						}
					} else {
						var val2;
						{
							var _g13 = c.type;
							switch(_g13[1]) {
							case 3:
								val2 = Std.parseInt(nv);
								break;
							case 4:
								var f = Std.parseFloat(nv);
								if(isNaN(f)) val2 = null; else val2 = f;
								break;
							case 0:
								if(_g.r_ident.match(nv)) val2 = nv; else val2 = null;
								break;
							case 9:
								var t1 = _g13[2];
								try {
									val2 = _g.parseTypeVal(_g.tmap.get(t1),nv);
								} catch( e2 ) {
									val2 = null;
								}
								break;
							default:
								val2 = nv;
							}
						}
						if(val2 != val && val2 != null) {
							if(c.type == cdb.ColumnType.TId && val != null) {
								var m = new haxe.ds.StringMap();
								var key = val;
								var value = val2;
								m.set(key,value);
								_g.updateRefs(sheet,m);
							}
							val = val2;
							obj[c.name] = val;
							_g.changed(sheet,c,index);
							html = _g.valueHtml(c,val,sheet,obj);
						}
					}
					editDone();
				});
				{
					var _g14 = c.type;
					switch(_g14[1]) {
					case 9:
						var t2 = _g14[2];
						var t3 = this.tmap.get(t2);
						i.keyup(function(_1) {
							var str = i.val();
							try {
								if(str != "") _g.parseTypeVal(t3,str);
								_g.setErrorMessage();
								i.removeClass("error");
							} catch( msg ) {
								if( js.Boot.__instanceof(msg,String) ) {
									_g.setErrorMessage(msg);
									i.addClass("error");
								} else throw(msg);
							}
						});
						break;
					default:
					}
				}
				i.focus();
				i.select();
				break;
			case 5:
				var values = _g1[2];
				v.empty();
				var s = new js.JQuery("<select>");
				v.addClass("edit");
				var _g2 = 0;
				var _g15 = values.length;
				while(_g2 < _g15) {
					var i1 = _g2++;
					new js.JQuery("<option>").attr("value","" + i1).attr(val == i1?"selected":"_sel","selected").text(values[i1]).appendTo(s);
				}
				if(c.opt) new js.JQuery("<option>").attr("value","-1").text("--- None ---").prependTo(s);
				v.append(s);
				s.change(function(e3) {
					val = Std.parseInt(s.val());
					if(val < 0) {
						val = null;
						Reflect.deleteField(obj,c.name);
					} else obj[c.name] = val;
					html = _g.valueHtml(c,val,sheet,obj);
					_g.changed(sheet,c,index);
					editDone();
					e3.stopPropagation();
				});
				s.keydown(function(e4) {
					var _g16 = e4.keyCode;
					switch(_g16) {
					case 37:case 39:
						s.blur();
						return;
					case 9:
						s.blur();
						_g.moveCursor(e4.shiftKey?-1:1,0,false,false);
						haxe.Timer.delay(function() {
							new js.JQuery(".cursor").dblclick();
						},1);
						e4.preventDefault();
						break;
					default:
					}
					e4.stopPropagation();
				});
				s.blur(function(_2) {
					editDone();
				});
				s.focus();
				var event = window.document.createEvent("MouseEvents");
				event.initMouseEvent("mousedown",true,true,window);
				s[0].dispatchEvent(event);
				break;
			case 6:
				var sname = _g1[2];
				var sdat = this.smap.get(sname);
				if(sdat == null) return;
				v.empty();
				v.addClass("edit");
				var s1 = new js.JQuery("<select>");
				var _g17 = 0;
				var _g21 = sdat.all;
				while(_g17 < _g21.length) {
					var l = _g21[_g17];
					++_g17;
					new js.JQuery("<option>").attr("value","" + l.id).attr(val == l.id?"selected":"_sel","selected").text(l.disp).appendTo(s1);
				}
				if(c.opt || val == null || val == "") new js.JQuery("<option>").attr("value","").text("--- None ---").prependTo(s1);
				v.append(s1);
				s1.change(function(e5) {
					val = s1.val();
					if(val == "") {
						val = null;
						Reflect.deleteField(obj,c.name);
					} else obj[c.name] = val;
					html = _g.valueHtml(c,val,sheet,obj);
					_g.changed(sheet,c,index);
					editDone();
					e5.stopPropagation();
				});
				s1.keydown(function(e6) {
					var _g18 = e6.keyCode;
					switch(_g18) {
					case 37:case 39:
						s1.blur();
						return;
					case 9:
						s1.blur();
						_g.moveCursor(e6.shiftKey?-1:1,0,false,false);
						haxe.Timer.delay(function() {
							new js.JQuery(".cursor").dblclick();
						},1);
						e6.preventDefault();
						break;
					default:
					}
					e6.stopPropagation();
				});
				s1.blur(function(_3) {
					editDone();
				});
				s1.focus();
				var event1 = window.document.createEvent("MouseEvents");
				event1.initMouseEvent("mousedown",true,true,window);
				s1[0].dispatchEvent(event1);
				break;
			case 2:
				if(c.opt && val == false) {
					val = null;
					Reflect.deleteField(obj,c.name);
				} else {
					val = !val;
					obj[c.name] = val;
				}
				v.html(_g.valueHtml(c,val,sheet,obj));
				_g.changed(sheet,c,index);
				break;
			case 7:
				var i2 = new js.JQuery("<input>").attr("type","file").css("display","none").change(function(e7) {
					var j = $(this);
					var file = j.val();
					var ext = file.split(".").pop().toLowerCase();
					if(ext == "jpeg") ext = "jpg";
					if(ext != "png" && ext != "gif" && ext != "jpg") {
						_g.error("Unsupported image extension " + ext);
						return;
					}
					var bytes = sys.io.File.getBytes(file);
					var md5 = haxe.crypto.Md5.make(bytes).toHex();
					if(_g.imageBank == null) _g.imageBank = { };
					if(!Object.prototype.hasOwnProperty.call(_g.imageBank,md5)) {
						var data = "data:image/" + ext + ";base64," + new haxe.crypto.BaseCode(haxe.io.Bytes.ofString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")).encodeBytes(bytes).toString();
						_g.imageBank[md5] = data;
					}
					val = md5;
					obj[c.name] = val;
					v.html(_g.valueHtml(c,val,sheet,obj));
					_g.changed(sheet,c,index);
					j.remove();
				});
				i2.appendTo(new js.JQuery("body"));
				i2.click();
				break;
			case 10:
				var values1 = _g1[2];
				var div = new js.JQuery("<div>").addClass("flagValues");
				div.click(function(e8) {
					e8.stopPropagation();
				}).dblclick(function(e9) {
					e9.stopPropagation();
				});
				var _g22 = 0;
				var _g19 = values1.length;
				while(_g22 < _g19) {
					var i3 = [_g22++];
					var f1 = new js.JQuery("<input>").attr("type","checkbox").prop("checked",(val & 1 << i3[0]) != 0).change((function(i3) {
						return function(e10) {
							val &= ~(1 << i3[0]);
							if($(this).prop("checked")) val |= 1 << i3[0];
							e10.stopPropagation();
						};
					})(i3));
					new js.JQuery("<label>").text(values1[i3[0]]).appendTo(div).append(f1);
				}
				v.empty();
				v.append(div);
				this.cursor.onchange = function() {
					if(c.opt && val == 0) {
						val = null;
						Reflect.deleteField(obj,c.name);
					} else obj[c.name] = val;
					html = _g.valueHtml(c,val,sheet,obj);
					editDone();
					_g.save();
				};
				break;
			case 8:case 11:case 12:
				throw "assert";
				break;
			}
		}
	}
	,updateCursor: function() {
		new js.JQuery(".selected").removeClass("selected");
		new js.JQuery(".cursor").removeClass("cursor");
		if(this.cursor.s == null) return;
		if(this.cursor.y < 0) {
			this.cursor.y = 0;
			this.cursor.select = null;
		}
		if(this.cursor.y >= this.cursor.s.lines.length) {
			this.cursor.y = this.cursor.s.lines.length - 1;
			this.cursor.select = null;
		}
		if(this.cursor.x >= this.cursor.s.columns.length) {
			this.cursor.x = this.cursor.s.columns.length - 1;
			this.cursor.select = null;
		}
		var l = this.getLine(this.cursor.s,this.cursor.y);
		if(this.cursor.x < 0) {
			l.addClass("selected");
			if(this.cursor.select != null) {
				var y = this.cursor.y;
				while(this.cursor.select.y != y) {
					if(this.cursor.select.y > y) y++; else y--;
					this.getLine(this.cursor.s,y).addClass("selected");
				}
			}
		} else {
			l.find("td.c").eq(this.cursor.x).addClass("cursor");
			if(this.cursor.select != null) {
				var s = this.getSelection();
				var _g1 = s.y1;
				var _g = s.y2 + 1;
				while(_g1 < _g) {
					var y1 = _g1++;
					this.getLine(this.cursor.s,y1).find("td.c").slice(s.x1,s.x2 + 1).addClass("selected");
				}
			}
		}
		var e = l[0];
		if(e != null) e.scrollIntoViewIfNeeded();
	}
	,refresh: function() {
		var t = new js.JQuery("<table>");
		this.checkCursor = true;
		this.fillTable(t,this.viewSheet);
		if(this.cursor.s != this.viewSheet && this.checkCursor) this.setCursor(this.viewSheet,null,null,null,false);
		var content = new js.JQuery("#content");
		content.empty();
		t.appendTo(content);
		this.updateCursor();
	}
	,fillTable: function(content,sheet) {
		var _g4 = this;
		if(sheet.columns.length == 0) {
			content.html("<a href=\"javascript:_.newColumn('" + sheet.name + "')\">Add a column</a>");
			return;
		}
		var todo = [];
		var inTodo = false;
		var cols = new js.JQuery("<tr>").addClass("head");
		var types;
		var _g = [];
		var _g1 = 0;
		var _g2 = Type.getEnumConstructs(cdb.ColumnType);
		while(_g1 < _g2.length) {
			var t = _g2[_g1];
			++_g1;
			_g.push(HxOverrides.substr(t,1,null).toLowerCase());
		}
		types = _g;
		new js.JQuery("<td>").addClass("start").appendTo(cols).click(function(_) {
			if(sheet.props.hide) content.change(); else new js.JQuery("tr.list table").change();
		});
		content.addClass("sheet");
		content.attr("sheet",this.getPath(sheet));
		content.click(function(e) {
			e.stopPropagation();
		});
		var lines;
		var _g11 = [];
		var _g3 = 0;
		var _g21 = sheet.lines.length;
		while(_g3 < _g21) {
			var i = [_g3++];
			_g11.push((function($this) {
				var $r;
				var l = new js.JQuery("<tr>");
				l.data("index",i[0]);
				var head = [new js.JQuery("<td>").addClass("start").text("" + i[0])];
				l.mousedown((function(head,i) {
					return function(e1) {
						if(e1.which == 3) {
							head[0].click();
							haxe.Timer.delay(((function() {
								return function(f,a1,a2) {
									return (function() {
										return function() {
											return f(a1,a2);
										};
									})();
								};
							})())($bind(_g4,_g4.popupLine),sheet,i[0]),1);
							e1.preventDefault();
							return;
						}
					};
				})(head,i)).click((function(i) {
					return function(e2) {
						if(e2.shiftKey && _g4.cursor.s == sheet && _g4.cursor.x < 0) {
							_g4.cursor.select = { x : -1, y : i[0]};
							_g4.updateCursor();
						} else _g4.setCursor(sheet,-1,i[0]);
					};
				})(i));
				head[0].appendTo(l);
				$r = l;
				return $r;
			}(this)));
		}
		lines = _g11;
		var colCount = sheet.columns.length;
		if(sheet.props.levelProps != null) colCount++;
		var _g31 = 0;
		var _g22 = sheet.columns.length;
		while(_g31 < _g22) {
			var cindex = [_g31++];
			var c = [sheet.columns[cindex[0]]];
			var col = new js.JQuery("<td>");
			col.html(c[0].name);
			col.css("width",(100 / colCount | 0) + "%");
			if(sheet.props.displayColumn == c[0].name) col.addClass("display");
			col.mousedown((function(c) {
				return function(e3) {
					if(e3.which == 3) {
						haxe.Timer.delay(((function() {
							return function(f1,a11,c1) {
								return (function() {
									return function() {
										return f1(a11,c1);
									};
								})();
							};
						})())($bind(_g4,_g4.popupColumn),sheet,c[0]),1);
						e3.preventDefault();
						return;
					}
				};
			})(c));
			cols.append(col);
			var ctype = "t_" + types[c[0].type[1]];
			var _g5 = 0;
			var _g41 = sheet.lines.length;
			while(_g5 < _g41) {
				var index = [_g5++];
				var obj = [sheet.lines[index[0]]];
				var val = [Reflect.field(obj[0],c[0].name)];
				var v = [new js.JQuery("<td>").addClass(ctype).addClass("c")];
				var l1 = [lines[index[0]]];
				v[0].appendTo(l1[0]);
				var html = [this.valueHtml(c[0],val[0],sheet,obj[0])];
				v[0].html(html[0]);
				v[0].data("index",cindex[0]);
				v[0].click((function(index,cindex) {
					return function(e4) {
						if(inTodo) {
						} else if(e4.shiftKey && _g4.cursor.s == sheet) {
							_g4.cursor.select = { x : cindex[0], y : index[0]};
							_g4.updateCursor();
							e4.stopImmediatePropagation();
						} else _g4.setCursor(sheet,cindex[0],index[0]);
						e4.stopPropagation();
					};
				})(index,cindex));
				{
					var _g6 = c[0].type;
					switch(_g6[1]) {
					case 7:
						v[0].find("img").addClass("deletable").change((function(obj,c) {
							return function(e5) {
								if(Reflect.field(obj[0],c[0].name) != null) {
									Reflect.deleteField(obj[0],c[0].name);
									_g4.refresh();
									_g4.save();
								}
							};
						})(obj,c)).click((function() {
							return function(e6) {
								$(this).addClass("selected");
								e6.stopPropagation();
							};
						})());
						v[0].dblclick((function(v,index,c) {
							return function(_1) {
								_g4.editCell(c[0],v[0],sheet,index[0]);
							};
						})(v,index,c));
						break;
					case 8:
						var key = [this.getPath(sheet) + "@" + c[0].name + ":" + index[0]];
						v[0].click((function(key,html,l1,v,val,obj,index,c,cindex) {
							return function(e7) {
								var next = l1[0].next("tr.list");
								if(next.length > 0) {
									if(next.data("name") == c[0].name) {
										next.change();
										return;
									}
									next.change();
								}
								next = new js.JQuery("<tr>").addClass("list").data("name",c[0].name);
								new js.JQuery("<td>").appendTo(next);
								var cell = new js.JQuery("<td>").attr("colspan","" + sheet.columns.length).appendTo(next);
								var div = new js.JQuery("<div>").appendTo(cell);
								if(!inTodo) div.hide();
								var content1 = new js.JQuery("<table>").appendTo(div);
								var psheet = _g4.smap.get(sheet.name + "@" + c[0].name).s;
								if(val[0] == null) {
									val[0] = [];
									obj[0][c[0].name] = val[0];
								}
								psheet = { columns : psheet.columns, props : psheet.props, name : psheet.name, path : key[0], parent : { sheet : sheet, column : cindex[0], line : index[0]}, lines : val[0], separators : []};
								_g4.fillTable(content1,psheet);
								next.insertAfter(l1[0]);
								v[0].html("...");
								_g4.openedList.set(key[0],true);
								next.change((function(key,html,v,val,obj,c) {
									return function(e8) {
										if(c[0].opt && val[0].length == 0) {
											val[0] = null;
											Reflect.deleteField(obj[0],c[0].name);
										}
										html[0] = _g4.valueHtml(c[0],val[0],sheet,obj[0]);
										v[0].html(html[0]);
										div.slideUp(100,(function() {
											return function() {
												next.remove();
											};
										})());
										_g4.openedList.remove(key[0]);
										e8.stopPropagation();
									};
								})(key,html,v,val,obj,c));
								if(inTodo) {
									if(_g4.cursor.s != null && _g4.getPath(_g4.cursor.s) == _g4.getPath(psheet)) {
										_g4.cursor.s = psheet;
										_g4.checkCursor = false;
									}
								} else {
									div.slideDown(100);
									_g4.setCursor(psheet);
								}
								e7.stopPropagation();
							};
						})(key,html,l1,v,val,obj,index,c,cindex));
						if(this.openedList.get(key[0])) todo.push((function(v) {
							return function() {
								v[0].click();
							};
						})(v));
						break;
					case 11:case 12:
						break;
					default:
						v[0].dblclick((function(v,index,c) {
							return function(e9) {
								_g4.editCell(c[0],v[0],sheet,index[0]);
							};
						})(v,index,c));
					}
				}
			}
		}
		if(sheet.props.levelProps != null) {
			var col1 = new js.JQuery("<td>");
			cols.append(col1);
			var _g32 = 0;
			var _g23 = sheet.lines.length;
			while(_g32 < _g23) {
				var index1 = [_g32++];
				var l2 = lines[index1[0]];
				var c2 = new js.JQuery("<input type='submit' value='Edit'>");
				new js.JQuery("<td>").append(c2).appendTo(l2);
				c2.click((function(index1) {
					return function() {
						_g4.level = new Level(_g4,sheet,index1[0]);
						new js.JQuery("#sheets li").removeClass("active");
					};
				})(index1));
			}
		}
		content.empty();
		content.append(cols);
		var snext = 0;
		var _g33 = 0;
		var _g24 = lines.length;
		while(_g33 < _g24) {
			var i1 = _g33++;
			if(sheet.separators[snext] == i1) {
				var sep = new js.JQuery("<tr>").addClass("separator").append("<td colspan=\"" + (sheet.columns.length + 1) + "\">").appendTo(content);
				var content2 = [sep.find("td")];
				var title = [sheet.props.separatorTitles != null?sheet.props.separatorTitles[snext]:null];
				if(title[0] != null) content2[0].text(title[0]);
				var pos = [snext];
				sep.dblclick((function(pos,title,content2) {
					return function(e10) {
						content2[0].empty();
						new js.JQuery("<input>").appendTo(content2[0]).focus().val(title[0] == null?"":title[0]).blur((function(pos,title,content2) {
							return function(_2) {
								title[0] = $(this).val();
								$(this).remove();
								content2[0].text(title[0]);
								var titles = sheet.props.separatorTitles;
								if(titles == null) titles = [];
								while(titles.length < pos[0]) titles.push(null);
								if(title[0] == "") titles[pos[0]] = null; else titles[pos[0]] = title[0];
								while(titles[titles.length - 1] == null && titles.length > 0) titles.pop();
								if(titles.length == 0) titles = null;
								sheet.props.separatorTitles = titles;
								_g4.save();
							};
						})(pos,title,content2)).keypress((function() {
							return function(e11) {
								e11.stopPropagation();
							};
						})()).keydown((function(title,content2) {
							return function(e12) {
								if(e12.keyCode == 13) {
									$(this).blur();
									e12.preventDefault();
								} else if(e12.keyCode == 27) content2[0].text(title[0]);
								e12.stopPropagation();
							};
						})(title,content2));
					};
				})(pos,title,content2));
				snext++;
			}
			content.append(lines[i1]);
		}
		inTodo = true;
		var _g25 = 0;
		while(_g25 < todo.length) {
			var t1 = todo[_g25];
			++_g25;
			t1();
		}
		inTodo = false;
	}
	,setCursor: function(s,x,y,sel,update) {
		if(update == null) update = true;
		if(y == null) y = 0;
		if(x == null) x = 0;
		this.cursor.s = s;
		this.cursor.x = x;
		this.cursor.y = y;
		this.cursor.select = sel;
		var ch = this.cursor.onchange;
		if(ch != null) {
			this.cursor.onchange = null;
			ch();
		}
		if(update) this.updateCursor();
	}
	,selectSheet: function(s,manual) {
		if(manual == null) manual = true;
		this.viewSheet = s;
		this.cursor = this.sheetCursors.get(s.name);
		if(this.cursor == null) {
			this.cursor = { x : 0, y : 0, s : s};
			this.sheetCursors.set(s.name,this.cursor);
		}
		this.prefs.curSheet = Lambda.indexOf(this.data.sheets,s);
		new js.JQuery("#sheets li").removeClass("active").filter("#sheet_" + this.prefs.curSheet).addClass("active");
		if(manual) this.level = null;
		this.refresh();
	}
	,newSheet: function() {
		new js.JQuery("#newsheet").show();
	}
	,deleteColumn: function(sheet,cname) {
		if(cname == null) {
			sheet = this.smap.get(this.colProps.sheet).s;
			cname = this.colProps.ref.name;
		}
		if(!Model.prototype.deleteColumn.call(this,sheet,cname)) return false;
		new js.JQuery("#newcol").hide();
		this.refresh();
		this.save();
		return true;
	}
	,editTypes: function() {
		var _g = this;
		if(this.typesStr == null) {
			var tl = [];
			var _g1 = 0;
			var _g11 = this.data.customTypes;
			while(_g1 < _g11.length) {
				var t = _g11[_g1];
				++_g1;
				tl.push("enum " + t.name + " {\n" + this.typeCasesToString(t,"\t") + "\n}");
			}
			this.typesStr = tl.join("\n\n");
		}
		var content = new js.JQuery("#content");
		content.html(new js.JQuery("#editTypes").html());
		var text = content.find("textarea");
		var apply = content.find("input.button").first();
		var cancel = content.find("input.button").eq(1);
		var types;
		text.change(function(_) {
			var nstr = text.val();
			if(nstr == _g.typesStr) return;
			_g.typesStr = nstr;
			var errors = [];
			var t1 = StringTools.trim(_g.typesStr);
			var r = new EReg("^enum[ \r\n\t]+([A-Za-z0-9_]+)[ \r\n\t]*\\{([^}]*)\\}","");
			var oldTMap = _g.tmap;
			var descs = [];
			_g.tmap = new haxe.ds.StringMap();
			types = [];
			while(r.match(t1)) {
				var name = r.matched(1);
				var desc = r.matched(2);
				if(_g.tmap.get(name) != null) errors.push("Duplicate type " + name);
				var td = { name : name, cases : []};
				_g.tmap.set(name,td);
				descs.push(desc);
				types.push(td);
				t1 = StringTools.trim(r.matchedRight());
			}
			var _g12 = 0;
			while(_g12 < types.length) {
				var t2 = types[_g12];
				++_g12;
				try {
					t2.cases = _g.parseTypeCases(descs.shift());
				} catch( msg ) {
					errors.push(msg);
				}
			}
			_g.tmap = oldTMap;
			if(t1 != "") errors.push("Invalid " + StringTools.htmlEscape(t1));
			_g.setErrorMessage(errors.length == 0?null:errors.join("<br>"));
			if(errors.length == 0) apply.removeAttr("disabled"); else apply.attr("disabled","");
		});
		text.keydown(function(e) {
			if(e.keyCode == 9) {
				e.preventDefault();
				new js.Selection(text[0]).insert("\t","","");
			}
			e.stopPropagation();
		});
		text.keyup(function(e1) {
			text.change();
			e1.stopPropagation();
		});
		text.val(this.typesStr);
		cancel.click(function(_1) {
			_g.typesStr = null;
			_g.setErrorMessage();
			_g.quickLoad(_g.curSavedData);
			_g.initContent();
		});
		apply.click(function(_2) {
			var tpairs = _g.makePairs(_g.data.customTypes,types);
			var _g13 = 0;
			while(_g13 < tpairs.length) {
				var p = tpairs[_g13];
				++_g13;
				if(p.b == null) {
					var t3 = p.a;
					var _g2 = 0;
					var _g3 = _g.data.sheets;
					while(_g2 < _g3.length) {
						var s = _g3[_g2];
						++_g2;
						var _g4 = 0;
						var _g5 = s.columns;
						while(_g4 < _g5.length) {
							var c = _g5[_g4];
							++_g4;
							{
								var _g6 = c.type;
								switch(_g6[1]) {
								case 9:
									var name1 = _g6[2];
									if(name1 == t3.name) {
										_g.error("Type " + name1 + " used by " + s.name + "@" + c.name + " cannot be removed");
										return;
									} else {
									}
									break;
								default:
								}
							}
						}
					}
				}
			}
			var _g14 = 0;
			while(_g14 < types.length) {
				var t4 = [types[_g14]];
				++_g14;
				if(!Lambda.exists(tpairs,(function(t4) {
					return function(p1) {
						return p1.b == t4[0];
					};
				})(t4))) _g.data.customTypes.push(t4[0]);
			}
			var _g15 = 0;
			while(_g15 < tpairs.length) {
				var p2 = tpairs[_g15];
				++_g15;
				if(p2.b == null) HxOverrides.remove(_g.data.customTypes,p2.a); else try {
					_g.updateType(p2.a,p2.b);
				} catch( msg1 ) {
					if( js.Boot.__instanceof(msg1,String) ) {
						_g.error("Error while updating " + p2.b.name + " : " + msg1);
						return;
					} else throw(msg1);
				}
			}
			_g.initContent();
			_g.typesStr = null;
			_g.save();
		});
		this.typesStr = null;
		text.change();
	}
	,newColumn: function(sheetName,ref,index) {
		var form = new js.JQuery("#newcol form");
		this.colProps = { sheet : sheetName, ref : ref, index : index};
		var sheets = new js.JQuery("[name=sheet]");
		sheets.empty();
		var _g1 = 0;
		var _g = this.data.sheets.length;
		while(_g1 < _g) {
			var i = _g1++;
			var s = this.data.sheets[i];
			if(s.props.hide) continue;
			new js.JQuery("<option>").attr("value","" + i).text(s.name).appendTo(sheets);
		}
		var types = new js.JQuery("[name=ctype]");
		types.empty();
		types.unbind("change");
		types.change(function(_) {
			new js.JQuery("#col_options").toggleClass("t_edit",types.val() != "");
		});
		new js.JQuery("<option>").attr("value","").text("--- Select ---").appendTo(types);
		var _g2 = 0;
		var _g11 = this.data.customTypes;
		while(_g2 < _g11.length) {
			var t = _g11[_g2];
			++_g2;
			new js.JQuery("<option>").attr("value","" + t.name).text(t.name).appendTo(types);
		}
		form.removeClass("edit").removeClass("create");
		if(ref != null) {
			form.addClass("edit");
			form.find("[name=name]").val(ref.name);
			form.find("[name=type]").val(HxOverrides.substr(ref.type[0],1,null).toLowerCase()).change();
			form.find("[name=req]").prop("checked",!ref.opt);
			form.find("[name=display]").val(ref.display == null?"0":Std.string(ref.display));
			{
				var _g3 = ref.type;
				switch(_g3[1]) {
				case 5:
					var values = _g3[2];
					form.find("[name=values]").val(values.join(","));
					break;
				case 10:
					var values = _g3[2];
					form.find("[name=values]").val(values.join(","));
					break;
				case 6:
					var sname = _g3[2];
					form.find("[name=sheet]").val("" + Lambda.indexOf(this.data.sheets,Lambda.find(this.data.sheets,function(s1) {
						return s1.name == sname;
					})));
					break;
				case 12:
					var sname = _g3[2];
					form.find("[name=sheet]").val("" + Lambda.indexOf(this.data.sheets,Lambda.find(this.data.sheets,function(s1) {
						return s1.name == sname;
					})));
					break;
				case 9:
					var name = _g3[2];
					form.find("[name=ctype]").val(name);
					break;
				default:
				}
			}
		} else {
			form.addClass("create");
			form.find("input").not("[type=submit]").val("");
			form.find("[name=req]").prop("checked",true);
		}
		types.change();
		new js.JQuery("#newcol").show();
	}
	,newLine: function(sheet,index) {
		Model.prototype.newLine.call(this,sheet,index);
		this.refresh();
		this.save();
	}
	,insertLine: function() {
		if(this.cursor.s != null) this.newLine(this.cursor.s);
	}
	,createSheet: function(name) {
		name = StringTools.trim(name);
		if(!this.r_ident.match(name)) {
			this.error("Invalid sheet name");
			return;
		}
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			if(s.name == name) {
				this.error("Sheet name already in use");
				return;
			}
		}
		new js.JQuery("#newsheet").hide();
		var s1 = { name : name, columns : [], lines : [], separators : [], props : { }};
		this.prefs.curSheet = this.data.sheets.length;
		this.data.sheets.push(s1);
		this.initContent();
		this.save();
	}
	,createColumn: function() {
		var v = { };
		var cols = new js.JQuery("#col_form input, #col_form select").not("[type=submit]");
		var $it0 = (cols.iterator)();
		while( $it0.hasNext() ) {
			var i = $it0.next();
			Reflect.setField(v,i.attr("name"),i.attr("type") == "checkbox"?i["is"](":checked")?"on":null:i.val());
		}
		var sheet;
		if(this.colProps.sheet == null) sheet = this.viewSheet; else sheet = this.smap.get(this.colProps.sheet).s;
		var refColumn = this.colProps.ref;
		var t;
		var _g = v.type;
		switch(_g) {
		case "id":
			t = cdb.ColumnType.TId;
			break;
		case "int":
			t = cdb.ColumnType.TInt;
			break;
		case "float":
			t = cdb.ColumnType.TFloat;
			break;
		case "string":
			t = cdb.ColumnType.TString;
			break;
		case "bool":
			t = cdb.ColumnType.TBool;
			break;
		case "enum":
			var vals = StringTools.trim(v.values).split(",");
			if(vals.length == 0) {
				this.error("Missing value list");
				return;
			}
			t = cdb.ColumnType.TEnum((function($this) {
				var $r;
				var _g1 = [];
				{
					var _g2 = 0;
					while(_g2 < vals.length) {
						var f = vals[_g2];
						++_g2;
						_g1.push(StringTools.trim(f));
					}
				}
				$r = _g1;
				return $r;
			}(this)));
			break;
		case "flags":
			var vals1 = StringTools.trim(v.values).split(",");
			if(vals1.length == 0) {
				this.error("Missing value list");
				return;
			}
			t = cdb.ColumnType.TFlags((function($this) {
				var $r;
				var _g11 = [];
				{
					var _g21 = 0;
					while(_g21 < vals1.length) {
						var f1 = vals1[_g21];
						++_g21;
						_g11.push(StringTools.trim(f1));
					}
				}
				$r = _g11;
				return $r;
			}(this)));
			break;
		case "ref":
			var s = this.data.sheets[Std.parseInt(v.sheet)];
			if(s == null) {
				this.error("Sheet not found");
				return;
			}
			t = cdb.ColumnType.TRef(s.name);
			break;
		case "image":
			t = cdb.ColumnType.TImage;
			break;
		case "list":
			t = cdb.ColumnType.TList;
			break;
		case "custom":
			var t1 = this.tmap.get(v.ctype);
			if(t1 == null) {
				this.error("Type not found");
				return;
			}
			t = cdb.ColumnType.TCustom(t1.name);
			break;
		case "color":
			t = cdb.ColumnType.TColor;
			break;
		case "layer":
			var s1 = this.data.sheets[Std.parseInt(v.sheet)];
			if(s1 == null) {
				this.error("Sheet not found");
				return;
			}
			t = cdb.ColumnType.TLayer(s1.name);
			break;
		default:
			return;
		}
		var c = { type : t, typeStr : null, name : v.name};
		if(v.req != "on") c.opt = true;
		if(v.display != "0") c.display = Std.parseInt(v.display);
		if(refColumn != null) {
			var err = Model.prototype.updateColumn.call(this,sheet,refColumn,c);
			if(err != null) {
				this.refresh();
				this.save();
				this.error(err);
				return;
			}
		} else {
			var err1 = Model.prototype.addColumn.call(this,sheet,c,this.colProps.index);
			if(err1 != null) {
				this.error(err1);
				return;
			}
		}
		new js.JQuery("#newcol").hide();
		var $it1 = (cols.iterator)();
		while( $it1.hasNext() ) {
			var c1 = $it1.next();
			c1.val("");
		}
		this.refresh();
		this.save();
	}
	,initContent: function() {
		var _g2 = this;
		Model.prototype.initContent.call(this);
		var sheets = new js.JQuery("ul#sheets");
		sheets.children().remove();
		var _g1 = 0;
		var _g = this.data.sheets.length;
		while(_g1 < _g) {
			var i = _g1++;
			var s = [this.data.sheets[i]];
			if(s[0].props.hide) continue;
			var li = [new js.JQuery("<li>")];
			li[0].text(s[0].name).attr("id","sheet_" + i).appendTo(sheets).click(((function() {
				return function(f,s1) {
					return (function() {
						return function() {
							return f(s1);
						};
					})();
				};
			})())($bind(this,this.selectSheet),s[0])).dblclick((function(li,s) {
				return function(_) {
					li[0].empty();
					new js.JQuery("<input>").val(s[0].name).appendTo(li[0]).focus().blur((function(li,s) {
						return function(_1) {
							li[0].text(s[0].name);
							var name = $(this).val();
							if(!_g2.r_ident.match(name)) {
								_g2.error("Invalid sheet name");
								return;
							}
							var f1 = _g2.smap.get(name);
							if(f1 != null) {
								if(f1.s != s[0]) _g2.error("Sheet name already in use");
								return;
							}
							var old = s[0].name;
							s[0].name = name;
							_g2.mapType((function() {
								return function(t) {
									switch(t[1]) {
									case 6:
										var o = t[2];
										if(o == old) return cdb.ColumnType.TRef(name); else return t;
										break;
									case 12:
										var o1 = t[2];
										if(o1 == old) return cdb.ColumnType.TLayer(name); else return t;
										break;
									default:
										return t;
									}
								};
							})());
							var _g3 = 0;
							var _g4 = _g2.data.sheets;
							while(_g3 < _g4.length) {
								var s2 = _g4[_g3];
								++_g3;
								if(StringTools.startsWith(s2.name,old + "@")) s2.name = name + "@" + HxOverrides.substr(s2.name,old.length + 1,null);
							}
							_g2.initContent();
							_g2.save();
						};
					})(li,s)).keydown((function() {
						return function(e) {
							if(e.keyCode == 13) $(this).blur(); else if(e.keyCode == 27) _g2.initContent();
							e.stopPropagation();
						};
					})()).keypress((function() {
						return function(e1) {
							e1.stopPropagation();
						};
					})());
				};
			})(li,s)).mousedown((function(li,s) {
				return function(e2) {
					if(e2.which == 3) {
						haxe.Timer.delay(((function() {
							return function(f2,s3,li1) {
								return (function() {
									return function() {
										return f2(s3,li1);
									};
								})();
							};
						})())($bind(_g2,_g2.popupSheet),s[0],li[0]),1);
						e2.stopPropagation();
					}
				};
			})(li,s));
		}
		if(this.data.sheets.length == 0) {
			new js.JQuery("#content").html("<a href='javascript:_.newSheet()'>Create a sheet</a>");
			return;
		}
		var s4 = this.data.sheets[this.prefs.curSheet];
		if(s4 == null) s4 = this.data.sheets[0];
		this.selectSheet(s4,false);
		if(this.level != null) {
			if(!this.smap.exists(this.level.sheetPath)) this.level = null; else {
				var s5 = this.smap.get(this.level.sheetPath).s;
				if(s5.lines.length < this.level.index) this.level = null; else this.level = new Level(this,s5,this.level.index);
			}
			if(this.level != null) new js.JQuery("#sheets li").removeClass("active");
		}
	}
	,initMenu: function() {
		var _g = this;
		var menu = new nodejs.webkit.Menu({ type : "menubar"});
		var mfile = new nodejs.webkit.MenuItem({ label : "File"});
		var mfiles = new nodejs.webkit.Menu();
		var mnew = new nodejs.webkit.MenuItem({ label : "New"});
		var mopen = new nodejs.webkit.MenuItem({ label : "Open..."});
		var msave = new nodejs.webkit.MenuItem({ label : "Save As..."});
		var mclean = new nodejs.webkit.MenuItem({ label : "Clean Images"});
		var mabout = new nodejs.webkit.MenuItem({ label : "About"});
		var mexit = new nodejs.webkit.MenuItem({ label : "Exit"});
		var mdebug = new nodejs.webkit.MenuItem({ label : "Dev"});
		mnew.click = function() {
			_g.prefs.curFile = null;
			_g.load(true);
		};
		mdebug.click = function() {
			_g.window.showDevTools();
		};
		mopen.click = function() {
			var i = new js.JQuery("<input>").attr("type","file").css("display","none").change(function(e) {
				var j = $(this);
				_g.prefs.curFile = j.val();
				_g.load();
				j.remove();
			});
			i.appendTo(new js.JQuery("body"));
			i.click();
		};
		msave.click = function() {
			var i1 = new js.JQuery("<input>").attr("type","file").attr("nwsaveas","new.cdb").css("display","none").change(function(e1) {
				var j1 = $(this);
				_g.prefs.curFile = j1.val();
				_g.save();
				j1.remove();
			});
			i1.appendTo(new js.JQuery("body"));
			i1.click();
		};
		mclean.click = function() {
			if(_g.imageBank == null) {
				_g.error("No image bank");
				return;
			}
			var count = Reflect.fields(_g.imageBank).length;
			_g.cleanImages();
			var count2 = Reflect.fields(_g.imageBank).length;
			_g.error(count - count2 + " unused images removed");
			if(count2 == 0) _g.imageBank = null;
			_g.refresh();
			_g.saveImages();
		};
		mexit.click = function() {
			Sys.exit(0);
		};
		mabout.click = function() {
			new js.JQuery("#about").show();
		};
		mfiles.append(mnew);
		mfiles.append(mopen);
		mfiles.append(msave);
		mfiles.append(mclean);
		mfiles.append(mabout);
		mfiles.append(mexit);
		mfile.submenu = mfiles;
		menu.append(mfile);
		menu.append(mdebug);
		this.window.menu = menu;
		this.window.moveTo(this.prefs.windowPos.x,this.prefs.windowPos.y);
		this.window.resizeTo(this.prefs.windowPos.w,this.prefs.windowPos.h);
		this.window.show();
		if(this.prefs.windowPos.max) this.window.maximize();
		this.window.on("close",function() {
			if(!_g.prefs.windowPos.max) _g.prefs.windowPos = { x : _g.window.x, y : _g.window.y, w : _g.window.width, h : _g.window.height, max : false};
			_g.savePrefs();
			_g.window.close(true);
		});
		this.window.on("maximize",function() {
			_g.prefs.windowPos.max = true;
		});
		this.window.on("unmaximize",function() {
			_g.prefs.windowPos.max = false;
		});
	}
	,getFileTime: function() {
		try {
			return js.Node.require("fs").statSync(this.prefs.curFile).mtime.getTime() * 1.;
		} catch( e ) {
			return 0.;
		}
	}
	,checkTime: function() {
		if(this.prefs.curFile == null) return;
		var fileTime = this.getFileTime();
		if(fileTime != this.lastSave && fileTime != 0) {
			if(window.confirm("The CDB file has been modified. Reload?")) {
				if(sys.io.File.getContent(this.prefs.curFile).indexOf("<<<<<<<") >= 0) {
					this.error("The file has conflicts, please resolve them before reloading");
					return;
				}
				this.load();
			} else this.lastSave = fileTime;
		}
	}
	,load: function(noError) {
		if(noError == null) noError = false;
		Model.prototype.load.call(this,noError);
		this.lastSave = this.getFileTime();
	}
	,save: function(history) {
		if(history == null) history = true;
		Model.prototype.save.call(this,history);
		this.lastSave = this.getFileTime();
	}
	,__class__: Main
});
var IMap = function() { };
$hxClasses["IMap"] = IMap;
IMap.__name__ = ["IMap"];
IMap.prototype = {
	__class__: IMap
};
Math.__name__ = ["Math"];
var Reflect = function() { };
$hxClasses["Reflect"] = Reflect;
Reflect.__name__ = ["Reflect"];
Reflect.field = function(o,field) {
	try {
		return o[field];
	} catch( e ) {
		return null;
	}
};
Reflect.setField = function(o,field,value) {
	o[field] = value;
};
Reflect.fields = function(o) {
	var a = [];
	if(o != null) {
		var hasOwnProperty = Object.prototype.hasOwnProperty;
		for( var f in o ) {
		if(f != "__id__" && f != "hx__closures__" && hasOwnProperty.call(o,f)) a.push(f);
		}
	}
	return a;
};
Reflect.isFunction = function(f) {
	return typeof(f) == "function" && !(f.__name__ || f.__ename__);
};
Reflect.deleteField = function(o,field) {
	if(!Object.prototype.hasOwnProperty.call(o,field)) return false;
	delete(o[field]);
	return true;
};
var Std = function() { };
$hxClasses["Std"] = Std;
Std.__name__ = ["Std"];
Std.instance = function(value,c) {
	if((value instanceof c)) return value; else return null;
};
Std.string = function(s) {
	return js.Boot.__string_rec(s,"");
};
Std["int"] = function(x) {
	return x | 0;
};
Std.parseInt = function(x) {
	var v = parseInt(x,10);
	if(v == 0 && (HxOverrides.cca(x,1) == 120 || HxOverrides.cca(x,1) == 88)) v = parseInt(x);
	if(isNaN(v)) return null;
	return v;
};
Std.parseFloat = function(x) {
	return parseFloat(x);
};
var StringBuf = function() {
	this.b = "";
};
$hxClasses["StringBuf"] = StringBuf;
StringBuf.__name__ = ["StringBuf"];
StringBuf.prototype = {
	add: function(x) {
		this.b += Std.string(x);
	}
	,__class__: StringBuf
};
var StringTools = function() { };
$hxClasses["StringTools"] = StringTools;
StringTools.__name__ = ["StringTools"];
StringTools.htmlEscape = function(s,quotes) {
	s = s.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
	if(quotes) return s.split("\"").join("&quot;").split("'").join("&#039;"); else return s;
};
StringTools.startsWith = function(s,start) {
	return s.length >= start.length && HxOverrides.substr(s,0,start.length) == start;
};
StringTools.endsWith = function(s,end) {
	var elen = end.length;
	var slen = s.length;
	return slen >= elen && HxOverrides.substr(s,slen - elen,elen) == end;
};
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	return c > 8 && c < 14 || c == 32;
};
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) r++;
	if(r > 0) return HxOverrides.substr(s,r,l - r); else return s;
};
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) r++;
	if(r > 0) return HxOverrides.substr(s,0,l - r); else return s;
};
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
};
StringTools.hex = function(n,digits) {
	var s = "";
	var hexChars = "0123456789ABCDEF";
	do {
		s = hexChars.charAt(n & 15) + s;
		n >>>= 4;
	} while(n > 0);
	if(digits != null) while(s.length < digits) s = "0" + s;
	return s;
};
StringTools.fastCodeAt = function(s,index) {
	return s.charCodeAt(index);
};
var Sys = function() { };
$hxClasses["Sys"] = Sys;
Sys.__name__ = ["Sys"];
Sys.args = function() {
	return js.Node.process.argv;
};
Sys.getEnv = function(key) {
	return Reflect.field(js.Node.process.env,key);
};
Sys.environment = function() {
	return js.Node.process.env;
};
Sys.exit = function(code) {
	js.Node.process.exit(code);
};
Sys.time = function() {
	return new Date().getTime() / 1000;
};
var ValueType = $hxClasses["ValueType"] = { __ename__ : ["ValueType"], __constructs__ : ["TNull","TInt","TFloat","TBool","TObject","TFunction","TClass","TEnum","TUnknown"] };
ValueType.TNull = ["TNull",0];
ValueType.TNull.toString = $estr;
ValueType.TNull.__enum__ = ValueType;
ValueType.TInt = ["TInt",1];
ValueType.TInt.toString = $estr;
ValueType.TInt.__enum__ = ValueType;
ValueType.TFloat = ["TFloat",2];
ValueType.TFloat.toString = $estr;
ValueType.TFloat.__enum__ = ValueType;
ValueType.TBool = ["TBool",3];
ValueType.TBool.toString = $estr;
ValueType.TBool.__enum__ = ValueType;
ValueType.TObject = ["TObject",4];
ValueType.TObject.toString = $estr;
ValueType.TObject.__enum__ = ValueType;
ValueType.TFunction = ["TFunction",5];
ValueType.TFunction.toString = $estr;
ValueType.TFunction.__enum__ = ValueType;
ValueType.TClass = function(c) { var $x = ["TClass",6,c]; $x.__enum__ = ValueType; $x.toString = $estr; return $x; };
ValueType.TEnum = function(e) { var $x = ["TEnum",7,e]; $x.__enum__ = ValueType; $x.toString = $estr; return $x; };
ValueType.TUnknown = ["TUnknown",8];
ValueType.TUnknown.toString = $estr;
ValueType.TUnknown.__enum__ = ValueType;
var Type = function() { };
$hxClasses["Type"] = Type;
Type.__name__ = ["Type"];
Type.getClassName = function(c) {
	var a = c.__name__;
	return a.join(".");
};
Type.getEnumName = function(e) {
	var a = e.__ename__;
	return a.join(".");
};
Type.resolveClass = function(name) {
	var cl = $hxClasses[name];
	if(cl == null || !cl.__name__) return null;
	return cl;
};
Type.resolveEnum = function(name) {
	var e = $hxClasses[name];
	if(e == null || !e.__ename__) return null;
	return e;
};
Type.createEmptyInstance = function(cl) {
	function empty() {}; empty.prototype = cl.prototype;
	return new empty();
};
Type.createEnum = function(e,constr,params) {
	var f = Reflect.field(e,constr);
	if(f == null) throw "No such constructor " + constr;
	if(Reflect.isFunction(f)) {
		if(params == null) throw "Constructor " + constr + " need parameters";
		return f.apply(e,params);
	}
	if(params != null && params.length != 0) throw "Constructor " + constr + " does not need parameters";
	return f;
};
Type.getEnumConstructs = function(e) {
	var a = e.__constructs__;
	return a.slice();
};
Type["typeof"] = function(v) {
	var _g = typeof(v);
	switch(_g) {
	case "boolean":
		return ValueType.TBool;
	case "string":
		return ValueType.TClass(String);
	case "number":
		if(Math.ceil(v) == v % 2147483648.0) return ValueType.TInt;
		return ValueType.TFloat;
	case "object":
		if(v == null) return ValueType.TNull;
		var e = v.__enum__;
		if(e != null) return ValueType.TEnum(e);
		var c;
		if((v instanceof Array) && v.__enum__ == null) c = Array; else c = v.__class__;
		if(c != null) return ValueType.TClass(c);
		return ValueType.TObject;
	case "function":
		if(v.__name__ || v.__ename__) return ValueType.TObject;
		return ValueType.TFunction;
	case "undefined":
		return ValueType.TNull;
	default:
		return ValueType.TUnknown;
	}
};
Type.enumEq = function(a,b) {
	if(a == b) return true;
	try {
		if(a[0] != b[0]) return false;
		var _g1 = 2;
		var _g = a.length;
		while(_g1 < _g) {
			var i = _g1++;
			if(!Type.enumEq(a[i],b[i])) return false;
		}
		var e = a.__enum__;
		if(e != b.__enum__ || e == null) return false;
	} catch( e1 ) {
		return false;
	}
	return true;
};
var cdb = {};
cdb.ColumnType = $hxClasses["cdb.ColumnType"] = { __ename__ : ["cdb","ColumnType"], __constructs__ : ["TId","TString","TBool","TInt","TFloat","TEnum","TRef","TImage","TList","TCustom","TFlags","TColor","TLayer"] };
cdb.ColumnType.TId = ["TId",0];
cdb.ColumnType.TId.toString = $estr;
cdb.ColumnType.TId.__enum__ = cdb.ColumnType;
cdb.ColumnType.TString = ["TString",1];
cdb.ColumnType.TString.toString = $estr;
cdb.ColumnType.TString.__enum__ = cdb.ColumnType;
cdb.ColumnType.TBool = ["TBool",2];
cdb.ColumnType.TBool.toString = $estr;
cdb.ColumnType.TBool.__enum__ = cdb.ColumnType;
cdb.ColumnType.TInt = ["TInt",3];
cdb.ColumnType.TInt.toString = $estr;
cdb.ColumnType.TInt.__enum__ = cdb.ColumnType;
cdb.ColumnType.TFloat = ["TFloat",4];
cdb.ColumnType.TFloat.toString = $estr;
cdb.ColumnType.TFloat.__enum__ = cdb.ColumnType;
cdb.ColumnType.TEnum = function(values) { var $x = ["TEnum",5,values]; $x.__enum__ = cdb.ColumnType; $x.toString = $estr; return $x; };
cdb.ColumnType.TRef = function(sheet) { var $x = ["TRef",6,sheet]; $x.__enum__ = cdb.ColumnType; $x.toString = $estr; return $x; };
cdb.ColumnType.TImage = ["TImage",7];
cdb.ColumnType.TImage.toString = $estr;
cdb.ColumnType.TImage.__enum__ = cdb.ColumnType;
cdb.ColumnType.TList = ["TList",8];
cdb.ColumnType.TList.toString = $estr;
cdb.ColumnType.TList.__enum__ = cdb.ColumnType;
cdb.ColumnType.TCustom = function(name) { var $x = ["TCustom",9,name]; $x.__enum__ = cdb.ColumnType; $x.toString = $estr; return $x; };
cdb.ColumnType.TFlags = function(values) { var $x = ["TFlags",10,values]; $x.__enum__ = cdb.ColumnType; $x.toString = $estr; return $x; };
cdb.ColumnType.TColor = ["TColor",11];
cdb.ColumnType.TColor.toString = $estr;
cdb.ColumnType.TColor.__enum__ = cdb.ColumnType;
cdb.ColumnType.TLayer = function(type) { var $x = ["TLayer",12,type]; $x.__enum__ = cdb.ColumnType; $x.toString = $estr; return $x; };
cdb.Parser = function() { };
$hxClasses["cdb.Parser"] = cdb.Parser;
cdb.Parser.__name__ = ["cdb","Parser"];
cdb.Parser.saveType = function(t) {
	switch(t[1]) {
	case 6:case 9:case 12:
		return t[1] + ":" + t.slice(2)[0];
	case 5:
		var values = t[2];
		return t[1] + ":" + values.join(",");
	case 10:
		var values = t[2];
		return t[1] + ":" + values.join(",");
	case 0:case 1:case 8:case 3:case 7:case 4:case 2:case 11:
		return Std.string(t[1]);
	}
};
cdb.Parser.getType = function(str) {
	var _g = Std.parseInt(str);
	if(_g != null) switch(_g) {
	case 0:
		return cdb.ColumnType.TId;
	case 1:
		return cdb.ColumnType.TString;
	case 2:
		return cdb.ColumnType.TBool;
	case 3:
		return cdb.ColumnType.TInt;
	case 4:
		return cdb.ColumnType.TFloat;
	case 5:
		return cdb.ColumnType.TEnum(((function($this) {
			var $r;
			var pos = str.indexOf(":") + 1;
			$r = HxOverrides.substr(str,pos,null);
			return $r;
		}(this))).split(","));
	case 6:
		return cdb.ColumnType.TRef((function($this) {
			var $r;
			var pos1 = str.indexOf(":") + 1;
			$r = HxOverrides.substr(str,pos1,null);
			return $r;
		}(this)));
	case 7:
		return cdb.ColumnType.TImage;
	case 8:
		return cdb.ColumnType.TList;
	case 9:
		return cdb.ColumnType.TCustom((function($this) {
			var $r;
			var pos2 = str.indexOf(":") + 1;
			$r = HxOverrides.substr(str,pos2,null);
			return $r;
		}(this)));
	case 10:
		return cdb.ColumnType.TFlags(((function($this) {
			var $r;
			var pos3 = str.indexOf(":") + 1;
			$r = HxOverrides.substr(str,pos3,null);
			return $r;
		}(this))).split(","));
	case 11:
		return cdb.ColumnType.TColor;
	case 12:
		return cdb.ColumnType.TLayer((function($this) {
			var $r;
			var pos4 = str.indexOf(":") + 1;
			$r = HxOverrides.substr(str,pos4,null);
			return $r;
		}(this)));
	default:
		throw "Unknown type " + str;
	} else throw "Unknown type " + str;
};
cdb.Parser.parse = function(content) {
	if(content == null) throw "CDB content is null";
	var data = js.Node.parse(content);
	var _g = 0;
	var _g1 = data.sheets;
	while(_g < _g1.length) {
		var s = _g1[_g];
		++_g;
		var _g2 = 0;
		var _g3 = s.columns;
		while(_g2 < _g3.length) {
			var c = _g3[_g2];
			++_g2;
			c.type = cdb.Parser.getType(c.typeStr);
			c.typeStr = null;
		}
	}
	var _g4 = 0;
	var _g11 = data.customTypes;
	while(_g4 < _g11.length) {
		var t = _g11[_g4];
		++_g4;
		var _g21 = 0;
		var _g31 = t.cases;
		while(_g21 < _g31.length) {
			var c1 = _g31[_g21];
			++_g21;
			var _g41 = 0;
			var _g5 = c1.args;
			while(_g41 < _g5.length) {
				var a = _g5[_g41];
				++_g41;
				a.type = cdb.Parser.getType(a.typeStr);
				a.typeStr = null;
			}
		}
	}
	return data;
};
var haxe = {};
haxe.Json = function() { };
$hxClasses["haxe.Json"] = haxe.Json;
haxe.Json.__name__ = ["haxe","Json"];
haxe.Json.stringify = function(obj,replacer,insertion) {
	return js.Node.stringify(obj,replacer,insertion);
};
haxe.Json.parse = function(jsonString) {
	return js.Node.parse(jsonString);
};
haxe.Serializer = function() {
	this.buf = new StringBuf();
	this.cache = new Array();
	this.useCache = haxe.Serializer.USE_CACHE;
	this.useEnumIndex = haxe.Serializer.USE_ENUM_INDEX;
	this.shash = new haxe.ds.StringMap();
	this.scount = 0;
};
$hxClasses["haxe.Serializer"] = haxe.Serializer;
haxe.Serializer.__name__ = ["haxe","Serializer"];
haxe.Serializer.run = function(v) {
	var s = new haxe.Serializer();
	s.serialize(v);
	return s.toString();
};
haxe.Serializer.prototype = {
	toString: function() {
		return this.buf.b;
	}
	,serializeString: function(s) {
		var x = this.shash.get(s);
		if(x != null) {
			this.buf.b += "R";
			if(x == null) this.buf.b += "null"; else this.buf.b += "" + x;
			return;
		}
		this.shash.set(s,this.scount++);
		this.buf.b += "y";
		s = encodeURIComponent(s);
		if(s.length == null) this.buf.b += "null"; else this.buf.b += "" + s.length;
		this.buf.b += ":";
		if(s == null) this.buf.b += "null"; else this.buf.b += "" + s;
	}
	,serializeRef: function(v) {
		var vt = typeof(v);
		var _g1 = 0;
		var _g = this.cache.length;
		while(_g1 < _g) {
			var i = _g1++;
			var ci = this.cache[i];
			if(typeof(ci) == vt && ci == v) {
				this.buf.b += "r";
				if(i == null) this.buf.b += "null"; else this.buf.b += "" + i;
				return true;
			}
		}
		this.cache.push(v);
		return false;
	}
	,serializeFields: function(v) {
		var _g = 0;
		var _g1 = Reflect.fields(v);
		while(_g < _g1.length) {
			var f = _g1[_g];
			++_g;
			this.serializeString(f);
			this.serialize(Reflect.field(v,f));
		}
		this.buf.b += "g";
	}
	,serialize: function(v) {
		{
			var _g = Type["typeof"](v);
			switch(_g[1]) {
			case 0:
				this.buf.b += "n";
				break;
			case 1:
				var v1 = v;
				if(v1 == 0) {
					this.buf.b += "z";
					return;
				}
				this.buf.b += "i";
				if(v1 == null) this.buf.b += "null"; else this.buf.b += "" + v1;
				break;
			case 2:
				var v2 = v;
				if(isNaN(v2)) this.buf.b += "k"; else if(!isFinite(v2)) if(v2 < 0) this.buf.b += "m"; else this.buf.b += "p"; else {
					this.buf.b += "d";
					if(v2 == null) this.buf.b += "null"; else this.buf.b += "" + v2;
				}
				break;
			case 3:
				if(v) this.buf.b += "t"; else this.buf.b += "f";
				break;
			case 6:
				var c = _g[2];
				if(c == String) {
					this.serializeString(v);
					return;
				}
				if(this.useCache && this.serializeRef(v)) return;
				switch(c) {
				case Array:
					var ucount = 0;
					this.buf.b += "a";
					var l = v.length;
					var _g1 = 0;
					while(_g1 < l) {
						var i = _g1++;
						if(v[i] == null) ucount++; else {
							if(ucount > 0) {
								if(ucount == 1) this.buf.b += "n"; else {
									this.buf.b += "u";
									if(ucount == null) this.buf.b += "null"; else this.buf.b += "" + ucount;
								}
								ucount = 0;
							}
							this.serialize(v[i]);
						}
					}
					if(ucount > 0) {
						if(ucount == 1) this.buf.b += "n"; else {
							this.buf.b += "u";
							if(ucount == null) this.buf.b += "null"; else this.buf.b += "" + ucount;
						}
					}
					this.buf.b += "h";
					break;
				case List:
					this.buf.b += "l";
					var v3 = v;
					var $it0 = v3.iterator();
					while( $it0.hasNext() ) {
						var i1 = $it0.next();
						this.serialize(i1);
					}
					this.buf.b += "h";
					break;
				case Date:
					var d = v;
					this.buf.b += "v";
					this.buf.add(HxOverrides.dateStr(d));
					break;
				case haxe.ds.StringMap:
					this.buf.b += "b";
					var v4 = v;
					var $it1 = v4.keys();
					while( $it1.hasNext() ) {
						var k = $it1.next();
						this.serializeString(k);
						this.serialize(v4.get(k));
					}
					this.buf.b += "h";
					break;
				case haxe.ds.IntMap:
					this.buf.b += "q";
					var v5 = v;
					var $it2 = v5.keys();
					while( $it2.hasNext() ) {
						var k1 = $it2.next();
						this.buf.b += ":";
						if(k1 == null) this.buf.b += "null"; else this.buf.b += "" + k1;
						this.serialize(v5.get(k1));
					}
					this.buf.b += "h";
					break;
				case haxe.ds.ObjectMap:
					this.buf.b += "M";
					var v6 = v;
					var $it3 = v6.keys();
					while( $it3.hasNext() ) {
						var k2 = $it3.next();
						var id = Reflect.field(k2,"__id__");
						Reflect.deleteField(k2,"__id__");
						this.serialize(k2);
						k2.__id__ = id;
						this.serialize(v6.h[k2.__id__]);
					}
					this.buf.b += "h";
					break;
				case haxe.io.Bytes:
					var v7 = v;
					var i2 = 0;
					var max = v7.length - 2;
					var charsBuf = new StringBuf();
					var b64 = haxe.Serializer.BASE64;
					while(i2 < max) {
						var b1 = v7.get(i2++);
						var b2 = v7.get(i2++);
						var b3 = v7.get(i2++);
						charsBuf.add(b64.charAt(b1 >> 2));
						charsBuf.add(b64.charAt((b1 << 4 | b2 >> 4) & 63));
						charsBuf.add(b64.charAt((b2 << 2 | b3 >> 6) & 63));
						charsBuf.add(b64.charAt(b3 & 63));
					}
					if(i2 == max) {
						var b11 = v7.get(i2++);
						var b21 = v7.get(i2++);
						charsBuf.add(b64.charAt(b11 >> 2));
						charsBuf.add(b64.charAt((b11 << 4 | b21 >> 4) & 63));
						charsBuf.add(b64.charAt(b21 << 2 & 63));
					} else if(i2 == max + 1) {
						var b12 = v7.get(i2++);
						charsBuf.add(b64.charAt(b12 >> 2));
						charsBuf.add(b64.charAt(b12 << 4 & 63));
					}
					var chars = charsBuf.b;
					this.buf.b += "s";
					if(chars.length == null) this.buf.b += "null"; else this.buf.b += "" + chars.length;
					this.buf.b += ":";
					if(chars == null) this.buf.b += "null"; else this.buf.b += "" + chars;
					break;
				default:
					if(this.useCache) this.cache.pop();
					if(v.hxSerialize != null) {
						this.buf.b += "C";
						this.serializeString(Type.getClassName(c));
						if(this.useCache) this.cache.push(v);
						v.hxSerialize(this);
						this.buf.b += "g";
					} else {
						this.buf.b += "c";
						this.serializeString(Type.getClassName(c));
						if(this.useCache) this.cache.push(v);
						this.serializeFields(v);
					}
				}
				break;
			case 4:
				if(this.useCache && this.serializeRef(v)) return;
				this.buf.b += "o";
				this.serializeFields(v);
				break;
			case 7:
				var e = _g[2];
				if(this.useCache) {
					if(this.serializeRef(v)) return;
					this.cache.pop();
				}
				if(this.useEnumIndex) this.buf.b += "j"; else this.buf.b += "w";
				this.serializeString(Type.getEnumName(e));
				if(this.useEnumIndex) {
					this.buf.b += ":";
					this.buf.b += Std.string(v[1]);
				} else this.serializeString(v[0]);
				this.buf.b += ":";
				var l1 = v.length;
				this.buf.b += Std.string(l1 - 2);
				var _g11 = 2;
				while(_g11 < l1) {
					var i3 = _g11++;
					this.serialize(v[i3]);
				}
				if(this.useCache) this.cache.push(v);
				break;
			case 5:
				throw "Cannot serialize function";
				break;
			default:
				throw "Cannot serialize " + Std.string(v);
			}
		}
	}
	,__class__: haxe.Serializer
};
haxe.Timer = function(time_ms) {
	var me = this;
	this.id = setInterval(function() {
		me.run();
	},time_ms);
};
$hxClasses["haxe.Timer"] = haxe.Timer;
haxe.Timer.__name__ = ["haxe","Timer"];
haxe.Timer.delay = function(f,time_ms) {
	var t = new haxe.Timer(time_ms);
	t.run = function() {
		t.stop();
		f();
	};
	return t;
};
haxe.Timer.prototype = {
	stop: function() {
		if(this.id == null) return;
		clearInterval(this.id);
		this.id = null;
	}
	,run: function() {
	}
	,__class__: haxe.Timer
};
haxe.Unserializer = function(buf) {
	this.buf = buf;
	this.length = buf.length;
	this.pos = 0;
	this.scache = new Array();
	this.cache = new Array();
	var r = haxe.Unserializer.DEFAULT_RESOLVER;
	if(r == null) {
		r = Type;
		haxe.Unserializer.DEFAULT_RESOLVER = r;
	}
	this.setResolver(r);
};
$hxClasses["haxe.Unserializer"] = haxe.Unserializer;
haxe.Unserializer.__name__ = ["haxe","Unserializer"];
haxe.Unserializer.initCodes = function() {
	var codes = new Array();
	var _g1 = 0;
	var _g = haxe.Unserializer.BASE64.length;
	while(_g1 < _g) {
		var i = _g1++;
		codes[haxe.Unserializer.BASE64.charCodeAt(i)] = i;
	}
	return codes;
};
haxe.Unserializer.run = function(v) {
	return new haxe.Unserializer(v).unserialize();
};
haxe.Unserializer.prototype = {
	setResolver: function(r) {
		if(r == null) this.resolver = { resolveClass : function(_) {
			return null;
		}, resolveEnum : function(_1) {
			return null;
		}}; else this.resolver = r;
	}
	,get: function(p) {
		return this.buf.charCodeAt(p);
	}
	,readDigits: function() {
		var k = 0;
		var s = false;
		var fpos = this.pos;
		while(true) {
			var c = this.buf.charCodeAt(this.pos);
			if(c != c) break;
			if(c == 45) {
				if(this.pos != fpos) break;
				s = true;
				this.pos++;
				continue;
			}
			if(c < 48 || c > 57) break;
			k = k * 10 + (c - 48);
			this.pos++;
		}
		if(s) k *= -1;
		return k;
	}
	,unserializeObject: function(o) {
		while(true) {
			if(this.pos >= this.length) throw "Invalid object";
			if(this.buf.charCodeAt(this.pos) == 103) break;
			var k = this.unserialize();
			if(!(typeof(k) == "string")) throw "Invalid object key";
			var v = this.unserialize();
			o[k] = v;
		}
		this.pos++;
	}
	,unserializeEnum: function(edecl,tag) {
		if(this.get(this.pos++) != 58) throw "Invalid enum format";
		var nargs = this.readDigits();
		if(nargs == 0) return Type.createEnum(edecl,tag);
		var args = new Array();
		while(nargs-- > 0) args.push(this.unserialize());
		return Type.createEnum(edecl,tag,args);
	}
	,unserialize: function() {
		var _g = this.get(this.pos++);
		switch(_g) {
		case 110:
			return null;
		case 116:
			return true;
		case 102:
			return false;
		case 122:
			return 0;
		case 105:
			return this.readDigits();
		case 100:
			var p1 = this.pos;
			while(true) {
				var c = this.buf.charCodeAt(this.pos);
				if(c >= 43 && c < 58 || c == 101 || c == 69) this.pos++; else break;
			}
			return Std.parseFloat(HxOverrides.substr(this.buf,p1,this.pos - p1));
		case 121:
			var len = this.readDigits();
			if(this.get(this.pos++) != 58 || this.length - this.pos < len) throw "Invalid string length";
			var s = HxOverrides.substr(this.buf,this.pos,len);
			this.pos += len;
			s = decodeURIComponent(s.split("+").join(" "));
			this.scache.push(s);
			return s;
		case 107:
			return NaN;
		case 109:
			return -Infinity;
		case 112:
			return Infinity;
		case 97:
			var buf = this.buf;
			var a = new Array();
			this.cache.push(a);
			while(true) {
				var c1 = this.buf.charCodeAt(this.pos);
				if(c1 == 104) {
					this.pos++;
					break;
				}
				if(c1 == 117) {
					this.pos++;
					var n = this.readDigits();
					a[a.length + n - 1] = null;
				} else a.push(this.unserialize());
			}
			return a;
		case 111:
			var o = { };
			this.cache.push(o);
			this.unserializeObject(o);
			return o;
		case 114:
			var n1 = this.readDigits();
			if(n1 < 0 || n1 >= this.cache.length) throw "Invalid reference";
			return this.cache[n1];
		case 82:
			var n2 = this.readDigits();
			if(n2 < 0 || n2 >= this.scache.length) throw "Invalid string reference";
			return this.scache[n2];
		case 120:
			throw this.unserialize();
			break;
		case 99:
			var name = this.unserialize();
			var cl = this.resolver.resolveClass(name);
			if(cl == null) throw "Class not found " + name;
			var o1 = Type.createEmptyInstance(cl);
			this.cache.push(o1);
			this.unserializeObject(o1);
			return o1;
		case 119:
			var name1 = this.unserialize();
			var edecl = this.resolver.resolveEnum(name1);
			if(edecl == null) throw "Enum not found " + name1;
			var e = this.unserializeEnum(edecl,this.unserialize());
			this.cache.push(e);
			return e;
		case 106:
			var name2 = this.unserialize();
			var edecl1 = this.resolver.resolveEnum(name2);
			if(edecl1 == null) throw "Enum not found " + name2;
			this.pos++;
			var index = this.readDigits();
			var tag = Type.getEnumConstructs(edecl1)[index];
			if(tag == null) throw "Unknown enum index " + name2 + "@" + index;
			var e1 = this.unserializeEnum(edecl1,tag);
			this.cache.push(e1);
			return e1;
		case 108:
			var l = new List();
			this.cache.push(l);
			var buf1 = this.buf;
			while(this.buf.charCodeAt(this.pos) != 104) l.add(this.unserialize());
			this.pos++;
			return l;
		case 98:
			var h = new haxe.ds.StringMap();
			this.cache.push(h);
			var buf2 = this.buf;
			while(this.buf.charCodeAt(this.pos) != 104) {
				var s1 = this.unserialize();
				h.set(s1,this.unserialize());
			}
			this.pos++;
			return h;
		case 113:
			var h1 = new haxe.ds.IntMap();
			this.cache.push(h1);
			var buf3 = this.buf;
			var c2 = this.get(this.pos++);
			while(c2 == 58) {
				var i = this.readDigits();
				h1.set(i,this.unserialize());
				c2 = this.get(this.pos++);
			}
			if(c2 != 104) throw "Invalid IntMap format";
			return h1;
		case 77:
			var h2 = new haxe.ds.ObjectMap();
			this.cache.push(h2);
			var buf4 = this.buf;
			while(this.buf.charCodeAt(this.pos) != 104) {
				var s2 = this.unserialize();
				h2.set(s2,this.unserialize());
			}
			this.pos++;
			return h2;
		case 118:
			var d;
			var s3 = HxOverrides.substr(this.buf,this.pos,19);
			d = HxOverrides.strDate(s3);
			this.cache.push(d);
			this.pos += 19;
			return d;
		case 115:
			var len1 = this.readDigits();
			var buf5 = this.buf;
			if(this.get(this.pos++) != 58 || this.length - this.pos < len1) throw "Invalid bytes length";
			var codes = haxe.Unserializer.CODES;
			if(codes == null) {
				codes = haxe.Unserializer.initCodes();
				haxe.Unserializer.CODES = codes;
			}
			var i1 = this.pos;
			var rest = len1 & 3;
			var size;
			size = (len1 >> 2) * 3 + (rest >= 2?rest - 1:0);
			var max = i1 + (len1 - rest);
			var bytes = haxe.io.Bytes.alloc(size);
			var bpos = 0;
			while(i1 < max) {
				var c11 = codes[StringTools.fastCodeAt(buf5,i1++)];
				var c21 = codes[StringTools.fastCodeAt(buf5,i1++)];
				bytes.set(bpos++,c11 << 2 | c21 >> 4);
				var c3 = codes[StringTools.fastCodeAt(buf5,i1++)];
				bytes.set(bpos++,c21 << 4 | c3 >> 2);
				var c4 = codes[StringTools.fastCodeAt(buf5,i1++)];
				bytes.set(bpos++,c3 << 6 | c4);
			}
			if(rest >= 2) {
				var c12 = codes[StringTools.fastCodeAt(buf5,i1++)];
				var c22 = codes[StringTools.fastCodeAt(buf5,i1++)];
				bytes.set(bpos++,c12 << 2 | c22 >> 4);
				if(rest == 3) {
					var c31 = codes[StringTools.fastCodeAt(buf5,i1++)];
					bytes.set(bpos++,c22 << 4 | c31 >> 2);
				}
			}
			this.pos += len1;
			this.cache.push(bytes);
			return bytes;
		case 67:
			var name3 = this.unserialize();
			var cl1 = this.resolver.resolveClass(name3);
			if(cl1 == null) throw "Class not found " + name3;
			var o2 = Type.createEmptyInstance(cl1);
			this.cache.push(o2);
			o2.hxUnserialize(this);
			if(this.get(this.pos++) != 103) throw "Invalid custom data";
			return o2;
		default:
		}
		this.pos--;
		throw "Invalid char " + this.buf.charAt(this.pos) + " at position " + this.pos;
	}
	,__class__: haxe.Unserializer
};
haxe.io = {};
haxe.io.Bytes = function(length,b) {
	this.length = length;
	this.b = b;
};
$hxClasses["haxe.io.Bytes"] = haxe.io.Bytes;
haxe.io.Bytes.__name__ = ["haxe","io","Bytes"];
haxe.io.Bytes.alloc = function(length) {
	return new haxe.io.Bytes(length,new Buffer(length));
};
haxe.io.Bytes.ofString = function(s) {
	var nb = new Buffer(s,"utf8");
	return new haxe.io.Bytes(nb.length,nb);
};
haxe.io.Bytes.ofData = function(b) {
	return new haxe.io.Bytes(b.length,b);
};
haxe.io.Bytes.prototype = {
	get: function(pos) {
		return this.b[pos];
	}
	,set: function(pos,v) {
		this.b[pos] = v;
	}
	,blit: function(pos,src,srcpos,len) {
		if(pos < 0 || srcpos < 0 || len < 0 || pos + len > this.length || srcpos + len > src.length) throw haxe.io.Error.OutsideBounds;
		src.b.copy(this.b,pos,srcpos,srcpos + len);
	}
	,sub: function(pos,len) {
		if(pos < 0 || len < 0 || pos + len > this.length) throw haxe.io.Error.OutsideBounds;
		var nb = new Buffer(len);
		var slice = this.b.slice(pos,pos + len);
		slice.copy(nb,0,0,len);
		return new haxe.io.Bytes(len,nb);
	}
	,compare: function(other) {
		var b1 = this.b;
		var b2 = other.b;
		var len;
		if(this.length < other.length) len = this.length; else len = other.length;
		var _g = 0;
		while(_g < len) {
			var i = _g++;
			if(b1[i] != b2[i]) return b1[i] - b2[i];
		}
		return this.length - other.length;
	}
	,readString: function(pos,len) {
		if(pos < 0 || len < 0 || pos + len > this.length) throw haxe.io.Error.OutsideBounds;
		var s = "";
		var b = this.b;
		var fcc = String.fromCharCode;
		var i = pos;
		var max = pos + len;
		while(i < max) {
			var c = b[i++];
			if(c < 128) {
				if(c == 0) break;
				s += fcc(c);
			} else if(c < 224) s += fcc((c & 63) << 6 | b[i++] & 127); else if(c < 240) {
				var c2 = b[i++];
				s += fcc((c & 31) << 12 | (c2 & 127) << 6 | b[i++] & 127);
			} else {
				var c21 = b[i++];
				var c3 = b[i++];
				s += fcc((c & 15) << 18 | (c21 & 127) << 12 | c3 << 6 & 127 | b[i++] & 127);
			}
		}
		return s;
	}
	,toString: function() {
		return this.readString(0,this.length);
	}
	,toHex: function() {
		var s = new StringBuf();
		var chars = [];
		var str = "0123456789abcdef";
		var _g1 = 0;
		var _g = str.length;
		while(_g1 < _g) {
			var i = _g1++;
			chars.push(HxOverrides.cca(str,i));
		}
		var _g11 = 0;
		var _g2 = this.length;
		while(_g11 < _g2) {
			var i1 = _g11++;
			var c = this.b[i1];
			s.b += String.fromCharCode(chars[c >> 4]);
			s.b += String.fromCharCode(chars[c & 15]);
		}
		return s.b;
	}
	,getData: function() {
		return this.b;
	}
	,__class__: haxe.io.Bytes
};
haxe.crypto = {};
haxe.crypto.Base64 = function() { };
$hxClasses["haxe.crypto.Base64"] = haxe.crypto.Base64;
haxe.crypto.Base64.__name__ = ["haxe","crypto","Base64"];
haxe.crypto.Base64.encode = function(bytes,complement) {
	if(complement == null) complement = true;
	var str = new haxe.crypto.BaseCode(haxe.crypto.Base64.BYTES).encodeBytes(bytes).toString();
	if(complement) {
		var _g1 = 0;
		var _g = (3 - bytes.length * 4 % 3) % 3;
		while(_g1 < _g) {
			var i = _g1++;
			str += "=";
		}
	}
	return str;
};
haxe.crypto.Base64.decode = function(str,complement) {
	if(complement == null) complement = true;
	if(complement) while(HxOverrides.cca(str,str.length - 1) == 61) str = HxOverrides.substr(str,0,-1);
	return new haxe.crypto.BaseCode(haxe.crypto.Base64.BYTES).decodeBytes(haxe.io.Bytes.ofString(str));
};
haxe.crypto.BaseCode = function(base) {
	var len = base.length;
	var nbits = 1;
	while(len > 1 << nbits) nbits++;
	if(nbits > 8 || len != 1 << nbits) throw "BaseCode : base length must be a power of two.";
	this.base = base;
	this.nbits = nbits;
};
$hxClasses["haxe.crypto.BaseCode"] = haxe.crypto.BaseCode;
haxe.crypto.BaseCode.__name__ = ["haxe","crypto","BaseCode"];
haxe.crypto.BaseCode.prototype = {
	encodeBytes: function(b) {
		var nbits = this.nbits;
		var base = this.base;
		var size = b.length * 8 / nbits | 0;
		var out = haxe.io.Bytes.alloc(size + (b.length * 8 % nbits == 0?0:1));
		var buf = 0;
		var curbits = 0;
		var mask = (1 << nbits) - 1;
		var pin = 0;
		var pout = 0;
		while(pout < size) {
			while(curbits < nbits) {
				curbits += 8;
				buf <<= 8;
				buf |= b.get(pin++);
			}
			curbits -= nbits;
			out.set(pout++,base.b[buf >> curbits & mask]);
		}
		if(curbits > 0) out.set(pout++,base.b[buf << nbits - curbits & mask]);
		return out;
	}
	,initTable: function() {
		var tbl = new Array();
		var _g = 0;
		while(_g < 256) {
			var i = _g++;
			tbl[i] = -1;
		}
		var _g1 = 0;
		var _g2 = this.base.length;
		while(_g1 < _g2) {
			var i1 = _g1++;
			tbl[this.base.b[i1]] = i1;
		}
		this.tbl = tbl;
	}
	,decodeBytes: function(b) {
		var nbits = this.nbits;
		var base = this.base;
		if(this.tbl == null) this.initTable();
		var tbl = this.tbl;
		var size = b.length * nbits >> 3;
		var out = haxe.io.Bytes.alloc(size);
		var buf = 0;
		var curbits = 0;
		var pin = 0;
		var pout = 0;
		while(pout < size) {
			while(curbits < 8) {
				curbits += nbits;
				buf <<= nbits;
				var i = tbl[b.get(pin++)];
				if(i == -1) throw "BaseCode : invalid encoded char";
				buf |= i;
			}
			curbits -= 8;
			out.set(pout++,buf >> curbits & 255);
		}
		return out;
	}
	,__class__: haxe.crypto.BaseCode
};
haxe.crypto.Md5 = function() {
};
$hxClasses["haxe.crypto.Md5"] = haxe.crypto.Md5;
haxe.crypto.Md5.__name__ = ["haxe","crypto","Md5"];
haxe.crypto.Md5.make = function(b) {
	var h = new haxe.crypto.Md5().doEncode(haxe.crypto.Md5.bytes2blks(b));
	var out = haxe.io.Bytes.alloc(16);
	var p = 0;
	var _g = 0;
	while(_g < 4) {
		var i = _g++;
		out.set(p++,h[i] & 255);
		out.set(p++,h[i] >> 8 & 255);
		out.set(p++,h[i] >> 16 & 255);
		out.set(p++,h[i] >>> 24);
	}
	return out;
};
haxe.crypto.Md5.bytes2blks = function(b) {
	var nblk = (b.length + 8 >> 6) + 1;
	var blks = new Array();
	var blksSize = nblk * 16;
	var _g = 0;
	while(_g < blksSize) {
		var i = _g++;
		blks[i] = 0;
	}
	var i1 = 0;
	while(i1 < b.length) {
		blks[i1 >> 2] |= b.b[i1] << (((b.length << 3) + i1 & 3) << 3);
		i1++;
	}
	blks[i1 >> 2] |= 128 << (b.length * 8 + i1) % 4 * 8;
	var l = b.length * 8;
	var k = nblk * 16 - 2;
	blks[k] = l & 255;
	blks[k] |= (l >>> 8 & 255) << 8;
	blks[k] |= (l >>> 16 & 255) << 16;
	blks[k] |= (l >>> 24 & 255) << 24;
	return blks;
};
haxe.crypto.Md5.prototype = {
	bitOR: function(a,b) {
		var lsb = a & 1 | b & 1;
		var msb31 = a >>> 1 | b >>> 1;
		return msb31 << 1 | lsb;
	}
	,bitXOR: function(a,b) {
		var lsb = a & 1 ^ b & 1;
		var msb31 = a >>> 1 ^ b >>> 1;
		return msb31 << 1 | lsb;
	}
	,bitAND: function(a,b) {
		var lsb = a & 1 & (b & 1);
		var msb31 = a >>> 1 & b >>> 1;
		return msb31 << 1 | lsb;
	}
	,addme: function(x,y) {
		var lsw = (x & 65535) + (y & 65535);
		var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
		return msw << 16 | lsw & 65535;
	}
	,rol: function(num,cnt) {
		return num << cnt | num >>> 32 - cnt;
	}
	,cmn: function(q,a,b,x,s,t) {
		return this.addme(this.rol(this.addme(this.addme(a,q),this.addme(x,t)),s),b);
	}
	,ff: function(a,b,c,d,x,s,t) {
		return this.cmn(this.bitOR(this.bitAND(b,c),this.bitAND(~b,d)),a,b,x,s,t);
	}
	,gg: function(a,b,c,d,x,s,t) {
		return this.cmn(this.bitOR(this.bitAND(b,d),this.bitAND(c,~d)),a,b,x,s,t);
	}
	,hh: function(a,b,c,d,x,s,t) {
		return this.cmn(this.bitXOR(this.bitXOR(b,c),d),a,b,x,s,t);
	}
	,ii: function(a,b,c,d,x,s,t) {
		return this.cmn(this.bitXOR(c,this.bitOR(b,~d)),a,b,x,s,t);
	}
	,doEncode: function(x) {
		var a = 1732584193;
		var b = -271733879;
		var c = -1732584194;
		var d = 271733878;
		var step;
		var i = 0;
		while(i < x.length) {
			var olda = a;
			var oldb = b;
			var oldc = c;
			var oldd = d;
			step = 0;
			a = this.ff(a,b,c,d,x[i],7,-680876936);
			d = this.ff(d,a,b,c,x[i + 1],12,-389564586);
			c = this.ff(c,d,a,b,x[i + 2],17,606105819);
			b = this.ff(b,c,d,a,x[i + 3],22,-1044525330);
			a = this.ff(a,b,c,d,x[i + 4],7,-176418897);
			d = this.ff(d,a,b,c,x[i + 5],12,1200080426);
			c = this.ff(c,d,a,b,x[i + 6],17,-1473231341);
			b = this.ff(b,c,d,a,x[i + 7],22,-45705983);
			a = this.ff(a,b,c,d,x[i + 8],7,1770035416);
			d = this.ff(d,a,b,c,x[i + 9],12,-1958414417);
			c = this.ff(c,d,a,b,x[i + 10],17,-42063);
			b = this.ff(b,c,d,a,x[i + 11],22,-1990404162);
			a = this.ff(a,b,c,d,x[i + 12],7,1804603682);
			d = this.ff(d,a,b,c,x[i + 13],12,-40341101);
			c = this.ff(c,d,a,b,x[i + 14],17,-1502002290);
			b = this.ff(b,c,d,a,x[i + 15],22,1236535329);
			a = this.gg(a,b,c,d,x[i + 1],5,-165796510);
			d = this.gg(d,a,b,c,x[i + 6],9,-1069501632);
			c = this.gg(c,d,a,b,x[i + 11],14,643717713);
			b = this.gg(b,c,d,a,x[i],20,-373897302);
			a = this.gg(a,b,c,d,x[i + 5],5,-701558691);
			d = this.gg(d,a,b,c,x[i + 10],9,38016083);
			c = this.gg(c,d,a,b,x[i + 15],14,-660478335);
			b = this.gg(b,c,d,a,x[i + 4],20,-405537848);
			a = this.gg(a,b,c,d,x[i + 9],5,568446438);
			d = this.gg(d,a,b,c,x[i + 14],9,-1019803690);
			c = this.gg(c,d,a,b,x[i + 3],14,-187363961);
			b = this.gg(b,c,d,a,x[i + 8],20,1163531501);
			a = this.gg(a,b,c,d,x[i + 13],5,-1444681467);
			d = this.gg(d,a,b,c,x[i + 2],9,-51403784);
			c = this.gg(c,d,a,b,x[i + 7],14,1735328473);
			b = this.gg(b,c,d,a,x[i + 12],20,-1926607734);
			a = this.hh(a,b,c,d,x[i + 5],4,-378558);
			d = this.hh(d,a,b,c,x[i + 8],11,-2022574463);
			c = this.hh(c,d,a,b,x[i + 11],16,1839030562);
			b = this.hh(b,c,d,a,x[i + 14],23,-35309556);
			a = this.hh(a,b,c,d,x[i + 1],4,-1530992060);
			d = this.hh(d,a,b,c,x[i + 4],11,1272893353);
			c = this.hh(c,d,a,b,x[i + 7],16,-155497632);
			b = this.hh(b,c,d,a,x[i + 10],23,-1094730640);
			a = this.hh(a,b,c,d,x[i + 13],4,681279174);
			d = this.hh(d,a,b,c,x[i],11,-358537222);
			c = this.hh(c,d,a,b,x[i + 3],16,-722521979);
			b = this.hh(b,c,d,a,x[i + 6],23,76029189);
			a = this.hh(a,b,c,d,x[i + 9],4,-640364487);
			d = this.hh(d,a,b,c,x[i + 12],11,-421815835);
			c = this.hh(c,d,a,b,x[i + 15],16,530742520);
			b = this.hh(b,c,d,a,x[i + 2],23,-995338651);
			a = this.ii(a,b,c,d,x[i],6,-198630844);
			d = this.ii(d,a,b,c,x[i + 7],10,1126891415);
			c = this.ii(c,d,a,b,x[i + 14],15,-1416354905);
			b = this.ii(b,c,d,a,x[i + 5],21,-57434055);
			a = this.ii(a,b,c,d,x[i + 12],6,1700485571);
			d = this.ii(d,a,b,c,x[i + 3],10,-1894986606);
			c = this.ii(c,d,a,b,x[i + 10],15,-1051523);
			b = this.ii(b,c,d,a,x[i + 1],21,-2054922799);
			a = this.ii(a,b,c,d,x[i + 8],6,1873313359);
			d = this.ii(d,a,b,c,x[i + 15],10,-30611744);
			c = this.ii(c,d,a,b,x[i + 6],15,-1560198380);
			b = this.ii(b,c,d,a,x[i + 13],21,1309151649);
			a = this.ii(a,b,c,d,x[i + 4],6,-145523070);
			d = this.ii(d,a,b,c,x[i + 11],10,-1120210379);
			c = this.ii(c,d,a,b,x[i + 2],15,718787259);
			b = this.ii(b,c,d,a,x[i + 9],21,-343485551);
			a = this.addme(a,olda);
			b = this.addme(b,oldb);
			c = this.addme(c,oldc);
			d = this.addme(d,oldd);
			i += 16;
		}
		return [a,b,c,d];
	}
	,__class__: haxe.crypto.Md5
};
haxe.ds = {};
haxe.ds.IntMap = function() {
	this.h = { };
};
$hxClasses["haxe.ds.IntMap"] = haxe.ds.IntMap;
haxe.ds.IntMap.__name__ = ["haxe","ds","IntMap"];
haxe.ds.IntMap.__interfaces__ = [IMap];
haxe.ds.IntMap.prototype = {
	set: function(key,value) {
		this.h[key] = value;
	}
	,get: function(key) {
		return this.h[key];
	}
	,keys: function() {
		var a = [];
		for( var key in this.h ) {
		if(this.h.hasOwnProperty(key)) a.push(key | 0);
		}
		return HxOverrides.iter(a);
	}
	,__class__: haxe.ds.IntMap
};
haxe.ds.ObjectMap = function() {
	this.h = { };
	this.h.__keys__ = { };
};
$hxClasses["haxe.ds.ObjectMap"] = haxe.ds.ObjectMap;
haxe.ds.ObjectMap.__name__ = ["haxe","ds","ObjectMap"];
haxe.ds.ObjectMap.__interfaces__ = [IMap];
haxe.ds.ObjectMap.prototype = {
	set: function(key,value) {
		var id = key.__id__ || (key.__id__ = ++haxe.ds.ObjectMap.count);
		this.h[id] = value;
		this.h.__keys__[id] = key;
	}
	,get: function(key) {
		return this.h[key.__id__];
	}
	,keys: function() {
		var a = [];
		for( var key in this.h.__keys__ ) {
		if(this.h.hasOwnProperty(key)) a.push(this.h.__keys__[key]);
		}
		return HxOverrides.iter(a);
	}
	,__class__: haxe.ds.ObjectMap
};
haxe.ds.StringMap = function() {
	this.h = { };
};
$hxClasses["haxe.ds.StringMap"] = haxe.ds.StringMap;
haxe.ds.StringMap.__name__ = ["haxe","ds","StringMap"];
haxe.ds.StringMap.__interfaces__ = [IMap];
haxe.ds.StringMap.prototype = {
	set: function(key,value) {
		this.h["$" + key] = value;
	}
	,get: function(key) {
		return this.h["$" + key];
	}
	,exists: function(key) {
		return this.h.hasOwnProperty("$" + key);
	}
	,remove: function(key) {
		key = "$" + key;
		if(!this.h.hasOwnProperty(key)) return false;
		delete(this.h[key]);
		return true;
	}
	,keys: function() {
		var a = [];
		for( var key in this.h ) {
		if(this.h.hasOwnProperty(key)) a.push(key.substr(1));
		}
		return HxOverrides.iter(a);
	}
	,iterator: function() {
		return { ref : this.h, it : this.keys(), hasNext : function() {
			return this.it.hasNext();
		}, next : function() {
			var i = this.it.next();
			return this.ref["$" + i];
		}};
	}
	,__class__: haxe.ds.StringMap
};
haxe.io.BytesBuffer = function() {
	this.b = new Array();
};
$hxClasses["haxe.io.BytesBuffer"] = haxe.io.BytesBuffer;
haxe.io.BytesBuffer.__name__ = ["haxe","io","BytesBuffer"];
haxe.io.BytesBuffer.prototype = {
	addByte: function($byte) {
		this.b.push($byte);
	}
	,add: function(src) {
		var b1 = this.b;
		var b2 = src.b;
		var _g1 = 0;
		var _g = src.length;
		while(_g1 < _g) {
			var i = _g1++;
			this.b.push(b2[i]);
		}
	}
	,addBytes: function(src,pos,len) {
		if(pos < 0 || len < 0 || pos + len > src.length) throw haxe.io.Error.OutsideBounds;
		var b1 = this.b;
		var b2 = src.b;
		var _g1 = pos;
		var _g = pos + len;
		while(_g1 < _g) {
			var i = _g1++;
			this.b.push(b2[i]);
		}
	}
	,getBytes: function() {
		var nb = new Buffer(this.b);
		var bytes = new haxe.io.Bytes(nb.length,nb);
		this.b = null;
		return bytes;
	}
	,__class__: haxe.io.BytesBuffer
};
haxe.io.Eof = function() { };
$hxClasses["haxe.io.Eof"] = haxe.io.Eof;
haxe.io.Eof.__name__ = ["haxe","io","Eof"];
haxe.io.Eof.prototype = {
	toString: function() {
		return "Eof";
	}
	,__class__: haxe.io.Eof
};
haxe.io.Error = $hxClasses["haxe.io.Error"] = { __ename__ : ["haxe","io","Error"], __constructs__ : ["Blocked","Overflow","OutsideBounds","Custom"] };
haxe.io.Error.Blocked = ["Blocked",0];
haxe.io.Error.Blocked.toString = $estr;
haxe.io.Error.Blocked.__enum__ = haxe.io.Error;
haxe.io.Error.Overflow = ["Overflow",1];
haxe.io.Error.Overflow.toString = $estr;
haxe.io.Error.Overflow.__enum__ = haxe.io.Error;
haxe.io.Error.OutsideBounds = ["OutsideBounds",2];
haxe.io.Error.OutsideBounds.toString = $estr;
haxe.io.Error.OutsideBounds.__enum__ = haxe.io.Error;
haxe.io.Error.Custom = function(e) { var $x = ["Custom",3,e]; $x.__enum__ = haxe.io.Error; $x.toString = $estr; return $x; };
haxe.io.Output = function() { };
$hxClasses["haxe.io.Output"] = haxe.io.Output;
haxe.io.Output.__name__ = ["haxe","io","Output"];
var js = {};
js.Boot = function() { };
$hxClasses["js.Boot"] = js.Boot;
js.Boot.__name__ = ["js","Boot"];
js.Boot.getClass = function(o) {
	if((o instanceof Array) && o.__enum__ == null) return Array; else return o.__class__;
};
js.Boot.__string_rec = function(o,s) {
	if(o == null) return "null";
	if(s.length >= 5) return "<...>";
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) t = "object";
	switch(t) {
	case "object":
		if(o instanceof Array) {
			if(o.__enum__) {
				if(o.length == 2) return o[0];
				var str = o[0] + "(";
				s += "\t";
				var _g1 = 2;
				var _g = o.length;
				while(_g1 < _g) {
					var i = _g1++;
					if(i != 2) str += "," + js.Boot.__string_rec(o[i],s); else str += js.Boot.__string_rec(o[i],s);
				}
				return str + ")";
			}
			var l = o.length;
			var i1;
			var str1 = "[";
			s += "\t";
			var _g2 = 0;
			while(_g2 < l) {
				var i2 = _g2++;
				str1 += (i2 > 0?",":"") + js.Boot.__string_rec(o[i2],s);
			}
			str1 += "]";
			return str1;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( e ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString) {
			var s2 = o.toString();
			if(s2 != "[object Object]") return s2;
		}
		var k = null;
		var str2 = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		for( var k in o ) {
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str2.length != 2) str2 += ", \n";
		str2 += s + k + " : " + js.Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str2 += "\n" + s + "}";
		return str2;
	case "function":
		return "<function>";
	case "string":
		return o;
	default:
		return String(o);
	}
};
js.Boot.__interfLoop = function(cc,cl) {
	if(cc == null) return false;
	if(cc == cl) return true;
	var intf = cc.__interfaces__;
	if(intf != null) {
		var _g1 = 0;
		var _g = intf.length;
		while(_g1 < _g) {
			var i = _g1++;
			var i1 = intf[i];
			if(i1 == cl || js.Boot.__interfLoop(i1,cl)) return true;
		}
	}
	return js.Boot.__interfLoop(cc.__super__,cl);
};
js.Boot.__instanceof = function(o,cl) {
	if(cl == null) return false;
	switch(cl) {
	case Int:
		return (o|0) === o;
	case Float:
		return typeof(o) == "number";
	case Bool:
		return typeof(o) == "boolean";
	case String:
		return typeof(o) == "string";
	case Array:
		return (o instanceof Array) && o.__enum__ == null;
	case Dynamic:
		return true;
	default:
		if(o != null) {
			if(typeof(cl) == "function") {
				if(o instanceof cl) return true;
				if(js.Boot.__interfLoop(js.Boot.getClass(o),cl)) return true;
			}
		} else return false;
		if(cl == Class && o.__name__ != null) return true;
		if(cl == Enum && o.__ename__ != null) return true;
		return o.__enum__ == cl;
	}
};
js.Browser = function() { };
$hxClasses["js.Browser"] = js.Browser;
js.Browser.__name__ = ["js","Browser"];
js.Browser.getLocalStorage = function() {
	try {
		var s = window.localStorage;
		s.getItem("");
		return s;
	} catch( e ) {
		return null;
	}
};
js.Lib = function() { };
$hxClasses["js.Lib"] = js.Lib;
js.Lib.__name__ = ["js","Lib"];
js.Lib.alert = function(v) {
	alert(js.Boot.__string_rec(v,""));
};
js.NodeC = function() { };
$hxClasses["js.NodeC"] = js.NodeC;
js.NodeC.__name__ = ["js","NodeC"];
js.Node = function() { };
$hxClasses["js.Node"] = js.Node;
js.Node.__name__ = ["js","Node"];
js.Node.get_assert = function() {
	return js.Node.require("assert");
};
js.Node.get_childProcess = function() {
	return js.Node.require("child_process");
};
js.Node.get_cluster = function() {
	return js.Node.require("cluster");
};
js.Node.get_crypto = function() {
	return js.Node.require("crypto");
};
js.Node.get_dgram = function() {
	return js.Node.require("dgram");
};
js.Node.get_dns = function() {
	return js.Node.require("dns");
};
js.Node.get_fs = function() {
	return js.Node.require("fs");
};
js.Node.get_http = function() {
	return js.Node.require("http");
};
js.Node.get_https = function() {
	return js.Node.require("https");
};
js.Node.get_net = function() {
	return js.Node.require("net");
};
js.Node.get_os = function() {
	return js.Node.require("os");
};
js.Node.get_path = function() {
	return js.Node.require("path");
};
js.Node.get_querystring = function() {
	return js.Node.require("querystring");
};
js.Node.get_repl = function() {
	return js.Node.require("repl");
};
js.Node.get_tls = function() {
	return js.Node.require("tls");
};
js.Node.get_url = function() {
	return js.Node.require("url");
};
js.Node.get_util = function() {
	return js.Node.require("util");
};
js.Node.get_vm = function() {
	return js.Node.require("vm");
};
js.Node.get___filename = function() {
	return __filename;
};
js.Node.get___dirname = function() {
	return __dirname;
};
js.Node.newSocket = function(options) {
	return new js.Node.net.Socket(options);
};
js.Selection = function(doc) {
	this.doc = doc;
};
$hxClasses["js.Selection"] = js.Selection;
js.Selection.__name__ = ["js","Selection"];
js.Selection.prototype = {
	insert: function(left,text,right) {
		this.doc.focus();
		if(this.doc.selectionStart != null) {
			var top = this.doc.scrollTop;
			var start = this.doc.selectionStart;
			var end = this.doc.selectionEnd;
			this.doc.value = Std.string(this.doc.value.substr(0,start)) + left + text + right + Std.string(this.doc.value.substr(end));
			this.doc.selectionStart = start + left.length;
			this.doc.selectionEnd = start + left.length + text.length;
			this.doc.scrollTop = top;
			return;
		}
		var range = js.Lib.document.selection.createRange();
		range.text = left + text + right;
		range.moveStart("character",-text.length - right.length);
		range.moveEnd("character",-right.length);
		range.select();
	}
	,__class__: js.Selection
};
var nodejs = {};
nodejs.webkit = {};
nodejs.webkit.$ui = function() { };
$hxClasses["nodejs.webkit.$ui"] = nodejs.webkit.$ui;
nodejs.webkit.$ui.__name__ = ["nodejs","webkit","$ui"];
var sys = {};
sys.FileSystem = function() { };
$hxClasses["sys.FileSystem"] = sys.FileSystem;
sys.FileSystem.__name__ = ["sys","FileSystem"];
sys.FileSystem.exists = function(path) {
	return js.Node.require("fs").existsSync(path);
};
sys.FileSystem.rename = function(path,newpath) {
	js.Node.require("fs").renameSync(path,newpath);
};
sys.FileSystem.stat = function(path) {
	return js.Node.require("fs").statSync(path);
};
sys.FileSystem.fullPath = function(relpath) {
	return js.Node.require("path").resolve(null,relpath);
};
sys.FileSystem.isDirectory = function(path) {
	if(js.Node.require("fs").statSync(path).isSymbolicLink()) return false; else return js.Node.require("fs").statSync(path).isDirectory();
};
sys.FileSystem.createDirectory = function(path) {
	js.Node.require("fs").mkdirSync(path);
};
sys.FileSystem.deleteFile = function(path) {
	js.Node.require("fs").unlinkSync(path);
};
sys.FileSystem.deleteDirectory = function(path) {
	js.Node.require("fs").rmdirSync(path);
};
sys.FileSystem.readDirectory = function(path) {
	return js.Node.require("fs").readdirSync(path);
};
sys.FileSystem.signature = function(path) {
	var shasum = js.Node.require("crypto").createHash("md5");
	shasum.update(js.Node.require("fs").readFileSync(path));
	return shasum.digest("hex");
};
sys.FileSystem.join = function(p1,p2,p3) {
	return js.Node.require("path").join(p1 == null?"":p1,p2 == null?"":p2,p3 == null?"":p3);
};
sys.FileSystem.readRecursive = function(path,filter) {
	var files = sys.FileSystem.readRecursiveInternal(path,null,filter);
	if(files == null) return []; else return files;
};
sys.FileSystem.readRecursiveInternal = function(root,dir,filter) {
	if(dir == null) dir = "";
	if(root == null) return null;
	var dirPath = js.Node.require("path").join(root == null?"":root,dir == null?"":dir,"");
	if(!(js.Node.require("fs").existsSync(dirPath) && sys.FileSystem.isDirectory(dirPath))) return null;
	var result = [];
	var _g = 0;
	var _g1 = js.Node.require("fs").readdirSync(dirPath);
	while(_g < _g1.length) {
		var file = _g1[_g];
		++_g;
		var fullPath = js.Node.require("path").join(dirPath == null?"":dirPath,file == null?"":file,"");
		var relPath;
		if(dir == "") relPath = file; else relPath = js.Node.require("path").join(dir == null?"":dir,file == null?"":file,"");
		if(js.Node.require("fs").existsSync(fullPath)) {
			if(sys.FileSystem.isDirectory(fullPath)) {
				if(fullPath.charCodeAt(fullPath.length - 1) == 47) fullPath = HxOverrides.substr(fullPath,0,-1);
				if(filter != null && !filter(relPath)) continue;
				var recursedResults = sys.FileSystem.readRecursiveInternal(root,relPath,filter);
				if(recursedResults != null && recursedResults.length > 0) result = result.concat(recursedResults);
			} else if(filter == null || filter(relPath)) result.push(relPath);
		}
	}
	return result;
};
sys.io = {};
sys.io.File = function() { };
$hxClasses["sys.io.File"] = sys.io.File;
sys.io.File.__name__ = ["sys","io","File"];
sys.io.File.append = function(path,binary) {
	throw "Not implemented";
	return null;
};
sys.io.File.copy = function(src,dst) {
	var content = js.Node.require("fs").readFileSync(src);
	js.Node.require("fs").writeFileSync(dst,content);
};
sys.io.File.getBytes = function(path) {
	var o = js.Node.require("fs").openSync(path,"r");
	var s = js.Node.require("fs").fstatSync(o);
	var len = s.size;
	var pos = 0;
	var bytes = haxe.io.Bytes.alloc(s.size);
	while(len > 0) {
		var r = js.Node.require("fs").readSync(o,bytes.b,pos,len,null);
		pos += r;
		len -= r;
	}
	js.Node.require("fs").closeSync(o);
	return bytes;
};
sys.io.File.getContent = function(path) {
	return js.Node.require("fs").readFileSync(path,"utf8");
};
sys.io.File.saveContent = function(path,content) {
	js.Node.require("fs").writeFileSync(path,content);
};
sys.io.File.write = function(path,binary) {
	throw "Not implemented";
	return null;
};
function $iterator(o) { if( o instanceof Array ) return function() { return HxOverrides.iter(o); }; return typeof(o.iterator) == 'function' ? $bind(o,o.iterator) : o.iterator; }
var $_, $fid = 0;
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $fid++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = function(){ return f.method.apply(f.scope, arguments); }; f.scope = o; f.method = m; o.hx__closures__[m.__id__] = f; } return f; }
if(Array.prototype.indexOf) HxOverrides.indexOf = function(a,o,i) {
	return Array.prototype.indexOf.call(a,o,i);
};
$hxClasses.Math = Math;
String.prototype.__class__ = $hxClasses.String = String;
String.__name__ = ["String"];
$hxClasses.Array = Array;
Array.__name__ = ["Array"];
Date.prototype.__class__ = $hxClasses.Date = Date;
Date.__name__ = ["Date"];
var Int = $hxClasses.Int = { __name__ : ["Int"]};
var Dynamic = $hxClasses.Dynamic = { __name__ : ["Dynamic"]};
var Float = $hxClasses.Float = Number;
Float.__name__ = ["Float"];
var Bool = $hxClasses.Bool = Boolean;
Bool.__ename__ = ["Bool"];
var Class = $hxClasses.Class = { __name__ : ["Class"]};
var Enum = { };
if(Array.prototype.map == null) Array.prototype.map = function(f) {
	var a = [];
	var _g1 = 0;
	var _g = this.length;
	while(_g1 < _g) {
		var i = _g1++;
		a[i] = f(this[i]);
	}
	return a;
};
if(Array.prototype.filter == null) Array.prototype.filter = function(f1) {
	var a1 = [];
	var _g11 = 0;
	var _g2 = this.length;
	while(_g11 < _g2) {
		var i1 = _g11++;
		var e = this[i1];
		if(f1(e)) a1.push(e);
	}
	return a1;
};
var q = window.jQuery;
js.JQuery = q;
q.fn.iterator = function() {
	return { pos : 0, j : this, hasNext : function() {
		return this.pos < this.j.length;
	}, next : function() {
		return $(this.j[this.pos++]);
	}};
};
var module, setImmediate, clearImmediate;
js.Node.setTimeout = setTimeout;
js.Node.clearTimeout = clearTimeout;
js.Node.setInterval = setInterval;
js.Node.clearInterval = clearInterval;
js.Node.global = global;
js.Node.process = process;
js.Node.require = require;
js.Node.console = console;
js.Node.module = module;
js.Node.stringify = JSON.stringify;
js.Node.parse = JSON.parse;
var version = HxOverrides.substr(js.Node.process.version,1,null).split(".").map(Std.parseInt);
if(version[0] > 0 || version[1] >= 9) {
	js.Node.setImmediate = setImmediate;
	js.Node.clearImmediate = clearImmediate;
}
nodejs.webkit.$ui = require('nw.gui');
nodejs.webkit.Clipboard = nodejs.webkit.$ui.Clipboard;
nodejs.webkit.Menu = nodejs.webkit.$ui.Menu;
nodejs.webkit.MenuItem = nodejs.webkit.$ui.MenuItem;
nodejs.webkit.Window = nodejs.webkit.$ui.Window;
Level.UID = 0;
K.INSERT = 45;
K.DELETE = 46;
K.LEFT = 37;
K.UP = 38;
K.RIGHT = 39;
K.DOWN = 40;
K.ESC = 27;
K.TAB = 9;
K.ENTER = 13;
K.F2 = 113;
K.F3 = 114;
K.F4 = 115;
Main.UID = 0;
haxe.Serializer.USE_CACHE = false;
haxe.Serializer.USE_ENUM_INDEX = false;
haxe.Serializer.BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%:";
haxe.Unserializer.DEFAULT_RESOLVER = Type;
haxe.Unserializer.BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%:";
haxe.crypto.Base64.CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
haxe.crypto.Base64.BYTES = haxe.io.Bytes.ofString(haxe.crypto.Base64.CHARS);
haxe.ds.ObjectMap.count = 0;
js.NodeC.UTF8 = "utf8";
js.NodeC.ASCII = "ascii";
js.NodeC.BINARY = "binary";
js.NodeC.BASE64 = "base64";
js.NodeC.HEX = "hex";
js.NodeC.EVENT_EVENTEMITTER_NEWLISTENER = "newListener";
js.NodeC.EVENT_EVENTEMITTER_ERROR = "error";
js.NodeC.EVENT_STREAM_DATA = "data";
js.NodeC.EVENT_STREAM_END = "end";
js.NodeC.EVENT_STREAM_ERROR = "error";
js.NodeC.EVENT_STREAM_CLOSE = "close";
js.NodeC.EVENT_STREAM_DRAIN = "drain";
js.NodeC.EVENT_STREAM_CONNECT = "connect";
js.NodeC.EVENT_STREAM_SECURE = "secure";
js.NodeC.EVENT_STREAM_TIMEOUT = "timeout";
js.NodeC.EVENT_STREAM_PIPE = "pipe";
js.NodeC.EVENT_PROCESS_EXIT = "exit";
js.NodeC.EVENT_PROCESS_UNCAUGHTEXCEPTION = "uncaughtException";
js.NodeC.EVENT_PROCESS_SIGINT = "SIGINT";
js.NodeC.EVENT_PROCESS_SIGUSR1 = "SIGUSR1";
js.NodeC.EVENT_CHILDPROCESS_EXIT = "exit";
js.NodeC.EVENT_HTTPSERVER_REQUEST = "request";
js.NodeC.EVENT_HTTPSERVER_CONNECTION = "connection";
js.NodeC.EVENT_HTTPSERVER_CLOSE = "close";
js.NodeC.EVENT_HTTPSERVER_UPGRADE = "upgrade";
js.NodeC.EVENT_HTTPSERVER_CLIENTERROR = "clientError";
js.NodeC.EVENT_HTTPSERVERREQUEST_DATA = "data";
js.NodeC.EVENT_HTTPSERVERREQUEST_END = "end";
js.NodeC.EVENT_CLIENTREQUEST_RESPONSE = "response";
js.NodeC.EVENT_CLIENTRESPONSE_DATA = "data";
js.NodeC.EVENT_CLIENTRESPONSE_END = "end";
js.NodeC.EVENT_NETSERVER_CONNECTION = "connection";
js.NodeC.EVENT_NETSERVER_CLOSE = "close";
js.NodeC.FILE_READ = "r";
js.NodeC.FILE_READ_APPEND = "r+";
js.NodeC.FILE_WRITE = "w";
js.NodeC.FILE_WRITE_APPEND = "a+";
js.NodeC.FILE_READWRITE = "a";
js.NodeC.FILE_READWRITE_APPEND = "a+";
Main.main();
})();
